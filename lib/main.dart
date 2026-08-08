import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicos/dispositivo_servico.dart';
import 'servicos/monitor_conexao_servico.dart';
import 'servicos/convite_funcionario_link_servico.dart';
import 'servicos/sessao_servico.dart';
import 'servicos/sincronizacao_automatica_servico.dart';
import 'telas/porta_entrada.dart';
import 'telas/tela_primeiro_acesso_funcionario.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rtidfwtjjpgwlgljfsyd.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0aWRmd3RqanBnd2xnbGpmc3lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNDA3OTIsImV4cCI6MjA5NDgxNjc5Mn0.ykA0xDpKNGDgL08pN5k4P3idDsA8fiXsLnXmar-y0Tw',
    authOptions: const FlutterAuthClientOptions(
      // O OAuth continua usando o callback nativo. Convites de funcionário
      // usam um link próprio e não passam pelo consumo automático de OTP.
      authFlowType: AuthFlowType.implicit,
    ),
  );

  await DispositivoServico.instance.inicializar();
  await MonitorConexaoServico.instance.inicializar();
  await ConviteFuncionarioLinkServico.instance.inicializar();

  runApp(const MeuAppCasamento());
}

class MeuAppCasamento extends StatefulWidget {
  const MeuAppCasamento({super.key});

  @override
  State<MeuAppCasamento> createState() => _MeuAppCasamentoState();
}

class _MeuAppCasamentoState extends State<MeuAppCasamento>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _mudancasAutenticacao;
  StreamSubscription<String>? _convitesFuncionario;
  bool _trocandoUsuario = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _convitesFuncionario = ConviteFuncionarioLinkServico.instance.novosConvites
        .listen((_) => _abrirPrimeiroAcessoPorConvite());
    _mudancasAutenticacao = Supabase.instance.client.auth.onAuthStateChange
        .listen((dados) {
          if (dados.event == AuthChangeEvent.signedIn ||
              dados.event == AuthChangeEvent.initialSession) {
            unawaited(_reconciliarUsuarioAutenticado());
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ConviteFuncionarioLinkServico.instance.possuiTokenPendente) {
        _abrirPrimeiroAcessoPorConvite();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_mudancasAutenticacao?.cancel());
    unawaited(_convitesFuncionario?.cancel());
    super.dispose();
  }

  void _abrirPrimeiroAcessoPorConvite() {
    if (!mounted) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const TelaPrimeiroAcessoFuncionario(),
      ),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconciliarUsuarioAutenticado());
      if (SessaoServico.instance.possuiUsuarioAtivoNoApp) {
        SincronizacaoAutomaticaServico.instance.sincronizarAgora();
      }
    }
  }

  Future<void> _reconciliarUsuarioAutenticado() async {
    if (_trocandoUsuario) return;

    final usuarioAutenticado = Supabase.instance.client.auth.currentUser;
    final usuarioLocal = SessaoServico.instance.usuarioAtual;
    if (usuarioAutenticado == null ||
        usuarioLocal == null ||
        usuarioAutenticado.id == usuarioLocal.id) {
      return;
    }

    _trocandoUsuario = true;
    try {
      await SessaoServico.instance.limparDadosLocaisAoTrocarUsuario();
      final navigator = _navigatorKey.currentState;
      if (navigator == null || !mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaPortaDeEntrada()),
        (_) => false,
      );
    } finally {
      _trocandoUsuario = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFE96851);
    const cream = Color(0xFFFFF8F2);
    const darkBrown = Color(0xFF3A2924);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.light,
    ).copyWith(
      primary: coral,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFD9CF),
      onPrimaryContainer: Color(0xFF3B1008),
      secondary: Color(0xFFE3A066),
      onSecondary: darkBrown,
      secondaryContainer: Color(0xFFFFE2C8),
      onSecondaryContainer: Color(0xFF3E2417),
      tertiary: Color(0xFFD97F78),
      surface: cream,
      onSurface: darkBrown,
      onSurfaceVariant: Color(0xFF6F5B53),
      outline: Color(0xFFAD8E82),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ConfirmaAi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cream,
          indicatorColor: colorScheme.primaryContainer,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final ativo = states.contains(WidgetState.selected);
            return TextStyle(
              color: ativo ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final ativo = states.contains(WidgetState.selected);
            return IconThemeData(
              color: ativo ? colorScheme.primary : colorScheme.onSurfaceVariant,
            );
          }),
        ),
        tabBarTheme: TabBarThemeData(
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        ),
      ),
      home: const TelaPortaDeEntrada(),
    );
  }
}
