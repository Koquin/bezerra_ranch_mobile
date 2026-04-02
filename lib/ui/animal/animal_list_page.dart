import 'package:flutter/material.dart';

import '../../controllers/animal_controller.dart';
import '../../models/nascimento.dart';

class AnimalListPage extends StatefulWidget {
  const AnimalListPage({super.key});

  @override
  State<AnimalListPage> createState() => _AnimalListPageState();
}

class _AnimalListPageState extends State<AnimalListPage> {
  final _animalController = AnimalController();
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

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do AnimalListPage');
    final totalMortos =
        _items.where((n) => n.status == Nascimento.statusMorto).length;
    final totalVendidos =
        _items.where((n) => n.status == Nascimento.statusVendido).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Animais')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
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
                  'Total: ${_items.length}  |  Mortos: $totalMortos  |  Vendidos: $totalVendidos',
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
                            final bool isVendido =
                                n.status == Nascimento.statusVendido;
                            return ListTile(
                              leading: isMorto
                                  ? const Icon(
                                      Icons.sentiment_very_dissatisfied,
                                      color: Colors.red,
                                      size: 28,
                                    )
                                  : isVendido
                                      ? const Icon(
                                          Icons.attach_money,
                                          color: Colors.green,
                                          size: 28,
                                        )
                                      : const Icon(Icons.pets),
                              title: Text(
                                n.cria,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                'Mãe: ${n.mae} • ${n.sexo} • ${n.fazenda} • ${n.status}',
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
