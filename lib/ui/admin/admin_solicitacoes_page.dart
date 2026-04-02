import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/solicitacao_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../controllers/usuario_controller.dart';
import '../../session/app_session.dart';
import '../../services/solicitacao_export_service.dart';
import '../../models/solicitacao.dart';
import 'user_form_page.dart';

class AdminSolicitacoesPage extends StatefulWidget {
  const AdminSolicitacoesPage({super.key});

  @override
  State<AdminSolicitacoesPage> createState() => _AdminSolicitacoesPageState();
}

class _AdminSolicitacoesPageState extends State<AdminSolicitacoesPage> {
  final _solicitacaoController = SolicitacaoController();
  final _usuarioController = UsuarioController();
  final _syncController = SyncController();
  final _export = SolicitacaoExportService();
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  List<Solicitacao> _items = [];
  bool _loading = true;
  String _filtro = 'TODAS'; // PENDENTE | ATENDIDA | TODAS

  @override
  void initState() {
    super.initState();
    print('Entrou no initState do AdminSolicitacoesPage');
    _sincronizarECarregar();
  }

  Future<void> _sincronizarECarregar() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('🔄 Baixando solicitações...'),
              backgroundColor: Colors.blueGrey,
            ),
          );
      }
      final temConexao = await _syncController.verificarConexao();
      if (temConexao) {
        await _syncController.baixarSolicitacoes();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('✅ Solicitações sincronizadas'),
                backgroundColor: Colors.green,
              ),
            );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('⚠️ Sem conexão com internet'),
                backgroundColor: Colors.orange,
              ),
            );
        }
      }
    } catch (e) {
      // Falha ao baixar não deve bloquear o carregamento local
      print('❌ Erro ao baixar solicitações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('❌ Erro ao baixar solicitações: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
    await _load();
  }

  Future<void> _load() async {
    print('Entrou no _load do AdminSolicitacoesPage, filtro=$_filtro');
    setState(() => _loading = true);
    final list = await _solicitacaoController.listByStatus(_filtro);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _marcarAtendida(Solicitacao s) async {
    print(
        'Entrou no _marcarAtendida do AdminSolicitacoesPage, solicitacaoId=${s.id}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marcar como atendida'),
        content: Text(
          'Usuário: ${s.usuarioNome}\n'
          'Faixa atual: ${s.prefixo}${s.inicioAtual}–${s.prefixo}${s.maxAtual}\n'
          'Restavam: ${s.restantes}\n\n'
          'Confirma que a solicitação já foi atendida?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );

    if (ok == true) {
      await _solicitacaoController.marcarAtendida(s.id);
      await _load();
    }
  }

  Future<void> _atenderEEditarUsuario(Solicitacao s) async {
    print(
        'Entrou no _atenderEEditarUsuario do AdminSolicitacoesPage, solicitacaoId=${s.id}');
    final u = await _usuarioController.getById(s.usuarioId);
    if (u == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Usuário não encontrado (talvez tenha sido removido).')),
      );
      return;
    }

    final changedUser = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UserFormPage(edit: u)),
    );

    await _load();
    if (!mounted) return;

    if (changedUser == true && s.status == 'PENDENTE') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Marcar solicitação como atendida?'),
          content: Text(
            'Usuário: ${s.usuarioNome}\n'
            'Solicitação #${s.id}\n\n'
            'Você acabou de editar a faixa do usuário.\n'
            'Deseja marcar esta solicitação como ATENDIDA?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Não')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sim')),
          ],
        ),
      );

      if (ok == true) {
        await _solicitacaoController.marcarAtendida(s.id);
        await _load();
      }
    }
  }

  Future<void> _exportar() async {
    print('Entrou no _exportar do AdminSolicitacoesPage, filtro=$_filtro');
    try {
      final file = await _export.exportarCsv(status: _filtro);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Solicitações de CRIAs ($_filtro)');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitações')),
        body: const Center(child: Text('Acesso negado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitações de CRIAs'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.upload_file),
            onPressed: _exportar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'PENDENTE',
                          label: Text('Pendentes'),
                          icon: Icon(Icons.inbox)),
                      ButtonSegment(
                          value: 'ATENDIDA',
                          label: Text('Atendidas'),
                          icon: Icon(Icons.check_circle)),
                      ButtonSegment(
                          value: 'TODAS',
                          label: Text('Todas'),
                          icon: Icon(Icons.list)),
                    ],
                    selected: {_filtro},
                    onSelectionChanged: (s) async {
                      setState(() => _filtro = s.first);
                      await _load();
                    },
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('Nenhuma solicitação neste filtro.'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final s = _items[i];
                            final pendente = s.status == 'PENDENTE';
                            final prioridade = s.restantes <= 10;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: prioridade
                                    ? Colors.red.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      prioridade ? Colors.red : Colors.black12,
                                  width: prioridade ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Topo com ícone e faixa
                                  Row(
                                    children: [
                                      if (prioridade)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(
                                            Icons.inbox_outlined,
                                            size: 24,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          'Faixa: ${s.prefixo}${s.inicioAtual}–${s.prefixo}${s.maxAtual}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Informações detalhadas
                                  Text(
                                    'Usuário: ${s.usuarioNome}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Restam: ${s.restantes}  •  ${_fmt.format(s.solicitadoEm)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: prioridade
                                          ? Colors.red.shade700
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Botões embaixo
                                  if (pendente)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        SizedBox(
                                          width: 140,
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                _atenderEEditarUsuario(s),
                                            child: const Text('Atender'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 140,
                                          child: FilledButton(
                                            onPressed: () => _marcarAtendida(s),
                                            child: const Text('Atendida'),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    const Center(
                                      child: Chip(
                                        label: Text('ATENDIDA'),
                                        backgroundColor: Colors.green,
                                        labelStyle:
                                            TextStyle(color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
