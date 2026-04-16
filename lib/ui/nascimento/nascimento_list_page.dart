import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_runtime_config.dart';
import '../../controllers/nascimento_controller.dart';
import '../../controllers/solicitacao_controller.dart';
import '../../session/app_session.dart';
import '../../services/export_service.dart';
import '../../models/nascimento.dart';
import 'nascimento_form_page.dart';

class NascimentoListPage extends StatefulWidget {
  const NascimentoListPage({super.key});

  @override
  State<NascimentoListPage> createState() => _NascimentoListPageState();
}

class _NascimentoListPageState extends State<NascimentoListPage> {
  final _controller = NascimentoController();
  final _export = ExportService();
  final _solicitacaoController = SolicitacaoController();

  final _search = TextEditingController();
  List<Nascimento> _items = [];
  bool _loading = true;
  int _restantes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    print(
        '[NascimentoListPage._load] q=$q isAdmin=${AppSession.isAdmin} fazenda=${AppSession.fazendaSelecionada}');
    setState(() => _loading = true);
    final fazenda = AppSession.fazendaSelecionada;
    if (fazenda == null || fazenda.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Selecione uma fazenda para continuar.')),
        );
      }
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    final list = await _controller.listPorFaixa(
      prefixo: AppSession.criaPrefixo!,
      inicio: AppSession.criaInicio!,
      maximo: AppSession.criaMax!,
      fazenda: fazenda,
      usuarioId: AppSession.usuarioId,
      q: q,
    );
    print('[NascimentoListPage._load] total=${list.length}');
    await _loadRestantes();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _loadRestantes() async {
    print('[NascimentoListPage._loadRestantes]');
    final r = await _controller.calcularRestantes(
      usuarioId: AppSession.usuarioId!,
      prefixo: AppSession.criaPrefixo!,
      inicio: AppSession.criaInicio!,
      maximo: AppSession.criaMax!,
    );
    if (!mounted) return;
    setState(() => _restantes = r);
  }

  Future<void> _novo() async {
    print('[NascimentoListPage._novo]');
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NascimentoFormPage()),
    );
    if (ok == true) await _load(q: _search.text);
  }

  Future<void> _exportarCsv() async {
    print('[NascimentoListPage._exportarCsv] itens=${_items.length}');
    try {
      final file = await _export.exportNascimentosCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Base de Nascimentos (CSV).\nEnvie no link do Dropbox: ${AppRuntimeConfig.dropboxRequestUrl}',
      );
      await launchUrl(Uri.parse(AppRuntimeConfig.dropboxRequestUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
    }
  }

  Future<void> _importarCsv() async {
    final usuarioId = AppSession.usuarioId;
    if (usuarioId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não identificado na sessão.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Importando CSV...')),
          ],
        ),
      ),
    );

    try {
      final result = await _export.importNascimentosCsv(
        usuarioId: usuarioId,
        fazendaFallback: AppSession.fazendaSelecionada,
      );
      if (result.cancelled) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Importação cancelada.')),
        );
        return;
      }

      await _load(q: _search.text);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Importação concluída. Importados: ${result.imported}. Ignorados: ${result.skipped}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Falha ao importar: $e')));
    }
  }

  Future<void> _editarNascimento(Nascimento n) async {
    print('[NascimentoListPage._editarNascimento] id=${n.id} cria=${n.cria}');
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NascimentoFormPage(
          nascimento: n,
          readOnly: false,
        ),
      ),
    );
    if (ok == true) await _load(q: _search.text);
  }

  Future<void> _deletarNascimento(Nascimento n) async {
    if (!AppSession.isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas administradores podem deletar animais.'),
        ),
      );
      return;
    }

    print('[NascimentoListPage._deletarNascimento] id=${n.id} cria=${n.cria}');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar deleção'),
        content: Text('Deletar o CRIA ${n.cria}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await _controller.delete(n.id!);
        await _load(q: _search.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CRIA ${n.cria} deletado com sucesso')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e')),
        );
      }
    }
  }

  Future<void> _solicitarMais() async {
    final usuarioId = AppSession.usuarioId!;
    final usuarioNome = AppSession.usuarioNome ?? 'Usuário';
    final prefixo = AppSession.criaPrefixo!;
    final inicio = AppSession.criaInicio!;
    final maximo = AppSession.criaMax!;
    try {
      await _solicitacaoController.criar(
        usuarioId: usuarioId,
        usuarioNome: usuarioNome,
        prefixo: prefixo,
        inicioAtual: inicio,
        maxAtual: maximo,
        restantes: _restantes,
      );

      final msg = 'Solicitação de liberação de CRIAs.\n'
          'Usuário: $usuarioNome (login: ${AppSession.usuarioLogin ?? "-"})\n'
          'Faixa atual: ${prefixo}${inicio} até ${prefixo}${maximo}\n'
          'Restam: $_restantes\n'
          'Solicito ampliação do limite.';

      final uri = Uri.parse(
          'https://wa.me/${AppRuntimeConfig.adminWhatsAppE164}?text=${Uri.encodeComponent(msg)}');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Solicitação registrada. Abra o WhatsApp e envie a mensagem.'
                : 'Solicitação registrada no celular. Quando estiver online, tente novamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao solicitar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final faixa =
        '${AppSession.criaPrefixo}${AppSession.criaInicio}–${AppSession.criaPrefixo}${AppSession.criaMax}';
    final critico = _restantes <= 20;
    print('[NascimentoListPage.build] isAdmin=${AppSession.isAdmin}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nascimento'),
        actions: [
          if (AppSession.isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Opções CSV',
              icon: const Icon(Icons.file_download_outlined),
              onSelected: (value) async {
                if (value == 'exportar') {
                  if (_items.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Nenhum dado para exportar.')),
                    );
                    return;
                  }
                  await _exportarCsv();
                  return;
                }
                if (value == 'importar') {
                  await _importarCsv();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'exportar',
                  child: Text('Exportar CSV'),
                ),
                PopupMenuItem(
                  value: 'importar',
                  child: Text('Importar CSV'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novo,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (value) => _load(q: value),
                decoration: InputDecoration(
                  labelText: 'Pesquisar Animal',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _load(q: _search.text),
                  ),
                ),
                onSubmitted: (_) => _load(q: _search.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: critico ? Colors.red : Colors.black12),
                      ),
                      child: Text(
                        'Faixa: $faixa  |  Restam: $_restantes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: critico ? Colors.red.shade700 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _solicitarMais,
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Solicitar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Nenhum registro.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            final dataStr =
                                '${n.criadoEm.day.toString().padLeft(2, '0')}/'
                                '${n.criadoEm.month.toString().padLeft(2, '0')}/'
                                '${n.criadoEm.year}';
                            return ListTile(
                              title: Text(n.cria,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              subtitle: Text(
                                  'Mãe: ${n.mae} • ${n.sexo} • ${n.fazenda} • $dataStr'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'editar') {
                                    _editarNascimento(n);
                                  } else if (value == 'deletar') {
                                    _deletarNascimento(n);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar'),
                                  ),
                                  if (AppSession.isAdmin)
                                    const PopupMenuItem(
                                      value: 'deletar',
                                      child: Text(
                                        'Deletar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                print(
                                    '[NascimentoListPage.onTap] id=${n.id} cria=${n.cria} readOnly=true');
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NascimentoFormPage(
                                      nascimento: n,
                                      readOnly: true,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
