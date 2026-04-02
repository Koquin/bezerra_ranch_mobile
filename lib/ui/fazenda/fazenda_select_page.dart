import 'package:flutter/material.dart';

import '../../config/farm_options.dart';
import '../../session/app_session.dart';
import '../home_rotinas_page.dart';

class FazendaSelectPage extends StatefulWidget {
  final bool voltarAposSelecionar;

  const FazendaSelectPage({
    super.key,
    this.voltarAposSelecionar = false,
  });

  @override
  State<FazendaSelectPage> createState() => _FazendaSelectPageState();
}

class _FazendaSelectPageState extends State<FazendaSelectPage> {
  static const double _itemHeight = 56;
  static const double _listPadding = 0;

  Future<void> _selecionarFazenda(String fazenda) async {
    AppSession.fazendaSelecionada = fazenda;

    if (!mounted) return;

    if (widget.voltarAposSelecionar) {
      Navigator.pop(context, true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeRotinasPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight = (_itemHeight * 7.5) + (_listPadding * 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Fazenda'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'Em que fazenda voce está?',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 100),
                  Container(
                    height: maxListHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Stack(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          itemExtent: _itemHeight,
                          itemCount: kFazendas.length,
                          itemBuilder: (_, i) {
                            final fazenda = kFazendas[i];
                            final selecionada =
                                AppSession.fazendaSelecionada == fazenda;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              tileColor:
                                  selecionada ? Colors.green.shade50 : null,
                              leading: Icon(
                                selecionada
                                    ? Icons.check_circle
                                    : Icons.agriculture,
                                color: selecionada ? Colors.green : null,
                              ),
                              title: Text(fazenda),
                              onTap: () => _selecionarFazenda(fazenda),
                            );
                          },
                        ),
                        Positioned(
                          right: 10,
                          bottom: 8,
                          child: Icon(
                            Icons.keyboard_double_arrow_down,
                            size: 20,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
