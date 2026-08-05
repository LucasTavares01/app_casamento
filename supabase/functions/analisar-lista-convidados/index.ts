import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_FILE_BYTES = 30 * 1024 * 1024;
const MAX_EXTRACTED_TEXT_CHARS = 1_500_000;
const GEMINI_TIMEOUT_MS = 180_000;
const GEMINI_MODEL = "gemini-3.6-flash";

const ALLOWED_MIME_TYPES = new Set([
  "application/pdf",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-excel",
  "text/csv",
  "text/tab-separated-values",
  "image/png",
  "image/jpeg",
  "image/webp",
]);

// O esquema evita campos nullable durante a geração para manter compatibilidade
// entre modelos Gemini. Valores opcionais usam -1 ou string vazia e são
// normalizados antes de retornar ao Flutter.
const guestSchema = {
  type: "object",
  properties: {
    nome: {
      type: "string",
      description: "Nome completo exatamente como aparece no arquivo.",
    },
    descricao: {
      type: "string",
      description:
        "Observação curta e útil inferida do próprio arquivo. Pode representar qualquer condição, relação, restrição, pagamento, faixa etária, acessibilidade ou outra anotação relevante. Não use significados fixos para cores ou símbolos. Use string vazia quando não houver.",
    },
    email: {
      type: "string",
      description:
        "Endereço de e-mail escrito junto ao convidado, ou string vazia quando não houver.",
    },
    whatsapp: {
      type: "string",
      description:
        "Número de telefone ou WhatsApp escrito junto ao convidado, preservando DDD, ou string vazia quando não houver.",
    },
    categoria: {
      type: "string",
      enum: ["normal", "outra"],
      description:
        'Use "normal" quando não houver observação e "outra" quando houver qualquer observação relevante.',
    },
    confianca: {
      type: "number",
      minimum: 0,
      maximum: 1,
      description: "Confiança de leitura do nome, de 0 a 1.",
    },
  },
  required: [
    "nome",
    "descricao",
    "email",
    "whatsapp",
    "categoria",
    "confianca",
  ],
};

const previewSchema = {
  type: "object",
  properties: {
    arquivo_nome: { type: "string" },
    resumo: { type: "string" },
    mesas: {
      type: "array",
      items: {
        type: "object",
        properties: {
          numero: {
            type: "integer",
            minimum: -1,
            description:
              "Número da mesa. Use 0 para Mesa Família e -1 quando não for possível identificar.",
          },
          nome_exibicao: { type: "string" },
          detalhe: { type: "string" },
          capacidade: {
            type: "integer",
            minimum: -1,
            description:
              "Quantidade de lugares somente quando estiver escrita de forma explícita no arquivo; use -1 quando ausente. Nunca calcule pela quantidade de convidados.",
          },
          capacidade_inferida_automaticamente: {
            type: "boolean",
            description:
              "Mantenha false. A capacidade ausente não deve ser inferida automaticamente.",
          },
          convidados: { type: "array", items: guestSchema },
        },
        required: [
          "numero",
          "nome_exibicao",
          "detalhe",
          "capacidade",
          "capacidade_inferida_automaticamente",
          "convidados",
        ],
      },
    },
    convidados_sem_mesa: { type: "array", items: guestSchema },
    avisos: {
      type: "array",
      items: {
        type: "object",
        properties: {
          tipo: {
            type: "string",
            enum: [
              "nome_ilegivel",
              "possivel_duplicidade",
              "mesa_sem_numero",
              "convidado_sem_mesa",
              "capacidade_divergente",
              "informacao_incompleta",
              "outro",
            ],
          },
          mensagem: { type: "string" },
          mesa_numero: {
            type: "integer",
            minimum: -1,
            description: "Número da mesa relacionada ou -1.",
          },
          convidado_nome: {
            type: "string",
            description: "Nome relacionado ou string vazia.",
          },
        },
        required: ["tipo", "mensagem", "mesa_numero", "convidado_nome"],
      },
    },
  },
  required: [
    "arquivo_nome",
    "resumo",
    "mesas",
    "convidados_sem_mesa",
    "avisos",
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
    const arquivoNome = cleanString(body.arquivo_nome);
    const mimeType = cleanString(body.mime_type).toLowerCase();
    const arquivoBase64 = cleanString(body.arquivo_base64);
    const casamentoId = cleanString(body.casamento_id);

    if (
      !arquivoNome ||
      !mimeType ||
      !arquivoBase64 ||
      !casamentoId
    ) {
      return jsonResponse(
        { mensagem: "Arquivo ou casamento incompletos." },
        400,
      );
    }

    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      return jsonResponse(
        { mensagem: "Formato não permitido para análise." },
        415,
      );
    }

    const approximateBytes = Math.floor((arquivoBase64.length * 3) / 4);
    if (approximateBytes > MAX_FILE_BYTES) {
      return jsonResponse(
        { mensagem: "O arquivo ultrapassa o limite de 30 MB." },
        413,
      );
    }

    const sessionValidation = await validateAdminAccess(request, casamentoId);

    if (!sessionValidation.valid) {
      return jsonResponse(
        { mensagem: sessionValidation.message },
        401,
      );
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

    // Modelo fixo para evitar que um valor incorreto em GEMINI_MODEL
    // faça a função chamar um modelo inexistente.
    const model = GEMINI_MODEL;

    const prompt = buildPrompt(arquivoNome);
    const filePart = await buildGeminiFilePart({
      arquivoNome,
      mimeType,
      arquivoBase64,
    });

    // O arquivo vem antes do comando final para o modelo primeiro inspecionar
    // visualmente todas as páginas e só então produzir a estrutura solicitada.
    const parts: Array<Record<string, unknown>> = [
      filePart,
      { text: prompt },
    ];

    const geminiResponse = await callGemini({
      apiKey: geminiKey,
      model,
      parts,
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
            extractGeminiError(geminiResponse.body, geminiResponse.status) ||
            "O Gemini não conseguiu processar o arquivo.",
        },
        geminiResponse.status === 429 ? 429 : 502,
      );
    }

    const outputText = extractGeminiText(geminiResponse.body);
    if (!outputText) {
      return jsonResponse(
        { mensagem: "O Gemini não retornou uma lista estruturada." },
        502,
      );
    }

    let rawResult: unknown;
    try {
      rawResult = JSON.parse(stripJsonFences(outputText));
    } catch {
      console.error("Invalid Gemini JSON", outputText);
      return jsonResponse(
        { mensagem: "O Gemini retornou uma prévia inválida." },
        502,
      );
    }

    const resultado = reconcilePreviewResult(
      normalizePreviewResult(rawResult, arquivoNome),
    );

    return jsonResponse({
      resultado,
      metadados: {
        provedor: "gemini",
        modelo: model,
        usuario: sessionValidation.userName,
      },
    });
  } catch (error) {
    console.error(error);

    if (error instanceof Error && error.name === "TimeoutError") {
      return jsonResponse(
        {
          mensagem:
            "O Gemini demorou demais para analisar o arquivo. Tente novamente.",
        },
        504,
      );
    }

    const message = error instanceof Error ? error.message : "";
    if (message.startsWith("ARQUIVO_GRANDE:")) {
      return jsonResponse(
        { mensagem: message.replace("ARQUIVO_GRANDE:", "").trim() },
        413,
      );
    }

    return jsonResponse(
      { mensagem: "Erro interno ao analisar o arquivo." },
      500,
    );
  }
});

async function buildGeminiFilePart(input: {
  arquivoNome: string;
  mimeType: string;
  arquivoBase64: string;
}): Promise<Record<string, unknown>> {
  if (
    input.mimeType === "application/pdf" ||
    input.mimeType.startsWith("image/")
  ) {
    return {
      inlineData: {
        mimeType: input.mimeType,
        data: input.arquivoBase64,
      },
      // Resolução alta é necessária para distinguir cores de fonte, legendas,
      // textos pequenos e limites de colunas em listas densas.
      mediaResolution: {
        level: "MEDIA_RESOLUTION_HIGH",
      },
    };
  }

  const bytes = decodeBase64(input.arquivoBase64);
  let extractedText: string;

  if (
    input.mimeType ===
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ||
    input.mimeType === "application/vnd.ms-excel"
  ) {
    extractedText = await extractWorkbookText(bytes);
  } else {
    extractedText = new TextDecoder("utf-8").decode(bytes).replace(/^\uFEFF/, "");
  }

  if (!extractedText.trim()) {
    throw new Error("O arquivo não possui conteúdo legível.");
  }

  if (extractedText.length > MAX_EXTRACTED_TEXT_CHARS) {
    throw new Error(
      "ARQUIVO_GRANDE: A planilha possui conteúdo demais para uma única análise. Divida-a em arquivos menores.",
    );
  }

  return {
    text:
      `CONTEÚDO EXTRAÍDO DO ARQUIVO ${input.arquivoNome}:\n\n${extractedText}`,
  };
}

// O SheetJS fica fora do carregamento inicial. Assim, PDF, CSV e imagens
// continuam disponíveis mesmo quando o runtime da Edge Function não consegue
// inicializar um parser de planilhas. A importação só ocorre quando o arquivo
// realmente é XLS/XLSX.
async function extractWorkbookText(bytes: Uint8Array): Promise<string> {
  try {
    const XLSX = await import("npm:xlsx@0.18.5");
    const workbook = XLSX.read(bytes, {
      type: "array",
      raw: false,
      cellDates: false,
    });

    const sections: string[] = [];

    for (const sheetName of workbook.SheetNames) {
      const sheet = workbook.Sheets[sheetName];
      if (!sheet) {
        continue;
      }

      const csv = XLSX.utils.sheet_to_csv(sheet, {
        blankrows: false,
        FS: ",",
        RS: "\n",
      });

      if (csv.trim()) {
        sections.push(`### ABA: ${sheetName}\n${csv}`);
      }
    }

    return sections.join("\n\n");
  } catch (error) {
    console.error("Falha ao carregar parser de planilha", error);
    throw new Error(
      "Não foi possível ler a planilha. Tente exportá-la como CSV, PDF ou imagem.",
    );
  }
}

async function callGemini(input: {
  apiKey: string;
  model: string;
  parts: Array<Record<string, unknown>>;
}): Promise<{ ok: boolean; status: number; body: any }> {
  const endpoint =
  `https://generativelanguage.googleapis.com/v1beta/models/${input.model}:generateContent`;

const geminiHeaders = {
  "Content-Type": "application/json",
  "x-goog-api-key": input.apiKey,
};

  // Configuração de resposta estruturada usada pela API Gemini.
  const legacyConfig = {
    maxOutputTokens: 65536,
    responseMimeType: "application/json",
    responseSchema: previewSchema,
  };

  let response = await fetch(endpoint, {
    method: "POST",
    headers: geminiHeaders,
    signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
    body: JSON.stringify({
      contents: [{ role: "user", parts: input.parts }],
      generationConfig: legacyConfig,
    }),
  });

  let responseBody = await safeJson(response);

  // Modelos/API mais novos podem preferir responseFormat. Se o primeiro
  // formato for rejeitado por campo desconhecido, tenta automaticamente o
  // formato atual sem exigir alteração no app.
  if (
    !response.ok &&
    response.status === 400 &&
    isStructuredOutputFieldError(responseBody)
  ) {
    response = await fetch(endpoint, {
      method: "POST",
      headers: geminiHeaders,
      signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
      body: JSON.stringify({
        contents: [{ role: "user", parts: input.parts }],
        generationConfig: {
          maxOutputTokens: 65536,
          responseFormat: {
            text: {
              mimeType: "application/json",
              schema: previewSchema,
            },
          },
        },
      }),
    });
    responseBody = await safeJson(response);
  }

  return { ok: response.ok, status: response.status, body: responseBody };
}

function isStructuredOutputFieldError(body: any): boolean {
  const message = cleanString(body?.error?.message).toLowerCase();
  return message.includes("unknown name") ||
    message.includes("unknown field") ||
    message.includes("responseschema") ||
    message.includes("responsemimetype");
}

function extractGeminiText(body: any): string | null {
  const blockReason = cleanString(body?.promptFeedback?.blockReason);
  if (blockReason) {
    throw new Error(`O Gemini bloqueou a análise: ${blockReason}.`);
  }

  const candidates = Array.isArray(body?.candidates) ? body.candidates : [];
  if (candidates.length === 0) {
    return null;
  }

  const candidate = candidates[0];
  const finishReason = cleanString(candidate?.finishReason);
  if (finishReason === "MAX_TOKENS") {
    throw new Error(
      "A resposta ficou grande demais. Tente dividir o arquivo em partes menores.",
    );
  }

  const parts = Array.isArray(candidate?.content?.parts)
    ? candidate.content.parts
    : [];

  const texts = parts
    .map((part: any) => cleanString(part?.text))
    .filter((text: string) => text.length > 0);

  return texts.length > 0 ? texts.join("") : null;
}

function extractGeminiError(body: any, status: number): string | null {
  const raw = cleanString(body?.error?.message || body?.message);

  if (status === 400 && raw.toLowerCase().includes("api key")) {
    return "A chave do Gemini foi recusada. Revise GEMINI_API_KEY no Supabase.";
  }

  if (status === 403) {
    return "O projeto do Gemini não autorizou esta chamada. Revise a chave e as restrições da API.";
  }

  if (status === 404) {
    return `O modelo ${GEMINI_MODEL} não foi encontrado ou não está disponível para esta chave.`;
  }

  if (status === 429) {
    return "O limite da API Gemini foi atingido. Aguarde um pouco e tente novamente.";
  }

  return raw || null;
}

function normalizePreviewResult(raw: unknown, fileName: string) {
  const source = isRecord(raw) ? raw : {};

  const mesas = asArray(source.mesas).map((value) => {
    const mesa = isRecord(value) ? value : {};
    return {
      numero: optionalNonNegativeInteger(mesa.numero),
      nome_exibicao: cleanString(mesa.nome_exibicao) || "Mesa sem nome",
      detalhe: cleanString(mesa.detalhe),
      capacidade: optionalCapacity(mesa.capacidade),
      capacidade_inferida_automaticamente:
        mesa.capacidade_inferida_automaticamente === true,
      convidados: asArray(mesa.convidados).map(normalizeGuest),
    };
  });

  const convidadosSemMesa = asArray(source.convidados_sem_mesa).map(
    normalizeGuest,
  );

  const avisos = asArray(source.avisos).map((value) => {
    const aviso = isRecord(value) ? value : {};
    const guestName = cleanString(aviso.convidado_nome);
    return {
      tipo: normalizeWarningType(aviso.tipo),
      mensagem: cleanString(aviso.mensagem) || "Revisão necessária.",
      mesa_numero: optionalNonNegativeInteger(aviso.mesa_numero),
      convidado_nome: guestName || null,
    };
  });

  return {
    arquivo_nome: cleanString(source.arquivo_nome) || fileName,
    resumo: cleanString(source.resumo),
    mesas,
    convidados_sem_mesa: convidadosSemMesa,
    avisos,
  };
}

function reconcilePreviewResult(result: any) {
  const warnings = asArray(result.avisos)
    .filter((value) => {
      const warning = isRecord(value) ? value : {};
      return cleanString(warning.tipo) !== "capacidade_divergente";
    })
    .map((value) => isRecord(value) ? value : {});

  const tables = asArray(result.mesas).map((value) => {
    const table = isRecord(value) ? value : {};
    const guests = asArray(table.convidados);
    const declaredCapacity = optionalCapacity(table.capacidade);
    const hasDeclaredCapacity = declaredCapacity !== null;
    const capacity = hasDeclaredCapacity ? declaredCapacity : null;
    const tableNumber = Number(table.numero);
    const normalizedNumber = Number.isInteger(tableNumber) && tableNumber >= 0
      ? tableNumber
      : null;

    if (hasDeclaredCapacity && guests.length !== capacity) {
      const label = normalizedNumber === 0
        ? "Mesa Família"
        : normalizedNumber === null
        ? cleanString(table.nome_exibicao) || "Mesa sem número"
        : `Mesa ${normalizedNumber}`;

      warnings.push({
        tipo: "capacidade_divergente",
        mensagem:
          `${label}: o cabeçalho informa ${capacity} lugar(es), ` +
          `mas foram reconhecido(s) ${guests.length} convidado(s).`,
        mesa_numero: normalizedNumber,
        convidado_nome: null,
      });
    }

    return {
      ...table,
      capacidade: capacity,
      capacidade_inferida_automaticamente: false,
      detalhe: normalizeTableDetail(table.detalhe),
      convidados: guests,
    };
  });

  const deduplicatedWarnings: any[] = [];
  const warningKeys = new Set<string>();

  for (const value of warnings) {
    const warning = isRecord(value) ? value : {};
    const key = [
      cleanString(warning.tipo),
      cleanString(warning.mensagem),
      String(warning.mesa_numero ?? ""),
      cleanString(warning.convidado_nome),
    ].join("|");

    if (!warningKeys.has(key)) {
      warningKeys.add(key);
      deduplicatedWarnings.push(warning);
    }
  }

  return {
    ...result,
    mesas: tables,
    avisos: deduplicatedWarnings,
  };
}

function normalizeGuest(value: unknown) {
  const guest = isRecord(value) ? value : {};
  let description = cleanString(guest.descricao);
  const emailEncontrado = normalizeEmail(
    cleanString(guest.email) || extractEmail(description),
  );
  const whatsappEncontrado = normalizePhone(
    cleanString(guest.whatsapp) || extractPhone(description),
  );
  if (emailEncontrado) {
    description = removeFromDescription(description, emailEncontrado);
  }
  if (whatsappEncontrado) {
    description = removeFromDescription(description, whatsappEncontrado);
  }
  const confidence = Number(guest.confianca);

  return {
    nome: cleanString(guest.nome) || "Nome não identificado",
    descricao: description || null,
    email: emailEncontrado || null,
    whatsapp: whatsappEncontrado || null,
    categoria: normalizeGuestCategory(guest.categoria),
    confianca: Number.isFinite(confidence)
      ? Math.max(0, Math.min(1, confidence))
      : 1,
  };
}

function extractEmail(value: string): string {
  return value.match(/[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)+/i)?.[0] ?? "";
}

function extractPhone(value: string): string {
  const match = value.match(
    /(?:\+?55\s*)?(?:\(?\d{2}\)?\s*)?9?\s*\d{4}[\s-]*\d{4}/,
  );
  return match?.[0] ?? "";
}

function normalizeEmail(value: string): string {
  return extractEmail(value).toLowerCase();
}

function normalizePhone(value: string): string {
  const digits = value.replace(/\D/g, "");
  if (digits.length < 10 || digits.length > 13) {
    return "";
  }
  return digits;
}

function removeFromDescription(description: string, value: string): string {
  if (!description || !value) {
    return description;
  }
  return description
    .replace(value, "")
    .replace(/\s{2,}/g, " ")
    .replace(/\s*[,;|]\s*([,;|])/g, "$1")
    .replace(/^\s*[,;|]\s*|\s*[,;|]\s*$/g, "")
    .trim();
}

function normalizeGuestCategory(value: unknown): string {
  return cleanString(value) === "outra" ? "outra" : "normal";
}

function normalizeWarningType(value: unknown): string {
  const allowed = new Set([
    "nome_ilegivel",
    "possivel_duplicidade",
    "mesa_sem_numero",
    "convidado_sem_mesa",
    "capacidade_divergente",
    "informacao_incompleta",
    "outro",
  ]);
  const warning = cleanString(value);
  return allowed.has(warning) ? warning : "outro";
}

async function validateAdminAccess(
  request: Request,
  casamentoId: string,
): Promise<{ valid: boolean; message: string; userName: string | null }> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = getSupabaseSecretKey();
  const token = extractBearerToken(request);

  if (!token || !supabaseUrl || !serviceRoleKey) {
    return {
      valid: false,
      message: "Sua sessão não está ativa. Entre novamente no aplicativo.",
      userName: null,
    };
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: identidade, error: erroIdentidade } = await admin.auth.getUser(token);
  if (erroIdentidade || !identidade.user) {
    return {
      valid: false,
      message: "Sua sessão não está ativa. Entre novamente no aplicativo.",
      userName: null,
    };
  }

  const usuarioId = identidade.user.id;
  const { data: casamento, error: erroCasamento } = await admin
    .from("casamentos")
    .select("organizacao_id")
    .eq("id", casamentoId)
    .maybeSingle();
  if (erroCasamento || !casamento) {
    return {
      valid: false,
      message: "Casamento não encontrado.",
      userName: null,
    };
  }

  const [{ data: adminOrganizacao }, { data: adminCasamento }] = await Promise.all([
    admin
      .from("membros_organizacao")
      .select("usuario_id")
      .eq("organizacao_id", casamento.organizacao_id)
      .eq("usuario_id", usuarioId)
      .eq("papel", "admin")
      .eq("ativo", true)
      .maybeSingle(),
    admin
      .from("membros_casamento")
      .select("usuario_id")
      .eq("casamento_id", casamentoId)
      .eq("usuario_id", usuarioId)
      .eq("papel", "admin")
      .eq("ativo", true)
      .maybeSingle(),
  ]);

  if (!adminOrganizacao && !adminCasamento) {
    return {
      valid: false,
      message: "Somente administradoras podem analisar listas.",
      userName: null,
    };
  }

  const { data: user } = await admin
    .from("usuarios_app")
    .select("nome, ativo")
    .eq("id", usuarioId)
    .maybeSingle();

  if (!user || user.ativo !== true) {
    return {
      valid: false,
      message: "Este usuário está desativado.",
      userName: null,
    };
  }

  return { valid: true, message: "ok", userName: String(user.nome) };
}

function extractBearerToken(request: Request): string {
  return (request.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
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

function buildPrompt(fileName: string): string {
  return `
Você está extraindo uma lista de convidados de um evento do arquivo "${fileName}".

OBJETIVO:
Interpretar o documento visualmente como uma pessoa extremamente cuidadosa faria,
respeitando a posição de cada coluna, os cabeçalhos das mesas, as legendas de cores,
os símbolos e todas as observações próprias daquele arquivo. Cada lista pode possuir
regras diferentes. Não existe significado universal para cores ou símbolos.

PROCESSO VISUAL OBRIGATÓRIO ANTES DE GERAR O JSON:
A. Examine TODAS as páginas por inteiro antes de extrair nomes.
B. Mapeie a estrutura da página: blocos, colunas, cabeçalhos e limites de cada mesa.
C. Procure a legenda do documento, inclusive no rodapé, nas laterais ou em outra página.
D. Para cada item da legenda, identifique o marcador visual exato usado pelo autor:
   cor da fonte, cor de fundo, símbolo, ícone, sublinhado, estilo ou abreviação.
E. Percorra novamente todos os convidados e aplique a legenda a cada nome cujo marcador
   visual corresponda. Compare visualmente a cor/estilo; não dependa somente do texto
   extraído do PDF.
F. Faça uma segunda conferência mesa por mesa, contando os elementos do array de
   convidados e comparando esse total com a capacidade escrita no cabeçalho.

REGRAS PARA LEGENDAS E OBSERVAÇÕES:
1. Quando uma legenda explícita existir, copie para descricao o significado indicado
   pela própria legenda, de forma curta e fiel.
2. Exemplo: se o documento trouxer as legendas "crianças de colo",
   "não pagantes com lugar" e "pagantes 50%", cada nome escrito com a mesma cor ou
   marcação da legenda deve receber exatamente a observação correspondente.
3. Texto preto ou sem marcação não recebe automaticamente observação de legenda.
4. Observações escritas ao lado do nome ou entre parênteses também devem ser preservadas.
5. Se um convidado tiver mais de uma observação sustentada pelo documento, combine-as
   em uma única descricao separada por ponto e vírgula.
6. Nunca invente o significado de uma cor. Se a legenda não estiver legível, mantenha
   o nome, não atribua significado e crie aviso "informacao_incompleta".
7. Se houver um e-mail escrito junto ao nome, preencha o campo email. Se houver um
   telefone ou WhatsApp escrito junto ao nome, preencha o campo whatsapp. Esses dados
   nunca devem ser colocados em descricao.
8. Reconheça e-mails mesmo quando estiverem em outra coluna da mesma linha do nome.
   Reconheça telefones brasileiros com DDD, com ou sem espaços, parênteses e hífen.

REGRAS PARA MESAS E CONTAGEM:
9. Em documentos organizados como grade, cada cabeçalho "MESA ..." inicia uma COLUNA.
   Leia os nomes de cima para baixo dentro da coluna correspondente. Não leia uma linha
   inteira da esquerda para a direita como se todos os nomes pertencessem à mesma mesa.
10. Quando surgir uma nova faixa de cabeçalhos de mesas, reinicie os limites das colunas.
11. A capacidade deve ser copiada somente do texto do cabeçalho, como "8 lugares".
   Quando o cabeçalho não informar explicitamente a quantidade de lugares, use -1.
   Nesse caso NÃO calcule a capacidade pela quantidade de convidados, NÃO use zero,
   NÃO escreva "0 lugares" e NÃO crie aviso de divergência por capacidade ausente.
12. Cada pessoa deve aparecer exatamente uma vez no resultado, na mesa visualmente
    correspondente. Não mova nomes para fazer a contagem coincidir com a capacidade.
13. Depois de montar cada array convidados, compare o tamanho real do array somente
    com uma capacidade explicitamente declarada no arquivo. Se a capacidade estiver
    ausente, não compare, não invente capacidade e não crie aviso. Se houver
    capacidade declarada e ela for diferente da quantidade reconhecida, crie aviso
    "capacidade_divergente" informando os dois números exatos.
14. Preserve nomes duplicados. Apenas crie aviso de possível duplicidade; não una e
    não exclua ninguém.

REGRAS GERAIS:
15. Extraia TODAS as pessoas. Nunca remova nomes.
16. Preserve a grafia encontrada, corrigindo apenas espaços evidentes. Não invente
    sobrenomes nem informações.
17. Associe cada pessoa à mesa visualmente correspondente.
18. Para "Mesa Família" sem número, use numero 0. Para mesa realmente não
    identificável, use numero -1 e crie aviso.
19. Em capacidade, use a quantidade declarada de lugares; use -1 quando ausente.
    Nunca use a quantidade de nomes reconhecidos para preencher capacidade e nunca
    transforme ausência em 0.
20. Use categoria "outra" quando descricao tiver conteúdo e "normal" quando estiver
    vazia. Categoria é somente um marcador genérico.
21. Use confiança de 0 a 1 para cada nome. Abaixo de 0,75, crie também aviso
    "nome_ilegivel".
22. Pessoas que não puderem ser ligadas a uma mesa devem ir em convidados_sem_mesa;
    nunca devem desaparecer.
23. Não grave dados, não produza SQL e não resuma omitindo nomes. A saída deve conter
    a lista integral.
24. Para campos de texto opcionais sem conteúdo, use string vazia. Para números
    opcionais ausentes, use -1.
25. Use o contexto global: cabeçalhos, proximidade visual, alinhamento, cores, notas
    de rodapé e padrões repetidos em outras páginas.
26. O fato de uma lista anterior ter usado determinada cor para determinado significado
    não cria regra para novos arquivos.

VERIFICAÇÃO FINAL OBRIGATÓRIA:
- Confirme que toda legenda encontrada foi aplicada aos nomes com a mesma marcação.
- Confirme que nenhum nome colorido ficou sem descricao quando existe legenda para ele.
- Confirme que nenhum nome preto recebeu uma descrição de cor indevidamente.
- Confirme a quantidade de convidados de cada mesa contando os itens do array.
- Confirme que nenhum nome foi duplicado entre duas mesas por erro de leitura da grade.

O campo nome_exibicao deve ser amigável, como "Mesa 8" ou "Mesa Família".
O campo detalhe deve preservar quantidade de lugares, nome do grupo ou outra descrição
relevante da mesa.
O resumo deve informar quantas mesas e pessoas foram reconhecidas, quais legendas foram
identificadas e os principais pontos que exigem revisão.
`;
}

function stripJsonFences(value: string): string {
  const text = value.trim();
  if (!text.startsWith("```")) {
    return text;
  }

  return text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function optionalNonNegativeInteger(value: unknown): number | null {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 0) {
    return null;
  }
  return number;
}

function optionalCapacity(value: unknown): number | null {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1) {
    return null;
  }
  return number;
}

function normalizeTableDetail(value: unknown): string {
  return cleanString(value)
    .replace(/\b0\s+lugar(?:es)?\b/gi, "")
    .replace(/\s*([•·|])\s*/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function safeJson(response: Response): Promise<any> {
  const text = await response.text();
  if (!text.trim()) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    return { message: text };
  }
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
