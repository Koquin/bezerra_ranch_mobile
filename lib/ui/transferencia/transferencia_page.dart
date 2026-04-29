import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/farm_options.dart';
import '../../controllers/animal_controller.dart';
import '../../controllers/transferencia_controller.dart';
import '../../models/nascimento.dart';
import '../../session/app_session.dart';
import '../../session/transferencia_selection_store.dart';

class TransferenciaPage extends StatefulWidget {
  const TransferenciaPage({super.key});

  @override
  State<TransferenciaPage> createState() => _TransferenciaPageState();
}

class _TransferenciaPageState extends State<TransferenciaPage> {
  final _transferenciaController = TransferenciaController();
  final _animalController = AnimalController();

  final _dataCtrl = TextEditingController();

  String? _fazendaOrigem;
  String? _fazendaDestino;
  String? _loteDestino;
  String? _pastoDestino;

  bool _saving = false;
  List<Nascimento> _animaisSelecionados = [];

  static const List<String> _lotesMock = ['Transferência', 'Geral'];
  static const List<String> _pastosMock = ['Transferência', 'Geral'];

  @override
  void initState() {
    super.initState();
    _dataCtrl.text = _formatDate(DateTime.now());
    _fazendaOrigem = AppSession.fazendaSelecionada;
    _fazendaDestino = AppSession.fazendaSelecionada;
    _loteDestino = _lotesMock.first;
    _pastoDestino = _pastosMock.first;
  }

  @override
  void dispose() {
    _dataCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirCalendario() async {
    final atual = _parseDate(_dataCtrl.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      _dataCtrl.text = _formatDate(selected);
    });
  }

  Future<void> _abrirSelecionarAnimais() async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _SelecionarAnimaisModalPage()),
    );
    if (confirmed != true) return;

    final ids = TransferenciaSelectionStore.instance.selectedAnimalIds.toList();
    final List<Nascimento> selecionados = [];
    for (final id in ids) {
      final animal = await _animalController.getById(id);
      if (animal != null && animal.status == Nascimento.statusAtivo) {
        selecionados.add(animal);
      }
    }

    if (!mounted) return;
    setState(() {
      _animaisSelecionados = selecionados;
    });
  }

  Future<bool> _confirmarCorrecaoInconsistencias({
    required List<Nascimento> inconsistentes,
    required String origemOriginal,
  }) async {
    if (inconsistentes.isEmpty) return true;

    final ids = inconsistentes.map((a) => a.cria).join(', ');
    final plural = inconsistentes.length > 1;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          plural ? 'Inconsistências detectadas' : 'Inconsistência detectada',
        ),
        content: Text(
          plural
              ? 'Os animais abaixo estão fora da fazenda de origem informada:\n$ids\n\nO sistema vai executar em 2 etapas:\n1) Transferir inconsistências uma a uma para "$origemOriginal" usando a origem real de cada animal.\n2) Após isso, transferir todos os animais para o destino original informado.\n\nDeseja continuar?'
              : 'O animal $ids está fora da fazenda de origem informada.\n\nO sistema vai executar em 2 etapas:\n1) Corrigir a inconsistência usando a origem real do animal e destino "$origemOriginal".\n2) Depois transferir normalmente para o destino original informado.\n\nDeseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    return confirmar == true;
  }

  Future<void> _confirmarTransferencia() async {
    if (_animaisSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos 1 animal.')),
      );
      return;
    }

    if (_fazendaOrigem == null || _fazendaDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe fazenda de origem e destino.')),
      );
      return;
    }

    if (_loteDestino == null || _pastoDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe lote e pasto de destino.')),
      );
      return;
    }

    final dataTransferencia = _parseDate(_dataCtrl.text);
    if (dataTransferencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data inválida. Use uma data válida.')),
      );
      return;
    }

    final fazendaOrigemOriginal = (_fazendaOrigem ?? '').trim().toUpperCase();
    final fazendaDestinoOriginal = (_fazendaDestino ?? '').trim().toUpperCase();
    final loteDestinoOriginal = (_loteDestino ?? '').trim().toUpperCase();
    final pastoDestinoOriginal = (_pastoDestino ?? '').trim().toUpperCase();

    final inconsistentes = _animaisSelecionados
        .where((a) => a.fazenda.trim().toUpperCase() != fazendaOrigemOriginal)
        .toList();

    final semMudanca = _animaisSelecionados.where((a) {
      final loteOrigem = (a.lote ?? '').trim().toUpperCase();
      final pastoOrigem = (a.pasto ?? '').trim().toUpperCase();
      return fazendaOrigemOriginal == fazendaDestinoOriginal &&
          loteOrigem == loteDestinoOriginal &&
          pastoOrigem == pastoDestinoOriginal;
    }).toList();

    if (semMudanca.isNotEmpty && inconsistentes.isEmpty) {
      final ids = semMudanca.map((a) => a.cria).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Origem e destino não podem ser iguais em tudo (fazenda, lote e pasto). Animal(is): $ids'),
        ),
      );
      return;
    }

    final confirmouInconsistencia = await _confirmarCorrecaoInconsistencias(
      inconsistentes: inconsistentes,
      origemOriginal: fazendaOrigemOriginal,
    );
    if (!confirmouInconsistencia) return;
    if (!mounted) return;

    final confirmarGeral = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar transferência'),
        content: Text(
            'Confirmar transferência de ${_animaisSelecionados.length} animal(is) para $fazendaDestinoOriginal, lote $loteDestinoOriginal e pasto $pastoDestinoOriginal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmarGeral != true) return;

    setState(() => _saving = true);
    try {
      for (final animal in inconsistentes) {
        final loteAtual = (animal.lote ?? '').trim().toUpperCase();
        final pastoAtual = (animal.pasto ?? '').trim().toUpperCase();

        await _transferenciaController.registrarTransferencias(
          animais: [animal],
          fazendaOrigem: animal.fazenda.trim().toUpperCase(),
          fazendaDestino: fazendaOrigemOriginal,
          loteDestino: loteAtual,
          pastoDestino: pastoAtual,
          isInconsistency: true,
          dataTransferencia: dataTransferencia,
          usuarioId: AppSession.usuarioId!,
        );
      }

      await _transferenciaController.registrarTransferencias(
        animais: _animaisSelecionados,
        fazendaOrigem: fazendaOrigemOriginal,
        fazendaDestino: fazendaDestinoOriginal,
        loteDestino: loteDestinoOriginal,
        pastoDestino: pastoDestinoOriginal,
        isInconsistency: false,
        dataTransferencia: dataTransferencia,
        usuarioId: AppSession.usuarioId!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inconsistentes.isEmpty
              ? 'Transferência confirmada de ${_animaisSelecionados.length} animal(is) para $fazendaDestinoOriginal, $loteDestinoOriginal, $pastoDestinoOriginal.'
              : 'Transferência concluída em 2 etapas. Inconsistências corrigidas: ${inconsistentes.length}. Transferência final aplicada para ${_animaisSelecionados.length} animal(is).'),
        ),
      );

      setState(() {
        _animaisSelecionados = [];
      });
      TransferenciaSelectionStore.instance.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao transferir: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _removerAnimalSelecionado(Nascimento animal) {
    setState(() {
      _animaisSelecionados.removeWhere((a) => a.id == animal.id);
    });

    final id = animal.id;
    if (id != null && TransferenciaSelectionStore.instance.isSelected(id)) {
      TransferenciaSelectionStore.instance.toggle(id);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  DateTime? _parseDate(String input) {
    final parts = input.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (year < 1900 || year > 9999) return null;
    if (month < 1 || month > 12) return null;

    int maxDay = 31;
    if (month == 2) {
      maxDay = 28;
    } else if ({4, 6, 9, 11}.contains(month)) {
      maxDay = 30;
    }

    if (day < 1 || day > maxDay) return null;

    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    final count = _animaisSelecionados.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Nova transferência')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Linha 1
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _dataCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _DateInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Data',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _abrirCalendario,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Animais selecionados',
                          ),
                          child: Text('$count animal(is)'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('pasto-destino-$_pastoDestino'),
                          initialValue: _pastoDestino,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          items: _pastosMock
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black))))
                              .toList(),
                          onChanged: (v) => setState(() => _pastoDestino = v),
                          decoration: const InputDecoration(
                            labelText: 'Pasto destino',
                            labelStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey('fazenda-origem-$_fazendaOrigem'),
                          initialValue: _fazendaOrigem,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          items: kFazendas
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black))))
                              .toList(),
                          onChanged: (v) => setState(() => _fazendaOrigem = v),
                          decoration: const InputDecoration(
                            labelText: 'Fazenda origem',
                            labelStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('fazenda-destino-$_fazendaDestino'),
                          initialValue: _fazendaDestino,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          items: kFazendas
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black))))
                              .toList(),
                          onChanged: (v) => setState(() => _fazendaDestino = v),
                          decoration: const InputDecoration(
                            labelText: 'Fazenda destino',
                            labelStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('lote-destino-$_loteDestino'),
                          initialValue: _loteDestino,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          items: _lotesMock
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black))))
                              .toList(),
                          onChanged: (v) => setState(() => _loteDestino = v),
                          decoration: const InputDecoration(
                            labelText: 'Lote destino',
                            labelStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha 2
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _animaisSelecionados.isEmpty
                      ? const Center(child: Text('Nenhum animal selecionado.'))
                      : Scrollbar(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Fazenda Origem')),
                                  DataColumn(label: Text('Fazenda Destino')),
                                  DataColumn(label: Text('Lote Origem')),
                                  DataColumn(label: Text('Lote Destino')),
                                  DataColumn(label: Text('Pasto Origem')),
                                  DataColumn(label: Text('Pasto Destino')),
                                  DataColumn(label: Text('')),
                                ],
                                rows: _animaisSelecionados
                                    .map(
                                      (a) => DataRow(
                                        cells: [
                                          DataCell(Text(a.cria)),
                                          DataCell(Text(a.fazenda,
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                          DataCell(Text(_fazendaDestino ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                          DataCell(Text(a.lote ?? '-')),
                                          DataCell(Text(_loteDestino ?? '-')),
                                          DataCell(Text(a.pasto ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                          DataCell(Text(_pastoDestino ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.black))),
                                          DataCell(
                                            IconButton(
                                              tooltip: 'Remover animal',
                                              icon: const Icon(Icons.close,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _removerAnimalSelecionado(a),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Linha 3
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _abrirSelecionarAnimais,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Selecionar animais'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _confirmarTransferencia,
                      child: Text(_saving ? 'Salvando...' : 'Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelecionarAnimaisModalPage extends StatefulWidget {
  const _SelecionarAnimaisModalPage();

  @override
  State<_SelecionarAnimaisModalPage> createState() =>
      _SelecionarAnimaisModalPageState();
}

class _SelecionarAnimaisModalPageState
    extends State<_SelecionarAnimaisModalPage> {
  final _animalController = AnimalController();
  final _search = TextEditingController();

  List<Nascimento> _items = [];
  bool _loading = true;

  Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedIds = TransferenciaSelectionStore.instance.selectedAnimalIds;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    final list = await _animalController.listVivos(q: q);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _limparSelecao() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _confirmarSelecao() {
    TransferenciaSelectionStore.instance.replaceAll(_selectedIds);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar animais vivos')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => _load(q: v),
                decoration: InputDecoration(
                  labelText: 'Pesquisar Animal',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _load(q: _search.text),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text('Nenhum animal vivo encontrado.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            final selected =
                                n.id != null && _selectedIds.contains(n.id!);
                            return ListTile(
                              leading: const Icon(
                                Icons.eco,
                                color: Colors.green,
                              ),
                              title: Text(n.cria,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  'Fazenda: ${n.fazenda} • Lote: ${n.lote ?? '-'} • Pasto: ${n.pasto ?? '-'}'),
                              trailing: selected
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.circle_outlined),
                              onTap: () {
                                if (n.id != null) {
                                  _toggle(n.id!);
                                }
                              },
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _limparSelecao,
                      child: const Text('Limpar seleção'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmarSelecao,
                      child: const Text('Confirmar seleção'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
