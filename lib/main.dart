import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicos/dispositivo_servico.dart';
import 'servicos/monitor_conexao_servico.dart';
import 'servicos/sessao_servico.dart';
import 'telas/porta_entrada.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rtidfwtjjpgwlgljfsyd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0aWRmd3RqanBnd2xnbGpmc3lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNDA3OTIsImV4cCI6MjA5NDgxNjc5Mn0.ykA0xDpKNGDgL08pN5k4P3idDsA8fiXsLnXmar-y0Tw',
  );

  await SessaoServico.instance.inicializar();

  await DispositivoServico.instance.inicializar();

  await MonitorConexaoServico.instance.inicializar();

  runApp(const MeuAppCasamento());
}

class MeuAppCasamento extends StatelessWidget {
  const MeuAppCasamento({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Check-in Casamento',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TelaPortaDeEntrada(),
    );
  }
}
