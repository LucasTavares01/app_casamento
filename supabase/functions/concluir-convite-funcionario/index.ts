import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AdminClient = ReturnType<typeof createClient<any, "public">>;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return json({ ok: true });
  }

  if (request.method !== "POST") {
    return json({ mensagem: "Método não permitido." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = getServiceRoleKey();
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ mensagem: "O servidor de convites não está configurado." }, 503);
  }

  try {
    const body = await request.json();
    const token = text(body?.token);
    const acao = text(body?.acao);
    const senha = text(body?.senha);
    const emailInformado = normalizeEmail(body?.email);

    if (!acao || !["dados", "senha", "google", "pendente"].includes(acao)) {
      return json({ mensagem: "O convite está incompleto." }, 400);
    }

    const admin: AdminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    });

    if (acao === "pendente") {
      const authorization = request.headers.get("Authorization") ?? "";
      const bearer = authorization.replace(/^Bearer\s+/i, "").trim();
      if (!bearer) {
        return json({ mensagem: "Faça login para verificar o convite." }, 401);
      }

      const { data: autenticado, error: erroAutenticado } =
        await admin.auth.getUser(bearer);
      const emailAutenticado = normalizeEmail(autenticado.user?.email);
      if (erroAutenticado || !autenticado.user || !emailAutenticado) {
        return json({ mensagem: "A sessão do usuário não é válida." }, 401);
      }

      const { data: convitePendente, error: erroConvitePendente } = await admin
        .from("convites_funcionario_app")
        .select("id, usuario_id, email, expira_em, usado_em, updated_at")
        .eq("email", emailAutenticado)
        .is("usado_em", null)
        .gt("expira_em", new Date().toISOString())
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (erroConvitePendente) {
        console.error("Erro ao procurar convite pendente", erroConvitePendente);
        return json({ mensagem: "Não foi possível verificar o convite." }, 500);
      }

      if (!convitePendente) return json({ ok: true, pendente: false });

      const novoToken = gerarTokenConvite();
      const { error: erroNovoToken } = await admin
        .from("convites_funcionario_app")
        .update({
          token_hash: await sha256Hex(novoToken),
          expira_em: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", convitePendente.id)
        .is("usado_em", null);

      if (erroNovoToken) {
        console.error("Erro ao renovar token do convite pendente", erroNovoToken);
        return json({ mensagem: "Não foi possível preparar o convite." }, 500);
      }

      const { data: usuarioPendente, error: erroUsuarioPendente } =
        await admin.auth.admin.getUserById(convitePendente.usuario_id);
      const metadados = autenticado.user.user_metadata ?? {};
      const nome =
        text(metadados.nome) ||
        text(metadados.full_name) ||
        text(usuarioPendente?.user?.user_metadata?.nome) ||
        text(usuarioPendente?.user?.user_metadata?.full_name) ||
        emailAutenticado.split("@")[0];

      if (erroUsuarioPendente && !usuarioPendente?.user) {
        return json({ mensagem: "A conta deste convite não está disponível." }, 410);
      }

      return json({
        ok: true,
        pendente: true,
        token: novoToken,
        email: emailAutenticado,
        nome,
      });
    }

    if (!token) {
      return json({ mensagem: "O convite está incompleto." }, 400);
    }

    const hash = await sha256Hex(token);
    const { data: convite, error: erroConvite } = await admin
      .from("convites_funcionario_app")
      .select("id, usuario_id, email, expira_em, usado_em")
      .eq("token_hash", hash)
      .maybeSingle();

    if (erroConvite || !convite) {
      return json({ mensagem: "Este convite não é válido." }, 410);
    }

    if (convite.usado_em || new Date(convite.expira_em).getTime() <= Date.now()) {
      return json({ mensagem: "Este convite expirou. Peça um novo convite." }, 410);
    }

    const { data: usuario, error: erroUsuario } =
      await admin.auth.admin.getUserById(convite.usuario_id);
    if (erroUsuario || !usuario.user) {
      return json({ mensagem: "A conta deste convite não está disponível." }, 410);
    }

    if (acao === "dados") {
      return json({
        ok: true,
        email: convite.email,
        nome:
          text(usuario.user.user_metadata?.nome) ||
          text(usuario.user.user_metadata?.full_name) ||
          text(usuario.user.email).split("@")[0],
      });
    }

    if (acao === "senha") {
      if (senha.length < 6) {
        return json({ mensagem: "A senha precisa ter pelo menos 6 caracteres." }, 400);
      }

      const emailDestino = normalizeEmail(convite.email) || emailInformado;
      if (!isValidEmail(emailDestino)) {
        return json(
          { mensagem: "Informe um e-mail válido para concluir o acesso." },
          400,
        );
      }

      const usuarioComMesmoEmail = await buscarUsuarioAuthPorEmail(admin, emailDestino);
      if (usuarioComMesmoEmail && usuarioComMesmoEmail.id !== convite.usuario_id) {
        return json({ mensagem: "Este e-mail já está vinculado a outra conta." }, 409);
      }

      const metadados = {
        ...(usuario.user.user_metadata ?? {}),
        precisa_definir_senha: false,
        criar_organizacao: false,
        cadastro_concluido: true,
        abrir_como_funcionario: true,
        convite_app_token: null,
        convite_app_link: null,
      };

      const { error: erroAtualizacao } =
        await admin.auth.admin.updateUserById(convite.usuario_id, {
          email: emailDestino,
          password: senha,
          email_confirm: true,
          user_metadata: metadados,
        });

      if (erroAtualizacao) {
        console.error("Erro ao concluir convite com senha", erroAtualizacao);
        return json({ mensagem: "Não foi possível criar o acesso agora." }, 500);
      }

      await admin
        .from("convites_funcionario_app")
        .update({ email: emailDestino })
        .eq("id", convite.id);
      await admin
        .from("funcionarios_organizacao")
        .update({ email: emailDestino, updated_at: new Date().toISOString() })
        .eq("usuario_id", convite.usuario_id);
      await admin
        .from("usuarios_app")
        .update({ email: emailDestino })
        .eq("id", convite.usuario_id);

      await marcarComoUsado(admin, convite.id);
      return json({ ok: true, email: emailDestino });
    }

    const emailConvite = normalizeEmail(convite.email);
    if (emailConvite && !isGmail(emailConvite)) {
      return json(
        { mensagem: "Este convite deve ser concluído criando uma senha." },
        400,
      );
    }

    const authorization = request.headers.get("Authorization") ?? "";
    const bearer = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!bearer) {
      return json({ mensagem: "Faça o acesso com Google para continuar." }, 401);
    }

    const { data: identidade, error: erroIdentidade } =
      await admin.auth.getUser(bearer);
    const emailAtual = normalizeEmail(identidade.user?.email);
    if (erroIdentidade || !identidade.user ||
        (emailConvite && emailAtual !== emailConvite)) {
      return json(
        { mensagem: "Use a mesma conta Google que recebeu o convite." },
        403,
      );
    }

    if (identidade.user.id !== convite.usuario_id) {
      try {
        await migrarConviteParaContaGoogle(
          admin,
          convite,
          usuario.user,
          identidade.user,
        );
      } catch (erroMigracao) {
        console.error("Erro ao migrar convite para a conta Google", erroMigracao);
        return json(
          {
            mensagem:
              "Não foi possível vincular esta conta Google ao convite. Tente novamente ou crie uma senha.",
          },
          409,
        );
      }
    }

    const { error: erroGoogle } = await admin.auth.admin.updateUserById(
      identidade.user.id,
      {
        user_metadata: {
          ...(identidade.user.user_metadata ?? {}),
          precisa_definir_senha: false,
          criar_organizacao: false,
          cadastro_concluido: true,
          abrir_como_funcionario: true,
          convite_app_token: null,
          convite_app_link: null,
        },
      },
    );
    if (erroGoogle) {
      return json({ mensagem: "Não foi possível concluir o cadastro Google." }, 500);
    }

    await admin
      .from("convites_funcionario_app")
      .update({ email: emailAtual })
      .eq("id", convite.id);
    await admin
      .from("funcionarios_organizacao")
      .update({ email: emailAtual, updated_at: new Date().toISOString() })
      .eq("usuario_id", identidade.user.id);
    await admin
      .from("usuarios_app")
      .update({ email: emailAtual })
      .eq("id", identidade.user.id);

    await marcarComoUsado(admin, convite.id);
    return json({ ok: true, email: convite.email });
  } catch (error) {
    console.error("Erro ao concluir convite próprio", error);
    return json({ mensagem: "Não foi possível concluir o convite." }, 500);
  }
});

async function migrarConviteParaContaGoogle(
  admin: AdminClient,
  convite: { id: string; usuario_id: string; email: string },
  usuarioAntigo: { id: string; user_metadata?: Record<string, unknown> | null },
  usuarioGoogle: { id: string; email?: string | null; user_metadata?: Record<string, unknown> | null },
): Promise<void> {
  const usuarioAntigoId = convite.usuario_id;
  const usuarioGoogleId = usuarioGoogle.id;

  const { data: organizacoes, error: erroOrganizacoes } = await admin
    .from("membros_organizacao")
    .select("organizacao_id")
    .eq("usuario_id", usuarioAntigoId)
    .eq("ativo", true);

  if (erroOrganizacoes) throw erroOrganizacoes;
  if ((organizacoes?.length ?? 0) > 0) {
    throw new Error("A conta antiga do convite já possui uma organização.");
  }

  const nome =
    text(usuarioGoogle.user_metadata?.nome) ||
    text(usuarioGoogle.user_metadata?.full_name) ||
    text(usuarioAntigo.user_metadata?.nome) ||
    text(usuarioAntigo.user_metadata?.full_name) ||
    text(usuarioGoogle.email).split("@")[0] ||
    "Funcionário";

  const { error: erroPerfil } = await admin.from("usuarios_app").upsert(
    {
      id: usuarioGoogleId,
      nome,
      email: normalizeEmail(usuarioGoogle.email ?? convite.email),
      ordem: 0,
      ativo: true,
    },
    { onConflict: "id" },
  );
  if (erroPerfil) throw erroPerfil;

  for (const tabela of ["funcionarios_organizacao", "membros_casamento"]) {
    const { error } = await admin
      .from(tabela)
      .update({ usuario_id: usuarioGoogleId })
      .eq("usuario_id", usuarioAntigoId);
    if (error) throw error;
  }

  const { error: erroConvite } = await admin
    .from("convites_funcionario_app")
    .update({ usuario_id: usuarioGoogleId })
    .eq("id", convite.id);
  if (erroConvite) throw erroConvite;

  const { error: erroPerfilAntigo } = await admin
    .from("usuarios_app")
    .delete()
    .eq("id", usuarioAntigoId);
  if (erroPerfilAntigo) throw erroPerfilAntigo;

  const { error: erroUsuarioAntigo } =
    await admin.auth.admin.deleteUser(usuarioAntigoId);
  if (erroUsuarioAntigo) throw erroUsuarioAntigo;
}

async function marcarComoUsado(admin: AdminClient, id: string) {
  const { error } = await admin
    .from("convites_funcionario_app")
    .update({ usado_em: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", id)
    .is("usado_em", null);
  if (error) throw error;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeEmail(value: unknown): string {
  return text(value).toLowerCase();
}

async function buscarUsuarioAuthPorEmail(
  admin: AdminClient,
  email: string,
): Promise<{ id: string } | null> {
  for (let pagina = 1; pagina <= 100; pagina += 1) {
    const { data, error } = await admin.auth.admin.listUsers({
      page: pagina,
      perPage: 1000,
    });
    if (error) throw error;

    const usuario = data.users.find(
      (item) => normalizeEmail(item.email) === email,
    );
    if (usuario) return { id: usuario.id };
    if (data.users.length < 1000) return null;
  }
  return null;
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isGmail(value: unknown): boolean {
  return normalizeEmail(value).endsWith("@gmail.com");
}

function gerarTokenConvite(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

function base64Url(bytes: Uint8Array): string {
  let binario = "";
  for (const byte of bytes) binario += String.fromCharCode(byte);
  return btoa(binario).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
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
