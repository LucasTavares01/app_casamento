import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_TABLES = 500;
const MAX_GUESTS = 10_000;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ mensagem: "Método não permitido." }, 405);
  }

  try {
    const body = await request.json();
    const resultado = body?.resultado;
    const casamentoId = cleanString(body?.casamento_id);

    if (!isPlainObject(resultado) || !casamentoId) {
      return jsonResponse(
        { mensagem: "A lista ou o evento estão incompletos." },
        400,
      );
    }

    const validation = validatePreview(resultado);
    if (!validation.valid) {
      return jsonResponse({ mensagem: validation.message }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getSupabaseSecretKey();

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        { mensagem: "O publicador não está configurado no Supabase." },
        503,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const token = extractBearerToken(request);
    const { data: identidade, error: erroIdentidade } = await admin.auth.getUser(token);
    if (!token || erroIdentidade || !identidade.user) {
      return jsonResponse(
        { mensagem: "Sua sessão expirou. Entre novamente no aplicativo." },
        401,
      );
    }

    const solicitanteId = identidade.user.id;
    const { data: casamento, error: erroCasamento } = await admin
      .from("casamentos")
      .select("organizacao_id, status")
      .eq("id", casamentoId)
      .maybeSingle();
    if (erroCasamento || !casamento) {
      return jsonResponse({ mensagem: "Evento não encontrado." }, 404);
    }

    if (["finalizado", "arquivado"].includes(String(casamento.status))) {
      return jsonResponse(
        { mensagem: "Não é possível publicar uma lista em evento finalizado ou arquivado." },
        409,
      );
    }

    const [{ data: adminOrganizacao }, { data: adminCasamento }] = await Promise.all([
      admin
        .from("membros_organizacao")
        .select("usuario_id")
        .eq("organizacao_id", casamento.organizacao_id)
        .eq("usuario_id", solicitanteId)
        .eq("papel", "admin")
        .eq("ativo", true)
        .maybeSingle(),
      admin
        .from("membros_casamento")
        .select("usuario_id")
        .eq("casamento_id", casamentoId)
        .eq("usuario_id", solicitanteId)
        .eq("papel", "admin")
        .eq("ativo", true)
        .maybeSingle(),
    ]);
    if (!adminOrganizacao && !adminCasamento) {
      return jsonResponse(
        { mensagem: "Somente administradoras podem publicar listas." },
        403,
      );
    }

    const { data, error } = await admin.rpc("publicar_lista_casamento_v2", {
      p_usuario_id: solicitanteId,
      p_casamento_id: casamentoId,
      p_resultado: resultado,
    });

    if (error) {
      console.error("Erro ao publicar lista", error);
      return jsonResponse(
        { mensagem: friendlyDatabaseError(error) },
        error.code === "28000" ? 403 : 400,
      );
    }

    if (!isPlainObject(data)) {
      return jsonResponse(
        { mensagem: "A lista foi processada, mas a confirmação foi inválida." },
        500,
      );
    }

    return jsonResponse({ resultado: data });
  } catch (error) {
    console.error(error);
    return jsonResponse(
      { mensagem: "Erro interno ao substituir a lista." },
      500,
    );
  }
});

function validatePreview(value: Record<string, unknown>): {
  valid: boolean;
  message: string;
} {
  const mesas = Array.isArray(value.mesas) ? value.mesas : [];
  const semMesa = Array.isArray(value.convidados_sem_mesa)
    ? value.convidados_sem_mesa
    : [];

  if (mesas.length > MAX_TABLES) {
    return {
      valid: false,
      message: `A lista ultrapassa o limite de ${MAX_TABLES} mesas.`,
    };
  }

  const tableNumbers = new Set<number>();
  let guestCount = semMesa.length;

  for (const rawTable of mesas) {
    if (!isPlainObject(rawTable)) {
      return { valid: false, message: "Uma das mesas possui formato inválido." };
    }

    const number = toInteger(rawTable.numero);
    if (number === null || number < 0) {
      return {
        valid: false,
        message: "Todas as mesas precisam ter um número válido antes da publicação.",
      };
    }

    if (tableNumbers.has(number)) {
      return {
        valid: false,
        message: `O número da Mesa ${number} aparece mais de uma vez.`,
      };
    }
    tableNumbers.add(number);

    if (!Array.isArray(rawTable.convidados)) {
      return {
        valid: false,
        message: `A Mesa ${number} possui uma lista de convidados inválida.`,
      };
    }

    guestCount += rawTable.convidados.length;
  }

  if (guestCount === 0) {
    return { valid: false, message: "Nenhum convidado foi identificado." };
  }

  if (guestCount > MAX_GUESTS) {
    return {
      valid: false,
      message: `A lista ultrapassa o limite de ${MAX_GUESTS} convidados.`,
    };
  }

  return { valid: true, message: "" };
}

function friendlyDatabaseError(error: {
  code?: string;
  message?: string;
  details?: string;
}): string {
  const text = `${error.message ?? ""} ${error.details ?? ""}`.trim();

  if (error.code === "28000" || text.includes("SESSAO_INVALIDA")) {
    return "Sua sessão não está mais ativa. Entre novamente no aplicativo.";
  }

  const marker = "IMPORTACAO_INVALIDA:";
  const markerIndex = text.indexOf(marker);
  if (markerIndex >= 0) {
    return text.slice(markerIndex + marker.length).trim();
  }

  return text || "O Supabase não conseguiu substituir a lista.";
}

function getSupabaseSecretKey(): string | null {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) {
    return legacy;
  }

  const current = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!current) {
    return null;
  }

  try {
    const parsed = JSON.parse(current);
    const value = parsed?.default;
    return typeof value === "string" && value.trim() ? value : null;
  } catch {
    return null;
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cleanString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function extractBearerToken(request: Request): string {
  return (request.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
}

function toInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === "string" && /^-?\d+$/.test(value.trim())) {
    return Number.parseInt(value, 10);
  }
  return null;
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
