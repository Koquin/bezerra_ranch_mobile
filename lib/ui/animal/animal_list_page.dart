import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_runtime_config.dart';
import '../../controllers/animal_controller.dart';
import '../../models/nascimento.dart';
import '../../session/app_session.dart';
import '../../services/export_service.dart';

class AnimalListPage extends StatefulWidget {
  const AnimalListPage({super.key});

  @override
  State<AnimalListPage> createState() => _AnimalListPageState();
}

class _AnimalListPageState extends State<AnimalListPage> {
  final _animalController = AnimalController();
  final _export = ExportService();
  final _search = TextEditingController();

  List<Nascimento> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print('Entrou no initState do AnimalListPage');
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    print('Entrou no _load do AnimalListPage, q=$q');
    setState(() => _loading = true);
    final list = await _animalController.list(q: q);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
    print('AnimalListPage._load finalizado com ${_items.length} registros.');
  }

  Future<void> _exportarCsv() async {
    try {
      final file = await _export.exportAnimaisCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Base de Animais (CSV). Envie no link do Dropbox: ${AppRuntimeConfig.dropboxRequestUrl}',
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
      final result = await _export.importAnimaisCsv(
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

  Widget _buildAnimalLeadingIcon({
    required bool isMorto,
    required bool isAbatido,
    required bool isVendido,
  }) {
    if (isMorto) {
      return const Icon(
        Icons.sentiment_very_dissatisfied,
        color: Colors.red,
        size: 30,
      );
    }
    if (isAbatido) {
      return const Icon(Icons.track_changes,
          color: Colors.deepOrange, size: 30);
    }
    if (isVendido) {
      return const Icon(Icons.attach_money, color: Colors.green, size: 30);
    }
    return const Icon(Icons.eco, color: Colors.green, size: 30);
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do AnimalListPage');
    final totalAtivos =
        _items.where((n) => n.status == Nascimento.statusAtivo).length;
    final totalMortos =
        _items.where((n) => n.status == Nascimento.statusMorto).length;
    final totalAbatidos =
        _items.where((n) => n.status == Nascimento.statusAbatido).length;
    final totalVendidos =
        _items.where((n) => n.status == Nascimento.statusVendido).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animais'),
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (value) => _load(q: value),
                decoration: InputDecoration(
                  labelText: 'Pesquisar por CRIA',
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
                  'Total: ${_items.length}  |  Ativos: $totalAtivos  |  Mortos: $totalMortos  |  Abatidos: $totalAbatidos  |  Vendidos: $totalVendidos',
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
                            final n = _items[i];
                            final bool isMorto =
                                n.status == Nascimento.statusMorto;
                            final bool isAbatido =
                                n.status == Nascimento.statusAbatido;
                            final bool isVendido =
                                n.status == Nascimento.statusVendido;
                            return ListTile(
                              leading: _buildAnimalLeadingIcon(
                                isMorto: isMorto,
                                isAbatido: isAbatido,
                                isVendido: isVendido,
                              ),
                              title: Text(
                                n.cria,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                'Mãe: ${n.mae} • ${n.sexo}\nFazenda: ${n.fazenda} • Lote: ${n.lote ?? '-'} • Pasto: ${n.pasto ?? '-'}\nStatus: ${n.status}',
                              ),
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
