import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_runtime_config.dart';
import '../../controllers/animal_controller.dart';
import '../../controllers/morte_controller.dart';
import '../../models/morte.dart';
import '../../services/export_service.dart';

import '../../models/nascimento.dart';

import 'morte_form_page.dart';

class MorteListPage extends StatefulWidget {
  const MorteListPage({super.key});

  @override
  State<MorteListPage> createState() => _MorteListPageState();
}

class _MorteListPageState extends State<MorteListPage> {
  final _export = ExportService();
  final _morteController = MorteController();

  Future<void> _exportarCsv() async {
    try {
      final file = await _export.exportMortesCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Base de Baixas (CSV). Envie no link do Dropbox: ${AppRuntimeConfig.dropboxRequestUrl}',
      );
      await launchUrl(Uri.parse(AppRuntimeConfig.dropboxRequestUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
    }
  }

  final _animalController = AnimalController();
  final _search = TextEditingController();
  List<_BaixaListItem> _items = [];
  bool _loading = true;

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

  Future<void> _editarMorte(_BaixaListItem item) async {
    final animal = item.animal;
    if (animal == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Animal desta baixa não foi encontrado para edição.')),
      );
      return;
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MorteFormPage(
          nascimento: animal,
          readOnly: false,
        ),
      ),
    );
    if (ok == true) await _load(q: _search.text);
  }

  Future<void> _deletarMorte(_BaixaListItem item) async {
    final morte = item.baixa;
    final animal = item.animal;
    final animalLabel = animal?.cria ?? 'ID ${morte.nascimentoId}';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar deleção'),
        content: Text('Deletar registro de baixa do animal $animalLabel?'),
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
        await _morteController.deletarPorNascimento(
          nascimentoId: morte.nascimentoId,
          morteId: morte.id!,
        );
        await _load(q: _search.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Baixa de $animalLabel deletada com sucesso')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e')),
        );
      }
    }
  }

  Future<void> _load({String? q}) async {
    print('Entrou no _load do MorteListPage, q=$q');
    setState(() => _loading = true);

    final baixas = await _morteController.list();
    final animais = await _animalController.list();
    final animalById = <int, Nascimento>{
      for (final a in animais)
        if (a.id != null) a.id!: a,
    };

    var itens = baixas
        .map(
            (b) => _BaixaListItem(baixa: b, animal: animalById[b.nascimentoId]))
        .toList();

    final term = q?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      itens = itens.where((item) {
        final animal = item.animal;
        final tipo = item.baixa.tipoBaixa.toLowerCase();
        final causa = (item.baixa.descricao ?? '').toLowerCase();
        final fazenda = item.baixa.fazenda.toLowerCase();
        final cria = (animal?.cria ?? '').toLowerCase();
        final mae = (animal?.mae ?? '').toLowerCase();
        return tipo.contains(term) ||
            causa.contains(term) ||
            fazenda.contains(term) ||
            cria.contains(term) ||
            mae.contains(term);
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _items = itens;
      _loading = false;
    });
  }

  Future<void> _abrirSeletorAnimais() async {
    final selecionado = await Navigator.push<Nascimento>(
      context,
      MaterialPageRoute(builder: (_) => const _SelecionarAnimalPage()),
    );
    if (!mounted || selecionado == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MorteFormPage(nascimento: selecionado),
      ),
    );
    if (result == true) {
      await _load(q: _search.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do MorteListPage');
    final totalAbatidos =
        _items.where((item) => item.baixa.tipoBaixa == Morte.tipoAbate).length;
    final totalMortes = _items.length - totalAbatidos;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baixas'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções CSV',
            icon: const Icon(Icons.file_download_outlined),
            onSelected: (value) async {
              if (value == 'exportar') {
                if (_items.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nenhum dado para exportar.')),
                  );
                  return;
                }
                await _exportarCsv();
                return;
              }

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Importação CSV será habilitada em seguida.')),
              );
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (value) => _load(q: value),
                decoration: InputDecoration(
                  labelText: 'Pesquisar',
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
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  'Total de animais baixados: ${_items.length}  |  Mortes: $totalMortes  |  Abates: $totalAbatidos',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
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
                            final item = _items[i];
                            final baixa = item.baixa;
                            final n = item.animal;
                            final isAbatido =
                                baixa.tipoBaixa == Morte.tipoAbate;
                            final dataStr =
                                '${baixa.criadoEm.day.toString().padLeft(2, '0')}/'
                                '${baixa.criadoEm.month.toString().padLeft(2, '0')}/'
                                '${baixa.criadoEm.year}';
                            final cria = n?.cria ?? 'ID ${baixa.nascimentoId}';
                            final mae = n?.mae ?? '-';
                            final sexo = n?.sexo ?? '-';
                            final causa = (baixa.descricao == null ||
                                    baixa.descricao!.trim().isEmpty)
                                ? '-'
                                : baixa.descricao!.trim();
                            return ListTile(
                              leading: isAbatido
                                  ? const Icon(Icons.track_changes,
                                      color: Colors.deepOrange, size: 32)
                                  : const Icon(
                                      Icons.sentiment_very_dissatisfied,
                                      color: Colors.red,
                                      size: 32),
                              title: Text(cria,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              subtitle: Text(
                                  'Mãe: $mae • $sexo • ${baixa.fazenda} • $dataStr\nCausa: $causa'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'editar') {
                                    _editarMorte(item);
                                  } else if (value == 'deletar') {
                                    _deletarMorte(item);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'deletar',
                                    child: Text(
                                      'Deletar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ), // end PopupMenuButton
                              onTap: () async {
                                if (n == null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Animal desta baixa não foi encontrado para abrir o formulário.')),
                                  );
                                  return;
                                }
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MorteFormPage(
                                      nascimento: n,
                                      readOnly: false,
                                    ),
                                  ),
                                );
                                if (result == true) _load(q: _search.text);
                              },
                            ); // end ListTile
                          },
                        ), // end ListView.separated
            ), // end Expanded
          ], // end Padding (Total de CRIAs)
        ), // end Column
      ), // end SafeArea
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar baixa',
        onPressed: _abrirSeletorAnimais,
        child: const Icon(Icons.add),
      ),
    ); // end Scaffold
  }
}

class _BaixaListItem {
  final Morte baixa;
  final Nascimento? animal;

  const _BaixaListItem({required this.baixa, required this.animal});
}

class _SelecionarAnimalPage extends StatefulWidget {
  const _SelecionarAnimalPage();

  @override
  State<_SelecionarAnimalPage> createState() => _SelecionarAnimalPageState();
}

class _SelecionarAnimalPageState extends State<_SelecionarAnimalPage> {
  final _animalController = AnimalController();
  final _search = TextEditingController();
  List<Nascimento> _items = [];
  bool _loading = true;

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
    setState(() => _loading = true);
    final list = await _animalController.list(q: q);
    if (!mounted) return;
    setState(() {
      _items = list.where((n) => n.status == Nascimento.statusAtivo).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar animal')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (value) => _load(q: value),
                decoration: InputDecoration(
                  labelText: 'Pesquisar',
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
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  'Animais disponíveis: ${_items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Nenhum animal disponível.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            return ListTile(
                              leading: const Icon(Icons.pets),
                              title: Text(n.cria,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              subtitle: Text(
                                  'Mãe: ${n.mae} • ${n.sexo} • ${n.fazenda}'),
                              onTap: () => Navigator.pop(context, n),
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
