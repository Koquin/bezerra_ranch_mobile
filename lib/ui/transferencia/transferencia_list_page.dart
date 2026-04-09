import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_runtime_config.dart';
import '../../controllers/transferencia_controller.dart';
import '../../services/export_service.dart';
import 'transferencia_page.dart';

class TransferenciaListPage extends StatefulWidget {
  const TransferenciaListPage({super.key});

  @override
  State<TransferenciaListPage> createState() => _TransferenciaListPageState();
}

class _TransferenciaListPageState extends State<TransferenciaListPage> {
  final _controller = TransferenciaController();
  final _export = ExportService();
  final _search = TextEditingController();

  List<Map<String, Object?>> _items = [];
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
    final list = await _controller.listarTransferencias(q: q);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _abrirCriacao() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransferenciaPage()),
    );
    await _load(q: _search.text);
  }

  Future<void> _exportarCsv() async {
    try {
      final file = await _export.exportTransferenciasCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Base de Transferências (CSV). Envie no link do Dropbox: ${AppRuntimeConfig.dropboxRequestUrl}',
      );
      await launchUrl(Uri.parse(AppRuntimeConfig.dropboxRequestUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
    }
  }

  bool _isInconsistency(Map<String, Object?> row) {
    final value = row['is_inconsistency'];
    if (value is int) return value == 1;
    return value?.toString() == '1';
  }

  String _fmtData(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    final raw = iso.trim();
    if (raw.contains('/')) return raw;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final qtdInconsistencias = _items.where(_isInconsistency).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferências'),
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
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  'Total de transferências: ${_items.length}\nInconsistências: $qtdInconsistencias',
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
                      ? const Center(
                          child: Text('Nenhuma transferência encontrada.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final t = _items[i];
                            final cria = (t['animal_cria']?.toString() ??
                                    t['animal_id']?.toString() ??
                                    '-')
                                .trim();
                            final fazendaOrigem =
                                (t['fazenda_origem']?.toString() ?? '-').trim();
                            final fazendaDestino =
                                (t['fazenda_destino']?.toString() ?? '-')
                                    .trim();
                            final loteDestino =
                                (t['lote_destino']?.toString() ?? '-').trim();
                            final pastoDestino =
                                (t['pasto_destino']?.toString() ?? '-').trim();
                            final data =
                                _fmtData(t['data_transferencia']?.toString());
                            final isInconsistency = _isInconsistency(t);

                            return ListTile(
                              leading: const Icon(Icons.compare_arrows),
                              title: Text(
                                'Animal: $cria',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                'Origem: $fazendaOrigem\nDestino: $fazendaDestino • Lote: $loteDestino • Pasto: $pastoDestino\nData: $data\nInconsistência: ${isInconsistency ? 'Sim' : 'Não'}',
                              ),
                              trailing: isInconsistency
                                  ? const Tooltip(
                                      message:
                                          'Transferência com inconsistência',
                                      child: Icon(Icons.warning_amber_rounded,
                                          color: Colors.orange),
                                    )
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova transferência',
        onPressed: _abrirCriacao,
        child: const Icon(Icons.add),
      ),
    );
  }
}
