import 'banco_local.dart';

/// Única instância do banco SQLite utilizada por todo o aplicativo.
///
/// Manter uma única instância evita abrir várias conexões diferentes
/// para o mesmo arquivo de banco no celular.
final BancoLocal bancoLocal = BancoLocal();
