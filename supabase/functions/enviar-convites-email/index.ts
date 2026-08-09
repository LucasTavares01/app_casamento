import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const LINK_BASE = "https://confirmaaiweb.netlify.app/convite?token=";

type ResultadoEnvio = {
  convidado_id: string;
  convite_id?: string;
  nome: string;
  email: string;
  link?: string;
  erro?: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ mensagem: "Método não permitido." }, 405);
  }

  try {
    const body = await request.json();
    const casamentoId = clean(body?.casamento_id);
    const convidadoIds = Array.isArray(body?.convidado_ids)
      ? body.convidado_ids.map((value: unknown) => clean(value)).filter(Boolean)
      : [];
    const forcarReenvio = body?.forcar_reenvio === true;

    if (forcarReenvio && convidadoIds.length !== 1) {
      return json(
        { mensagem: "O reenvio deve ser feito para um convidado por vez." },
        400,
      );
    }

    if (!casamentoId) {
      return json({ mensagem: "Evento não informado." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    const anonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ||
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    const token = getBearerToken(request);
    const gmailClientId = Deno.env.get("GMAIL_CLIENT_ID");
    const gmailClientSecret = Deno.env.get("GMAIL_CLIENT_SECRET");
    const gmailRefreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN");
    const fromEmail =
      clean(Deno.env.get("GMAIL_FROM_EMAIL")) || "appcasamentoweb@gmail.com";

    if (!supabaseUrl || !serviceRoleKey || !anonKey) {
      return json(
        { mensagem: "O envio de convites não está configurado no Supabase." },
        503,
      );
    }

    if (!gmailClientId || !gmailClientSecret || !gmailRefreshToken) {
      return json(
        {
          mensagem:
            "Configure GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET e GMAIL_REFRESH_TOKEN na Edge Function.",
        },
        503,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const acesso = await validarAdmin(admin, token, casamentoId);
    if (!acesso.valid) {
      return json({ mensagem: acesso.mensagem }, acesso.status);
    }

    const usuario = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: evento, error: eventoError } = await admin
      .from("casamentos")
      .select("titulo, status, data_limite_confirmacao")
      .eq("id", casamentoId)
      .maybeSingle();

    if (eventoError || !evento) {
      return json({ mensagem: "Evento não encontrado." }, 404);
    }

    if (["finalizado", "arquivado"].includes(String(evento.status))) {
      return json({ mensagem: "Não é possível enviar convites de um evento finalizado." }, 409);
    }

    let convidadosQuery = admin
      .from("convidados")
      .select("id, nome, email, whatsapp")
      .eq("casamento_id", casamentoId)
      .is("deleted_at", null)
      .not("email", "is", null)
      .order("nome");

    if (convidadoIds.length > 0) {
      convidadosQuery = convidadosQuery.in("id", convidadoIds);
    }

    const { data: convidados, error: convidadosError } = await convidadosQuery;
    if (convidadosError) {
      console.error("Erro ao carregar convidados", convidadosError);
      return json({ mensagem: "Não foi possível carregar os convidados." }, 500);
    }

    const { data: convites, error: convitesError } = await admin
      .from("convites_online")
      .select("id, convidado_id, status, canais_enviados")
      .eq("casamento_id", casamentoId);

    if (convitesError) {
      console.error("Erro ao carregar convites", convitesError);
      return json({ mensagem: "Não foi possível carregar os convites." }, 500);
    }

    let gmailAccessToken: string;
    try {
      gmailAccessToken = await obterTokenGmail({
        clientId: gmailClientId,
        clientSecret: gmailClientSecret,
        refreshToken: gmailRefreshToken,
      });
    } catch (error) {
      console.error("Erro na autorização do Gmail", error);
      return json(
        {
          mensagem:
            "O Gmail não está autorizado para o envio. Revise os segredos OAuth da Edge Function.",
        },
        503,
      );
    }

    const convitePorConvidado = new Map<string, Record<string, unknown>>();
    for (const convite of convites ?? []) {
      convitePorConvidado.set(String(convite.convidado_id), convite);
    }

    const enviados: ResultadoEnvio[] = [];
    const falhas: ResultadoEnvio[] = [];
    const ignorados: ResultadoEnvio[] = [];
    const links: Array<{ convidado_id: string; convite_id: string; link: string }> = [];

    for (const convidado of convidados ?? []) {
      const id = String(convidado.id);
      const nome = clean(convidado.nome) || "Convidado";
      const email = clean(convidado.email).toLowerCase();
      const conviteAtual = convitePorConvidado.get(id);
      const status = clean(conviteAtual?.status);
      const canais = asStringArray(conviteAtual?.canais_enviados);

      if (!isEmail(email)) {
        ignorados.push({
          convidado_id: id,
          nome,
          email,
          erro: "E-mail inválido ou não informado.",
        });
        continue;
      }

      if (["confirmado", "recusado"].includes(status) && !forcarReenvio) {
        ignorados.push({
          convidado_id: id,
          nome,
          email,
          erro: "O convidado já respondeu ao convite.",
        });
        continue;
      }

      if (canais.includes("email") && !forcarReenvio) {
        ignorados.push({
          convidado_id: id,
          nome,
          email,
          erro: "O e-mail já foi enviado.",
        });
        continue;
      }

      try {
        const { data: convite, error: criarError } = await usuario.rpc(
          "criar_convite_online_v1",
          {
            p_casamento_id: casamentoId,
            p_convidado_id: id,
          },
        );

        if (criarError || !isRecord(convite)) {
          throw new Error(criarError?.message || "Não foi possível criar o convite.");
        }

        const conviteId = clean(convite.id);
        const token = clean(convite.token);
        if (!conviteId || !token) {
          throw new Error("O convite não recebeu um link válido.");
        }

        const link = `${LINK_BASE}${encodeURIComponent(token)}`;
        links.push({ convidado_id: id, convite_id: conviteId, link });

        const mensagem = montarMensagem(
          nome,
          clean(evento.titulo),
          link,
          clean(evento.data_limite_confirmacao),
        );
        const emailResponse = await enviarGmail({
          accessToken: gmailAccessToken,
          from: fromEmail,
          to: email,
          subject: `Convite para ${clean(evento.titulo) || "o evento"}`,
          html: mensagem.html,
        });

        if (!emailResponse.ok) {
          throw new Error(emailResponse.erro || "O provedor recusou o e-mail.");
        }

        const canaisAtualizados = Array.from(new Set([...canais, "email"]));
        const { error: atualizarError } = await admin
          .from("convites_online")
          .update({
            canais_enviados: canaisAtualizados,
            ultimo_canal: "email",
            enviado_em: new Date().toISOString(),
            status: "enviado",
            ...(forcarReenvio
              ? { resposta: null, respondido_em: null }
              : {}),
          })
          .eq("id", conviteId);

        if (atualizarError) {
          throw new Error(
            "O e-mail foi aceito, mas não foi possível atualizar o status no banco.",
          );
        }

        enviados.push({ convidado_id: id, convite_id: conviteId, nome, email, link });
      } catch (error) {
        const mensagemErro =
          error instanceof Error ? error.message : "Falha no envio.";
        console.error(`Falha no convite ${id} (${email}): ${mensagemErro}`);
        falhas.push({
          convidado_id: id,
          nome,
          email,
          erro: mensagemErro,
        });
      }
    }

    return json({
      emails_solicitados: (convidados ?? []).length,
      emails_enviados: enviados.length,
      emails_falhos: falhas.length,
      emails_ignorados: ignorados.length,
      enviados,
      falhas,
      ignorados,
      links,
      mensagem: montarResumo(enviados.length, falhas.length, ignorados.length),
    });
  } catch (error) {
    console.error(error);
    return json({ mensagem: "Erro interno ao enviar os convites por e-mail." }, 500);
  }
});

async function validarAdmin(
  admin: ReturnType<typeof createClient>,
  token: string,
  casamentoId: string,
): Promise<{ valid: boolean; mensagem: string; status: number }> {
  if (!token) {
    return { valid: false, mensagem: "Sua sessão expirou.", status: 401 };
  }

  const { data: identidade, error: identidadeError } = await admin.auth.getUser(token);
  if (identidadeError || !identidade.user) {
    return { valid: false, mensagem: "Sua sessão expirou.", status: 401 };
  }

  const { data: casamento } = await admin
    .from("casamentos")
    .select("organizacao_id")
    .eq("id", casamentoId)
    .maybeSingle();
  if (!casamento) {
    return { valid: false, mensagem: "Evento não encontrado.", status: 404 };
  }

  const [{ data: adminOrganizacao }, { data: adminCasamento }] = await Promise.all([
    admin
      .from("membros_organizacao")
      .select("usuario_id")
      .eq("organizacao_id", casamento.organizacao_id)
      .eq("usuario_id", identidade.user.id)
      .eq("papel", "admin")
      .eq("ativo", true)
      .maybeSingle(),
    admin
      .from("membros_casamento")
      .select("usuario_id")
      .eq("casamento_id", casamentoId)
      .eq("usuario_id", identidade.user.id)
      .eq("papel", "admin")
      .eq("ativo", true)
      .maybeSingle(),
  ]);

  if (!adminOrganizacao && !adminCasamento) {
    return { valid: false, mensagem: "Somente administradoras podem enviar convites.", status: 403 };
  }

  return { valid: true, mensagem: "ok", status: 200 };
}

async function obterTokenGmail(input: {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
}): Promise<string> {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: input.clientId,
      client_secret: input.clientSecret,
      refresh_token: input.refreshToken,
      grant_type: "refresh_token",
    }),
  });

  const body = await response.text();
  let parsed: Record<string, unknown> = {};
  try {
    parsed = JSON.parse(body);
  } catch {
    // Mantém a mensagem genérica para não expor dados do OAuth.
  }

  const accessToken = clean(parsed.access_token);
  if (!response.ok || !accessToken) {
    throw new Error("O refresh token do Gmail foi recusado ou expirou.");
  }

  return accessToken;
}

async function enviarGmail(input: {
  accessToken: string;
  from: string;
  to: string;
  subject: string;
  html: string;
}): Promise<{ ok: boolean; erro?: string }> {
  const raw = [
    `From: ConfirmaAi <${input.from}>`,
    `To: ${input.to}`,
    `Subject: =?UTF-8?B?${base64Encode(input.subject)}?=`,
    "MIME-Version: 1.0",
    'Content-Type: text/html; charset="UTF-8"',
    "Content-Transfer-Encoding: 8bit",
    "",
    input.html,
  ].join("\r\n");

  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ raw: base64UrlEncode(raw) }),
    },
  );

  if (response.ok) {
    return { ok: true };
  }

  const body = await response.text();
  try {
    const parsed = JSON.parse(body);
    const detalhe = isRecord(parsed?.error) ? clean(parsed.error.message) : "";
    return {
      ok: false,
      erro: detalhe || "O Gmail recusou o e-mail.",
    };
  } catch {
    return { ok: false, erro: body || "O Gmail recusou o e-mail." };
  }
}

function base64UrlEncode(value: string): string {
  return base64Encode(value)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

function base64Encode(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function montarMensagem(
  nome: string,
  evento: string,
  link: string,
  prazoConfirmacao: string,
) {
  const tituloEvento = evento || "seu evento";
  const prazoTexto = prazoConfirmacao
    ? `\n\nConfirme sua presença até ${formatarData(prazoConfirmacao)}.`
    : "";
  const prazoHtml = prazoConfirmacao
    ? `<p><strong>Confirme sua presença até ${escapeHtml(formatarData(prazoConfirmacao))}.</strong></p>`
    : "";
  const texto = `Olá, ${nome}!\n\nVocê está convidado para ${tituloEvento}.${prazoTexto}\n\nAcesse o link abaixo para conferir os detalhes e confirmar sua presença:\n${link}\n\nSe você não solicitou este convite, ignore esta mensagem.`;
  const html = `<!doctype html><html lang="pt-BR"><body style="margin:0;background:#fff8f3;font-family:Arial,sans-serif;color:#3f2b25"><div style="max-width:600px;margin:24px auto;background:#fff;border-radius:18px;overflow:hidden"><div style="background:#ffd4c8;padding:28px 30px"><h1 style="margin:0;color:#ef6857">ConfirmaAi</h1><p style="margin:8px 0 0">Convite online</p></div><div style="padding:30px"><h2>Olá, ${escapeHtml(nome)}!</h2><p>Você está convidado para <strong>${escapeHtml(tituloEvento)}</strong>.</p>${prazoHtml}<p>Acesse o botão abaixo para conferir os detalhes e confirmar sua presença:</p><p><a href="${escapeHtml(link)}" style="display:inline-block;background:#ef6857;color:#fff;text-decoration:none;padding:14px 22px;border-radius:10px;font-weight:bold">Conferir convite</a></p><p style="font-size:13px;color:#806c65">Se você não solicitou este convite, ignore esta mensagem.</p></div></div></body></html>`;
  return { texto, html };
}

function formatarData(value: string): string {
  const partes = value.split("-");
  if (partes.length === 3) return `${partes[2]}/${partes[1]}/${partes[0]}`;
  return value;
}

function montarResumo(enviados: number, falhas: number, ignorados: number): string {
  return `${enviados} e-mail(ns) enviado(s), ${falhas} falha(s) e ${ignorados} ignorado(s).`;
}

function getBearerToken(request: Request): string {
  return (request.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
}

function getServiceRoleKey(): string | null {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const current = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!current) return null;
  try {
    const parsed = JSON.parse(current);
    const value = parsed?.default;
    return typeof value === "string" && value.trim() ? value : null;
  } catch {
    return null;
  }
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => clean(item)).filter(Boolean) : [];
}

function isEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function clean(value: unknown): string {
  return typeof value === "string" ? value.trim() : value == null ? "" : String(value).trim();
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}
