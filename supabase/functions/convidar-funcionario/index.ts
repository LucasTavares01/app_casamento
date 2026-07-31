import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REDIRECT_LOGIN = "br.com.appcasamento://login-callback";
const USUARIOS_POR_PAGINA = 1000;

type AdminClient = ReturnType<typeof createClient>;

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

    if (!casamentoId || (!funcionarioId && (!nome || !isValidEmail(email)))) {
      return json(
        { mensagem: "Funcionário, e-mail e casamento são obrigatórios." },
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

    const { data: identidade, error: erroIdentidade } = await admin.auth.getUser(
      token,
    );
    if (erroIdentidade || !identidade.user) {
      return json({ mensagem: "Sua sessão expirou. Entre novamente." }, 401);
    }

    const solicitanteId = identidade.user.id;
    const { data: casamento, error: erroCasamento } = await admin
      .from("casamentos")
      .select("organizacao_id, titulo")
      .eq("id", casamentoId)
      .maybeSingle();
    if (erroCasamento || !casamento) {
      return json({ mensagem: "Casamento não encontrado." }, 404);
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
    let emailDestino: string;
    let nomeDestino: string;
    let conviteEnviado = false;

    if (funcionarioId) {
      const { data: funcionario, error: erroFuncionario } = await admin
        .from("funcionarios_organizacao")
        .select("usuario_id, nome, email")
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

      if (!isValidEmail(emailDestino)) {
        return json(
          { mensagem: "O funcionário não possui um e-mail válido." },
          400,
        );
      }
    } else {
      const perfil = await buscarPerfilPorEmail(admin, email);
      if (perfil.erro) {
        return json({ mensagem: perfil.erro }, perfil.status);
      }

      emailDestino = email;
      nomeDestino = nome;

      if (perfil.usuarioId) {
        usuarioId = perfil.usuarioId;
      } else {
        const { data: convite, error: erroConvite } =
          await admin.auth.admin.inviteUserByEmail(email, {
            data: {
              nome,
              casamento_nome: text(casamento.titulo),
              casamento_id: casamentoId,
              criar_organizacao: false,
              precisa_definir_senha: true,
            },
            redirectTo: REDIRECT_LOGIN,
          });

        if (!erroConvite && convite.user?.id) {
          usuarioId = convite.user.id;
          conviteEnviado = true;
        } else if (isExistingUserError(erroConvite)) {
          const usuarioExistente = await buscarUsuarioAuthPorEmail(admin, email);
          if (!usuarioExistente) {
            return json(
              {
                mensagem:
                  "A conta já existe no Auth, mas não foi possível localizá-la para liberar o acesso.",
              },
              409,
            );
          }
          usuarioId = usuarioExistente.id;

          const { error: erroPerfil } = await admin.from("usuarios_app").upsert(
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
              { mensagem: "Não foi possível reparar o perfil da conta existente." },
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

    const { error: erroVinculo } = await admin.from("membros_casamento").upsert(
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

    // Mantém o nome do casamento nos metadados da conta. O Supabase expõe
    // esses dados nos templates de e-mail por meio de {{ .Data.casamento_nome }}.
    // Para contas novas, o dado também é enviado no próprio convite acima.
    const metadadosPreparados = await atualizarMetadadosDoConvite(
      admin,
      usuarioId,
      nomeDestino,
      text(casamento.titulo),
      casamentoId,
    );

    if (!metadadosPreparados) {
      return json(
        {
          mensagem:
            "O acesso foi liberado, mas não foi possível preparar o e-mail com o nome do casamento.",
        },
        500,
      );
    }

    // Uma conta nova já recebe o template de convite por inviteUserByEmail.
    // Contas existentes recebem apenas um Magic Link. O aplicativo não tenta
    // enviar uma segunda mensagem, evitando duplicidade e rate limit.
    const notificacao: ResultadoNotificacao = conviteEnviado
      ? { enviada: true, mensagem: null }
      : await enviarLinkDeAcesso(admin, emailDestino);

    return json({
      usuario_id: usuarioId,
      nome: nomeDestino,
      email: emailDestino,
      convite_enviado: conviteEnviado,
      notificacao_enviada: notificacao.enviada,
      mensagem_notificacao: notificacao.mensagem,
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

  if ((data?.length ?? 0) > 1) {
    return {
      usuarioId: null,
      erro:
        "Existem contas duplicadas para este e-mail. Exclua as duplicadas antes de convidar novamente.",
      status: 409,
    };
  }

  return {
    usuarioId: data?.[0]?.id ?? null,
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

async function atualizarMetadadosDoConvite(
  admin: AdminClient,
  usuarioId: string,
  nome: string,
  casamentoNome: string,
  casamentoId: string,
): Promise<boolean> {
  const { data: usuarioAtual, error: erroLeitura } =
    await admin.auth.admin.getUserById(usuarioId);

  if (erroLeitura || !usuarioAtual.user) {
    console.error("Erro ao ler metadados do usuário", erroLeitura);
    return false;
  }

  const metadadosAtuais = usuarioAtual.user.user_metadata ?? {};
  const { error: erroAtualizacao } = await admin.auth.admin.updateUserById(
    usuarioId,
    {
      user_metadata: {
        ...metadadosAtuais,
        nome,
        casamento_nome: casamentoNome,
        casamento_id: casamentoId,
      },
    },
  );

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

function isExistingUserError(error: unknown): boolean {
  const code = authErrorCode(error);
  return code === "user_already_exists" || code === "email_exists";
}

function friendlyAuthError(error: unknown, fallback: string): string {
  const code = authErrorCode(error);
  const status = authErrorStatus(error);

  if (status === 429 || code === "over_email_send_rate_limit") {
    return "Muitos e-mails foram solicitados em pouco tempo. Aguarde pelo menos 60 segundos e tente novamente.";
  }
  if (code === "email_address_not_authorized") {
    return "O provedor de e-mail do Supabase não está autorizado a enviar para este endereço. Configure um SMTP próprio no projeto.";
  }
  if (code === "email_address_invalid") {
    return "O endereço de e-mail informado não é aceito pelo provedor.";
  }
  if (code === "otp_disabled") {
    return "O envio de Magic Link está desativado nas configurações de autenticação.";
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
