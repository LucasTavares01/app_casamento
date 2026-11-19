import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REDIRECT_LOGIN = "br.com.appcasamento://login-callback";
const LINK_WEB_CONVITE_FUNCIONARIO =
  "https://confirmaaiweb.netlify.app/convite-funcionario/?token=";
const USUARIOS_POR_PAGINA = 1000;

// O cliente administrativo é criado sem um tipo de banco gerado nesta função.
// Parametrizar o schema evita que o tipo padrão `unknown` do createClient
// transforme os retornos de consultas/RPC em `never` durante o deploy.
type AdminClient = ReturnType<typeof createClient<any, "public">>;

type ResultadoNotificacao = {
  enviada: boolean;
  mensagem: string | null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ mensagem: "Método não permitido." }, 405);
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = getServiceRoleKey();

  if (!token || !supabaseUrl || !serviceRoleKey) {
    return json({ mensagem: "Não foi possível validar sua sessão." }, 401);
  }

  try {
    const body = await request.json();
    const casamentoId = text(body?.casamento_id);
    const funcionarioId = text(body?.funcionario_id);
    const nome = text(body?.nome);
    const email = normalizeEmail(body?.email);
    const telefoneInformado = normalizePhone(body?.telefone);

    if (!casamentoId || (!funcionarioId && !nome)) {
      return json(
        { mensagem: "Nome e evento são obrigatórios." },
        400,
      );
    }

    if (email && !isValidEmail(email)) {
      return json({ mensagem: "E-mail inválido." }, 400);
    }

    if (text(body?.telefone) && !telefoneInformado) {
      return json(
        { mensagem: "Número de WhatsApp inválido. Use DDD e número." },
        400,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    });

    const { data: identidade, error: erroIdentidade } =
      await admin.auth.getUser(token);

    if (erroIdentidade || !identidade.user) {
      return json({ mensagem: "Sua sessão expirou. Entre novamente." }, 401);
    }

    const solicitanteId = identidade.user.id;

    const { data: casamento, error: erroCasamento } = await admin
      .from("casamentos")
      .select("organizacao_id, titulo, tipo_evento, data_evento, hora_evento, local_evento")
      .eq("id", casamentoId)
      .maybeSingle();

    if (erroCasamento || !casamento) {
      return json({ mensagem: "Evento não encontrado." }, 404);
    }

    const [{ data: adminOrganizacao }, { data: adminCasamento }] =
      await Promise.all([
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
      return json(
        { mensagem: "Somente administradoras podem convidar funcionários." },
        403,
      );
    }

    let usuarioId: string;
    let emailDestino: string | null;
    let nomeDestino: string;
    let telefoneDestino: string | null = telefoneInformado;
    let conviteEnviado = false;
    let contaJaExistia = false;
    const tokenConvite = gerarTokenConvite();
    const hashTokenConvite = await sha256Hex(tokenConvite);
    const linkConviteApp =
      `${LINK_WEB_CONVITE_FUNCIONARIO}${encodeURIComponent(tokenConvite)}`;

    if (funcionarioId) {
      const { data: funcionario, error: erroFuncionario } = await admin
        .from("funcionarios_organizacao")
        .select("usuario_id, nome, email, telefone")
        .eq("id", funcionarioId)
        .eq("organizacao_id", casamento.organizacao_id)
        .eq("ativo", true)
        .maybeSingle();

      if (erroFuncionario || !funcionario) {
        return json(
          { mensagem: "Funcionário não encontrado na sua equipe." },
          404,
        );
      }

      usuarioId = funcionario.usuario_id;
      emailDestino = normalizeEmail(funcionario.email);
      nomeDestino = text(funcionario.nome);
      telefoneDestino = normalizePhone(funcionario.telefone);
      contaJaExistia = true;

      if (emailDestino && !isValidEmail(emailDestino)) {
        return json(
          { mensagem: "O funcionário possui um e-mail inválido." },
          400,
        );
      }
      if (!emailDestino && !telefoneDestino) {
        return json(
          { mensagem: "O funcionário precisa ter um e-mail ou WhatsApp." },
          400,
        );
      }
    } else {
      const perfil = isValidEmail(email)
        ? await buscarPerfilPorEmail(admin, email)
        : { usuarioId: null, erro: null, status: 200 };

      if (perfil.erro) {
        return json({ mensagem: perfil.erro }, perfil.status);
      }

      emailDestino = isValidEmail(email) ? email : null;
      nomeDestino = nome;

      if (perfil.usuarioId) {
        usuarioId = perfil.usuarioId;
        contaJaExistia = true;
      } else if (!emailDestino) {
        // O convite por WhatsApp não precisa de um e-mail. O usuário Auth
        // técnico é substituído pela conta Google ou pelo e-mail informado
        // na tela de primeiro acesso.
        const emailTecnico = `convite-${crypto.randomUUID()}@convites.confirmaai.local`;
        const { data: convite, error: erroConvite } =
          await admin.auth.admin.createUser({
            email: emailTecnico,
            password: gerarSenhaInterna(),
            email_confirm: true,
            user_metadata: {
              nome,
              marca_nome: "ConfirmaAi",
              casamento_nome: text(casamento.titulo),
              evento_nome: text(casamento.titulo),
              evento_tipo: text(casamento.tipo_evento),
              evento_data: text(casamento.data_evento),
              evento_horario: text(casamento.hora_evento),
              evento_local: text(casamento.local_evento),
              casamento_id: casamentoId,
              abrir_como_funcionario: true,
              criar_organizacao: false,
              precisa_definir_senha: true,
              convite_app_token: tokenConvite,
              convite_app_link: linkConviteApp,
            },
          });

        if (erroConvite || !convite.user?.id) {
          return json(
            { mensagem: "Não foi possível preparar o acesso do funcionário." },
            500,
          );
        }

        usuarioId = convite.user.id;
      } else {
        const { data: convite, error: erroConvite } =
          await admin.auth.admin.inviteUserByEmail(email, {
            data: {
              nome,
              marca_nome: "ConfirmaAi",
              casamento_nome: text(casamento.titulo),
              evento_nome: text(casamento.titulo),
              evento_tipo: text(casamento.tipo_evento),
              evento_data: text(casamento.data_evento),
              evento_horario: text(casamento.hora_evento),
              evento_local: text(casamento.local_evento),
              casamento_id: casamentoId,
              abrir_como_funcionario: true,
              criar_organizacao: false,
              precisa_definir_senha: true,
              convite_app_token: tokenConvite,
              convite_app_link: linkConviteApp,
            },
            redirectTo: REDIRECT_LOGIN,
          });

        if (!erroConvite && convite.user?.id) {
          usuarioId = convite.user.id;
          conviteEnviado = true;
        } else if (isExistingUserError(erroConvite)) {
          const usuarioExistente =
            await buscarUsuarioAuthPorEmail(admin, email);

          if (!usuarioExistente) {
            return json(
              {
                mensagem:
                  "A conta já existe, mas não foi possível localizá-la para liberar o acesso.",
              },
              409,
            );
          }

          usuarioId = usuarioExistente.id;
          contaJaExistia = true;

          const { error: erroPerfil } = await admin
            .from("usuarios_app")
            .upsert(
              {
                id: usuarioId,
                nome: nomeDestino,
                email: emailDestino,
                ordem: 0,
                ativo: true,
              },
              { onConflict: "id" },
            );

          if (erroPerfil) {
            return json(
              {
                mensagem:
                  "Não foi possível reparar o perfil da conta existente.",
              },
              409,
            );
          }
        } else {
          return json(
            {
              mensagem: friendlyAuthError(
                erroConvite,
                "Não foi possível enviar o convite por e-mail.",
              ),
            },
            authErrorStatus(erroConvite),
          );
        }
      }

      const { error: erroEquipe } = await admin
        .from("funcionarios_organizacao")
        .upsert(
          {
            organizacao_id: casamento.organizacao_id,
            usuario_id: usuarioId,
            nome: nomeDestino,
            email: emailDestino,
            telefone: telefoneDestino,
            ativo: true,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "organizacao_id,usuario_id" },
        );

      if (erroEquipe) {
        console.error("Erro ao salvar funcionário", erroEquipe);
        return json(
          { mensagem: "Não foi possível salvar a pessoa na equipe." },
          500,
        );
      }
    }

    const contaJaCerimonialista =
      await usuarioPossuiPerfilCerimonialista(admin, usuarioId);

    const { error: erroVinculo } = await admin
      .from("membros_casamento")
      .upsert(
        {
          casamento_id: casamentoId,
          usuario_id: usuarioId,
          papel: "funcionario",
          ativo: true,
          convite_aceito_em: null,
          criado_por_usuario_id: solicitanteId,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "casamento_id,usuario_id" },
      );

    if (erroVinculo) {
      console.error("Erro ao liberar casamento", erroVinculo);
      return json(
        {
          mensagem:
            "O funcionário foi salvo, mas não foi possível liberar o casamento.",
        },
        500,
      );
    }

    const metadadosPreparados = await atualizarMetadadosDoConvite(
      admin,
      usuarioId,
      nomeDestino,
      text(casamento.titulo),
      casamentoId,
      text(casamento.tipo_evento),
      text(casamento.data_evento),
      text(casamento.hora_evento),
      text(casamento.local_evento),
      tokenConvite,
      linkConviteApp,
    );

    if (!metadadosPreparados) {
      return json(
        {
          mensagem:
            "O acesso foi liberado, mas não foi possível preparar o e-mail do evento.",
        },
        500,
      );
    }

    const { error: erroToken } = await admin
      .from("convites_funcionario_app")
      .upsert(
        {
          casamento_id: casamentoId,
          organizacao_id: casamento.organizacao_id,
          usuario_id: usuarioId,
          email: emailDestino,
          token_hash: hashTokenConvite,
          expira_em: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          usado_em: null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "casamento_id,usuario_id" },
      );

    if (erroToken) {
      console.error("Erro ao salvar token próprio do convite", erroToken);
      return json(
        { mensagem: "Não foi possível preparar o link seguro do convite." },
        500,
      );
    }

    const notificacao: ResultadoNotificacao = conviteEnviado
      ? { enviada: true, mensagem: null }
      : emailDestino
      ? await enviarLinkDeAcesso(admin, emailDestino)
      : {
          enviada: false,
          mensagem: "Envie o link seguro pelo WhatsApp para o funcionário.",
        };

    const linkWhatsApp = telefoneDestino ? linkConviteApp : null;

    return json({
      usuario_id: usuarioId,
      nome: nomeDestino,
      email: emailDestino,
      convite_enviado: conviteEnviado,
      notificacao_enviada: notificacao.enviada,
      mensagem_notificacao: notificacao.mensagem,
      telefone_whatsapp: telefoneDestino,
      link_whatsapp: linkWhatsApp,
      conta_ja_existia: contaJaExistia,
      conta_mista: contaJaCerimonialista,
    });
  } catch (error) {
    console.error(error);
    return json({ mensagem: "Erro inesperado ao enviar o convite." }, 500);
  }
});

async function buscarPerfilPorEmail(
  admin: AdminClient,
  email: string,
): Promise<{ usuarioId: string | null; erro: string | null; status: number }> {
  const { data, error } = await admin.rpc(
    "buscar_usuarios_app_por_email_v1",
    { p_email: email },
  );

  if (error) {
    console.error("Erro ao procurar perfil", error);
    return {
      usuarioId: null,
      erro: "Não foi possível verificar se o e-mail já possui uma conta.",
      status: 500,
    };
  }

  const perfis = Array.isArray(data) ? data : [];
  const perfisValidos: string[] = [];

  for (const perfil of perfis) {
    const usuarioId = text(perfil?.id);
    if (!usuarioId) continue;

    const { data: usuarioAuth, error: erroAuth } =
      await admin.auth.admin.getUserById(usuarioId);

    if (!erroAuth && usuarioAuth.user) {
      const emailAuth = normalizeEmail(usuarioAuth.user.email);
      if (emailAuth === email) {
        perfisValidos.push(usuarioId);
      } else {
        console.error(
          "Perfil e usuário Auth não correspondem ao mesmo e-mail",
          { usuarioId, emailPerfil: email, emailAuth },
        );
      }
      continue;
    }

    if (isAuthUserMissing(erroAuth)) {
      const { error: erroLimpeza } = await admin
        .from("usuarios_app")
        .delete()
        .eq("id", usuarioId);

      if (erroLimpeza) {
        console.error("Não foi possível remover perfil órfão", erroLimpeza);
        return {
          usuarioId: null,
          erro:
            "Foi encontrado um cadastro antigo incompleto. Não foi possível corrigi-lo automaticamente; tente excluir esse cadastro e enviar o convite novamente.",
          status: 500,
        };
      }

      console.warn("Perfil órfão removido antes de reenviar convite", usuarioId);
      continue;
    }

    console.error("Erro ao verificar usuário do perfil", erroAuth);
    return {
      usuarioId: null,
      erro: "Não foi possível verificar a conta existente. Tente novamente.",
      status: 500,
    };
  }

  if (perfisValidos.length > 1) {
    return {
      usuarioId: null,
      erro:
        "Existem contas duplicadas para este e-mail. Exclua as duplicadas antes de convidar novamente.",
      status: 409,
    };
  }

  return {
    usuarioId: perfisValidos[0] ?? null,
    erro: null,
    status: 200,
  };
}

async function buscarUsuarioAuthPorEmail(
  admin: AdminClient,
  email: string,
): Promise<{ id: string } | null> {
  for (let pagina = 1; pagina <= 100; pagina += 1) {
    const { data, error } = await admin.auth.admin.listUsers({
      page: pagina,
      perPage: USUARIOS_POR_PAGINA,
    });

    if (error) {
      console.error("Erro ao procurar usuário no Auth", error);
      return null;
    }

    const encontrado = data.users.find(
      (usuario) => normalizeEmail(usuario.email) === email,
    );

    if (encontrado) return { id: encontrado.id };
    if (data.users.length < USUARIOS_POR_PAGINA) return null;
  }

  return null;
}

async function usuarioPossuiPerfilCerimonialista(
  admin: AdminClient,
  usuarioId: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("membros_organizacao")
    .select("organizacao_id")
    .eq("usuario_id", usuarioId)
    .eq("papel", "admin")
    .eq("ativo", true)
    .limit(1);

  if (error) {
    console.error("Erro ao verificar perfil de cerimonialista", error);
    return false;
  }

  return (data?.length ?? 0) > 0;
}

async function atualizarMetadadosDoConvite(
  admin: AdminClient,
  usuarioId: string,
  nome: string,
  eventoNome: string,
  casamentoId: string,
  eventoTipo: string,
  eventoData: string,
  eventoHorario: string,
  eventoLocal: string,
  conviteAppToken: string,
  conviteAppLink: string,
): Promise<boolean> {
  const { data: usuarioAtual, error: erroLeitura } =
    await admin.auth.admin.getUserById(usuarioId);

  if (erroLeitura || !usuarioAtual.user) {
    console.error("Erro ao ler metadados do usuário", erroLeitura);
    return false;
  }

  const metadadosAtuais = usuarioAtual.user.user_metadata ?? {};
  const nomeAtual =
    text(metadadosAtuais.nome) || text(metadadosAtuais.full_name);

  const { error: erroAtualizacao } =
    await admin.auth.admin.updateUserById(usuarioId, {
      user_metadata: {
        ...metadadosAtuais,
        nome: nomeAtual || nome,
        marca_nome: "ConfirmaAi",
        casamento_nome: eventoNome,
        evento_nome: eventoNome,
        evento_tipo: eventoTipo,
        evento_data: eventoData,
        evento_horario: eventoHorario,
        evento_local: eventoLocal,
        casamento_id: casamentoId,
        abrir_como_funcionario: true,
        convite_app_token: conviteAppToken,
        convite_app_link: conviteAppLink,
      },
    });

  if (erroAtualizacao) {
    console.error("Erro ao atualizar metadados do convite", erroAtualizacao);
    return false;
  }

  return true;
}

async function enviarLinkDeAcesso(
  admin: AdminClient,
  email: string,
): Promise<ResultadoNotificacao> {
  const { error } = await admin.auth.signInWithOtp({
    email,
    options: {
      shouldCreateUser: false,
      emailRedirectTo: REDIRECT_LOGIN,
    },
  });

  if (!error) return { enviada: true, mensagem: null };

  console.error("Erro ao enviar link de acesso", error);
  return {
    enviada: false,
    mensagem: friendlyAuthError(
      error,
      "O acesso foi liberado, mas o e-mail não pôde ser enviado.",
    ),
  };
}

function gerarTokenConvite(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

function gerarSenhaInterna(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return `C!${base64Url(bytes)}9a`;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function isExistingUserError(error: unknown): boolean {
  const code = authErrorCode(error);
  return code === "user_already_exists" || code === "email_exists";
}

function isAuthUserMissing(error: unknown): boolean {
  if (!error) return false;

  const code = authErrorCode(error).toLowerCase();
  const status = authErrorStatus(error);
  const message = authErrorMessage(error).toLowerCase();

  return (
    status === 404 ||
    code === "user_not_found" ||
    code === "not_found" ||
    message.includes("user not found") ||
    message.includes("user does not exist")
  );
}

function friendlyAuthError(error: unknown, fallback: string): string {
  const code = authErrorCode(error);
  const status = authErrorStatus(error);

  if (status === 429 || code === "over_email_send_rate_limit") {
    return "Muitos e-mails foram solicitados em pouco tempo. Aguarde pelo menos 60 segundos e tente novamente.";
  }

  if (code === "email_address_not_authorized") {
    return "O provedor de e-mail não está autorizado a enviar para este endereço.";
  }

  if (code === "email_address_invalid") {
    return "O endereço de e-mail informado não é aceito pelo provedor.";
  }

  if (code === "otp_disabled") {
    return "O envio do link de acesso está desativado nas configurações de autenticação.";
  }

  const message = authErrorMessage(error);
  return message || fallback;
}

function authErrorCode(error: unknown): string {
  if (typeof error !== "object" || error === null) return "";
  const value = (error as Record<string, unknown>).code;
  return typeof value === "string" ? value : "";
}

function authErrorMessage(error: unknown): string {
  if (typeof error !== "object" || error === null) return "";
  const value = (error as Record<string, unknown>).message;
  return typeof value === "string" ? value : "";
}

function authErrorStatus(error: unknown): number {
  if (typeof error !== "object" || error === null) return 400;
  const value = (error as Record<string, unknown>).status;
  return typeof value === "number" && value >= 400 ? value : 400;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeEmail(value: unknown): string {
  return text(value).toLowerCase();
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function normalizePhone(value: unknown): string | null {
  const digits = text(value).replace(/\D/g, "");
  if (!digits) return null;

  const withCountryCode = digits.startsWith("55") ? digits : `55${digits}`;
  if (withCountryCode.length !== 12 && withCountryCode.length !== 13) {
    return null;
  }

  return withCountryCode;
}

function getServiceRoleKey(): string | null {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const current = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!current) return null;

  try {
    const value = JSON.parse(current)?.default;
    return typeof value === "string" && value.trim() ? value : null;
  } catch {
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
