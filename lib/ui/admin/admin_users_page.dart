import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/usuario_controller.dart';
import '../../controllers/solicitacao_controller.dart';
import '../../session/app_session.dart';
import '../../services/export_service.dart';
import '../../models/usuario.dart';
import 'user_form_page.dart';
import 'reset_password_page.dart';
import 'admin_solicitacoes_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _usuarioController = UsuarioController();
  final _solicitacaoController = SolicitacaoController();
  final _export = ExportService();
  List<Usuario> _items = [];
  bool _loading = true;
  int _pendentes = 0;

  static const String _dropboxRequest =
      'https://www.dropbox.com/request/DVjbvzFK1nLnJAPhOsgV';

  @override
  void initState() {
    super.initState();
    print('Entrou no initState do AdminUsersPage');
    _load();
  }

  Future<void> _load() async {
    print('Entrou no _load do AdminUsersPage');
    setState(() => _loading = true);
    final list = await _usuarioController.list();
    final p = await _solicitacaoController.countPendentes();
    if (!mounted) return;
    setState(() {
      _items = list;
      _pendentes = p;
      _loading = false;
    });
  }

  Future<void> _openForm({Usuario? edit}) async {
    print('Entrou no _openForm do AdminUsersPage, edit=${edit?.id}');
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UserFormPage(edit: edit)),
    );
    if (changed == true) await _load();
  }

  Future<void> _resetSenha(Usuario u) async {
    print('Entrou no _resetSenha do AdminUsersPage, usuarioId=${u.id}');
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResetPasswordPage(user: u)),
    );
    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
    }
  }

  Future<void> _exportarCsv() async {
    print('Entrou no _exportarCsv do AdminUsersPage');
    try {
      final file = await _export.exportUsuariosCsv(_items);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Base de Usuários (CSV).\nEnvie no link do Dropbox: $_dropboxRequest',
      );
      await launchUrl(Uri.parse(_dropboxRequest),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do AdminUsersPage');
    if (!AppSession.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Acesso negado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Usuários'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.upload_file),
            onPressed: _items.isEmpty ? null : _exportarCsv,
          ),
          IconButton(
            tooltip: 'Solicitações de CRIAs',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.inbox),
                if (_pendentes > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _pendentes > 99 ? '99+' : '$_pendentes',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSolicitacoesPage()),
              );
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = _items[i];
                return ListTile(
                  title: Text(u.nome),
                  subtitle: Text(
                      'login: ${u.login} • faixa: ${u.prefixo}${u.inicio}-${u.prefixo}${u.maximo}'),
                  leading: Icon(
                      u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'editar') _openForm(edit: u);
                      if (v == 'senha') _resetSenha(u);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'senha', child: Text('Resetar senha')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
