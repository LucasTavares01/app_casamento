import 'package:flutter/material.dart';
import '../servicos/supabase_servico.dart';
import '../modelos/modelos.dart';

class AbaEquipe extends StatefulWidget {
  const AbaEquipe({super.key});

  @override
  State<AbaEquipe> createState() => _AbaEquipeState();
}

class _AbaEquipeState extends State<AbaEquipe> {
  final _servico = SupabaseServico();
  final _mensagemController = TextEditingController();
  Staff? _eu;

  // 1. Criamos as variáveis para segurar a conexão em tempo real
  late final Stream<List<Staff>> _streamStaff;
  late final Stream<List<MensagemChat>> _streamChat;

  @override
  void initState() {
    super.initState();
    // 2. Iniciamos a conexão APENAS UMA VEZ quando a tela abre.
    // Isso impede que o Flutter desconecte o chat ao redesenhar a tela.
    _streamStaff = _servico.listarStaff();
    _streamChat = _servico.listarMensagens();
  }

  void _pedirSenhaAdmin() {
    final senhaCtrl = TextEditingController();
    const senhaAdmin = 'admin123';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acesso Restrito'),
        content: TextField(
          controller: senhaCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Senha de Administrador'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (senhaCtrl.text == senhaAdmin) {
                Navigator.pop(context);
                _dialogNovoStaff();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Senha Incorreta!')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Validar'),
          ),
        ],
      ),
    );
  }

  void _dialogNovoStaff() {
    final nomeCtrl = TextEditingController();
    final sobrenomeCtrl = TextEditingController();
    final ocupacaoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(hintText: 'Nome'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sobrenomeCtrl,
              decoration: const InputDecoration(hintText: 'Sobrenome'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ocupacaoCtrl,
              decoration: const InputDecoration(
                hintText: 'Ocupação (ex: Segurança)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomeCtrl.text.isNotEmpty) {
                _servico.adicionarStaff(
                  nomeCtrl.text,
                  sobrenomeCtrl.text,
                  ocupacaoCtrl.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _enviarMsg() {
    if (_mensagemController.text.trim().isNotEmpty && _eu != null) {
      _servico.enviarMensagem(_eu!.id, _mensagemController.text.trim());
      _mensagemController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_eu == null) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _pedirSenhaAdmin,
          icon: const Icon(Icons.person_add),
          label: const Text('Adicionar Staff'),
        ),
        // 3. Usamos a variável segura em vez de chamar a função
        body: StreamBuilder<List<Staff>>(
          stream: _streamStaff,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final staffs = snapshot.data!;
            if (staffs.isEmpty) {
              return const Center(child: Text('Nenhum staff cadastrado.'));
            }

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Quem é você?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: staffs.length,
                    itemBuilder: (context, index) {
                      final staff = staffs[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(staff.nome[0])),
                        title: Text('${staff.nome} ${staff.sobrenome}'),
                        subtitle: Text(staff.ocupacao),
                        onTap: () => setState(() => _eu = staff),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Usamos a variável segura do Staff para montar a tela
    return StreamBuilder<List<Staff>>(
      stream: _streamStaff,
      builder: (context, snapStaff) {
        // Usamos a variável segura do Chat para puxar as mensagens
        return StreamBuilder<List<MensagemChat>>(
          stream: _streamChat,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final mensagens = snapshot.data!;
            final staffs = snapStaff.data ?? [];

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.deepPurple.shade50,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _eu = null),
                      ),
                      Text(
                        'Logado como: ${_eu!.nome} (${_eu!.ocupacao})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: mensagens.length,
                    itemBuilder: (context, index) {
                      final msg = mensagens[index];
                      final souEu = msg.staffId == _eu!.id;
                      String nomeRemetente = 'Desconhecido';
                      for (var s in staffs) {
                        if (s.id == msg.staffId) {
                          nomeRemetente = '${s.nome} (${s.ocupacao})';
                          break;
                        }
                      }

                      return Align(
                        alignment: souEu
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: souEu
                                ? Colors.deepPurple.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: souEu
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!souEu)
                                Text(
                                  nomeRemetente,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                msg.mensagem,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mensagemController,
                          decoration: const InputDecoration(
                            hintText: 'Digite...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: _enviarMsg,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
