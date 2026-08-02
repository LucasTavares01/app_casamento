import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GEMINI_TIMEOUT_MS = 120_000;
const GEMINI_MODEL = "gemini-3.6-flash";
const MAX_PAYLOAD_CHARS = 180_000;

const insightsSchema = {
  type: "object",
  properties: {
    titulo_dashboard: {
      type: "string",
      description: "Título curto e elegante para o dashboard do relatório.",
    },
    resumo_executivo: {
      type: "string",
      description:
        "Resumo executivo em português, objetivo, com no máximo 700 caracteres.",
    },
    destaques: {
      type: "array",
      maxItems: 4,
      items: {
        type: "object",
        properties: {
          titulo: { type: "string" },
          texto: { type: "string" },
          tipo: {
            type: "string",
            enum: ["positivo", "atencao", "neutro"],
          },
        },
        required: ["titulo", "texto", "tipo"],
      },
    },
    alertas: {
      type: "array",
      maxItems: 5,
      items: { type: "string" },
    },
    recomendacoes: {
      type: "array",
      maxItems: 5,
      items: { type: "string" },
    },
  },
  required: [
    "titulo_dashboard",
    "resumo_executivo",
    "destaques",
    "alertas",
    "recomendacoes",
  ],
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ mensagem: "Método não permitido." }, 405);
  }

  try {
    const body = await request.json();
    const casamentoId = cleanString(body?.casamento_id);
    const dados = body?.dados;

    if (!casamentoId || !dados || typeof dados !== "object") {
      return jsonResponse(
        { mensagem: "Os dados do evento estão incompletos." },
        400,
      );
    }

    const serializedData = JSON.stringify(dados);
    if (serializedData.length > MAX_PAYLOAD_CHARS) {
      return jsonResponse(
        { mensagem: "O relatório possui dados demais para uma única análise." },
        413,
      );
    }

    const access = await validateAdminAccess(request, casamentoId);
    if (!access.valid) {
      return jsonResponse({ mensagem: access.message }, access.status);
    }

    const geminiKey =
      Deno.env.get("GEMINI_API_KEY") || Deno.env.get("GOOGLE_API_KEY");

    if (!geminiKey) {
      return jsonResponse(
        {
          mensagem:
            "A chave GEMINI_API_KEY ainda não foi configurada nos segredos da Edge Function.",
        },
        503,
      );
    }

    const model = Deno.env.get("GEMINI_MODEL") || GEMINI_MODEL;
    const prompt = buildPrompt(serializedData);
    const geminiResponse = await callGemini({
      apiKey: geminiKey,
      model,
      prompt,
    });

    if (!geminiResponse.ok) {
      console.error(
        "Gemini error",
        geminiResponse.status,
        JSON.stringify(geminiResponse.body),
      );

      return jsonResponse(
        {
          mensagem:
            extractGeminiError(geminiResponse.body) ||
            "A IA não conseguiu analisar os dados do relatório.",
        },
        geminiResponse.status === 429 ? 429 : 502,
      );
    }

    const outputText = extractGeminiText(geminiResponse.body);
    if (!outputText) {
      return jsonResponse(
        { mensagem: "A IA não retornou os insights do relatório." },
        502,
      );
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(stripJsonFences(outputText));
    } catch {
      console.error("Invalid Gemini JSON", outputText);
      return jsonResponse(
        { mensagem: "A IA retornou uma resposta inválida." },
        502,
      );
    }

    return jsonResponse({
      resultado: normalizeInsights(parsed),
      metadados: {
        provedor: "gemini",
        modelo: model,
        usuario: access.userName,
      },
    });
  } catch (error) {
    console.error(error);

    if (error instanceof Error && error.name === "TimeoutError") {
      return jsonResponse(
        { mensagem: "A IA demorou demais para gerar os insights." },
        504,
      );
    }

    return jsonResponse(
      { mensagem: "Erro interno ao gerar os insights do relatório." },
      500,
    );
  }
});

async function validateAdminAccess(
  request: Request,
  casamentoId: string,
): Promise<
  | { valid: true; userName: string }
  | { valid: false; message: string; status: number }
> {
  const supabaseUrl = cleanString(Deno.env.get("SUPABASE_URL"));
  const anonKey = cleanString(Deno.env.get("SUPABASE_ANON_KEY"));
  const serviceRoleKey = cleanString(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  const authorization = cleanString(request.headers.get("Authorization"));

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return {
      valid: false,
      message: "A função não está configurada corretamente no Supabase.",
      status: 503,
    };
  }

  if (!authorization) {
    return {
      valid: false,
      message: "Sua sessão não está ativa. Entre novamente no aplicativo.",
      status: 401,
    };
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await authClient.auth.getUser();
  const user = userData.user;

  if (userError || !user) {
    return {
      valid: false,
      message: "Sua sessão expirou. Entre novamente no aplicativo.",
      status: 401,
    };
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: casamento, error: casamentoError } = await adminClient
    .from("casamentos")
    .select("organizacao_id")
    .eq("id", casamentoId)
    .maybeSingle();

  if (casamentoError || !casamento) {
    return {
      valid: false,
      message: "Evento não encontrado.",
      status: 404,
    };
  }

  const [{ data: adminOrganizacao }, { data: adminCasamento }] =
    await Promise.all([
      adminClient
        .from("membros_organizacao")
        .select("usuario_id")
        .eq("organizacao_id", casamento.organizacao_id)
        .eq("usuario_id", user.id)
        .eq("papel", "admin")
        .eq("ativo", true)
        .maybeSingle(),
      adminClient
        .from("membros_casamento")
        .select("usuario_id")
        .eq("casamento_id", casamentoId)
        .eq("usuario_id", user.id)
        .eq("papel", "admin")
        .eq("ativo", true)
        .maybeSingle(),
    ]);

  if (!adminOrganizacao && !adminCasamento) {
    return {
      valid: false,
      message: "Somente administradores podem gerar este relatório.",
      status: 403,
    };
  }

  const { data: profile } = await adminClient
    .from("usuarios_app")
    .select("nome")
    .eq("id", user.id)
    .maybeSingle();

  return {
    valid: true,
    userName: cleanString(profile?.nome) || cleanString(user.email) || "Admin",
  };
}

function buildPrompt(serializedData: string): string {
  return `
Você é um analista de eventos especializado em recepção e check-in.

Analise SOMENTE os dados JSON fornecidos abaixo e gere conteúdo para um dashboard em Excel.

REGRAS OBRIGATÓRIAS:
1. Responda em português do Brasil.
2. Não invente fatos, causas, horários, pessoas ou números.
3. Use linguagem profissional, clara e curta.
4. Destaque presença, ausências, conflitos, distribuição entre mesas e horários de chegada.
5. Quando não houver dados suficientes, diga isso claramente.
6. Alertas devem representar problemas reais encontrados nos dados.
7. Recomendações devem ser práticas e coerentes com os números fornecidos.
8. Não use Markdown, listas numeradas ou emojis dentro dos textos.
9. Não repita a mesma informação em vários campos.

DADOS DO RELATÓRIO:
${serializedData}
`;
}

async function callGemini(input: {
  apiKey: string;
  model: string;
  prompt: string;
}): Promise<{ ok: boolean; status: number; body: any }> {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${input.model}:generateContent`;

  const headers = {
    "Content-Type": "application/json",
    "x-goog-api-key": input.apiKey,
  };

  const legacyConfig = {
    maxOutputTokens: 4096,
    temperature: 0.2,
    responseMimeType: "application/json",
    responseSchema: insightsSchema,
  };

  let response = await fetch(endpoint, {
    method: "POST",
    headers,
    signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: input.prompt }] }],
      generationConfig: legacyConfig,
    }),
  });

  let responseBody = await safeJson(response);

  if (
    !response.ok &&
    response.status === 400 &&
    isStructuredOutputFieldError(responseBody)
  ) {
    response = await fetch(endpoint, {
      method: "POST",
      headers,
      signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: input.prompt }] }],
        generationConfig: {
          maxOutputTokens: 4096,
          temperature: 0.2,
          responseFormat: {
            text: {
              mimeType: "application/json",
              schema: insightsSchema,
            },
          },
        },
      }),
    });

    responseBody = await safeJson(response);
  }

  return { ok: response.ok, status: response.status, body: responseBody };
}

function normalizeInsights(value: unknown): Record<string, unknown> {
  const map = isRecord(value) ? value : {};

  const highlights = Array.isArray(map.destaques)
    ? map.destaques
        .filter(isRecord)
        .slice(0, 4)
        .map((item) => ({
          titulo: cleanString(item.titulo) || "Destaque",
          texto: cleanString(item.texto),
          tipo: normalizeHighlightType(item.tipo),
        }))
        .filter((item) => item.texto.length > 0)
    : [];

  const alerts = normalizeStringArray(map.alertas, 5);
  const recommendations = normalizeStringArray(map.recomendacoes, 5);

  return {
    titulo_dashboard:
      cleanString(map.titulo_dashboard) || "Dashboard da recepção",
    resumo_executivo:
      cleanString(map.resumo_executivo) ||
      "Os dados foram consolidados para análise da recepção.",
    destaques: highlights,
    alertas: alerts,
    recomendacoes: recommendations,
  };
}

function normalizeHighlightType(value: unknown): string {
  const type = cleanString(value).toLowerCase();
  if (type === "positivo" || type === "atencao" || type === "neutro") {
    return type;
  }
  return "neutro";
}

function normalizeStringArray(value: unknown, maxItems: number): string[] {
  if (!Array.isArray(value)) return [];

  return value
    .map(cleanString)
    .filter((item) => item.length > 0)
    .slice(0, maxItems);
}

function extractGeminiText(body: any): string | null {
  const candidates = Array.isArray(body?.candidates) ? body.candidates : [];
  if (candidates.length === 0) return null;

  const parts = Array.isArray(candidates[0]?.content?.parts)
    ? candidates[0].content.parts
    : [];

  const text = parts
    .map((part: any) => cleanString(part?.text))
    .filter((part: string) => part.length > 0)
    .join("\n")
    .trim();

  return text || null;
}

function extractGeminiError(body: any): string | null {
  const message = cleanString(body?.error?.message);
  return message || null;
}

function isStructuredOutputFieldError(body: any): boolean {
  const message = cleanString(body?.error?.message).toLowerCase();
  return message.includes("unknown name") ||
    message.includes("unknown field") ||
    message.includes("responseschema") ||
    message.includes("responsemimetype");
}

async function safeJson(response: Response): Promise<any> {
  const text = await response.text();
  if (!text.trim()) return {};

  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function stripJsonFences(value: string): string {
  return value
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cleanString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
