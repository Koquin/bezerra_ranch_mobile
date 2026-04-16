import 'package:flutter/material.dart';
import '../controllers/sync_controller.dart';
import '../session/app_session.dart';
import '../services/token_service.dart';
import 'fazenda/fazenda_select_page.dart';
import 'auth/login_page.dart';
import 'animal/animal_list_page.dart';
import 'nascimento/nascimento_list_page.dart';
import 'morte/morte_list_page.dart';
import 'transferencia/transferencia_list_page.dart';
import 'admin/admin_users_page.dart';

class HomeRotinasPage extends StatefulWidget {
  const HomeRotinasPage({super.key});

  @override
  State<HomeRotinasPage> createState() => _HomeRotinasPageState();
}

class _HomeRotinasPageState extends State<HomeRotinasPage> {
  final _syncController = SyncController();
  bool _sincronizando = false;

  Future<void> _garantirFazendaSelecionada() async {
    if (AppSession.fazendaSelecionada != null &&
        AppSession.fazendaSelecionada!.trim().isNotEmpty) {
      return;
    }
    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const FazendaSelectPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _garantirFazendaSelecionada();
    });
    // Sincronizar automaticamente ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizarAutomatico();
    });
  }

  Future<void> _sincronizarAutomatico() async {
    try {
      final temConexao = await _syncController.verificarConexao();
      if (temConexao) {
        final precisaSincronizar =
            await _syncController.deveSincronizarAutomatico();
        if (!precisaSincronizar) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('✅ Dados já atualizados.'),
                  backgroundColor: Colors.green,
                ),
              );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('🔄 Sincronizando...'),
                backgroundColor: Colors.blueGrey,
              ),
            );
        }

        await _syncController.sincronizar();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('✅ Sincronização concluída!'),
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
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('❌ Erro na sincronização: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _sincronizarManual() async {
    setState(() => _sincronizando = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('🔄 Sincronizando...'),
              backgroundColor: Colors.blueGrey,
            ),
          );
      }
      final temConexao = await _syncController.verificarConexao();
      if (!temConexao) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sem conexão com internet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _syncController.sincronizar();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sincronização concluída!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro na sincronização: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _sincronizarModulo({
    required String nomeModulo,
    required Future<void> Function() acao,
  }) async {
    setState(() => _sincronizando = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('🔄 Sincronizando $nomeModulo...'),
              backgroundColor: Colors.blueGrey,
            ),
          );
      }

      final temConexao = await _syncController.verificarConexao();
      if (!temConexao) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sem conexão com internet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await acao();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sincronização de $nomeModulo concluída!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro na sincronização de $nomeModulo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _onSyncOptionSelected(String value) async {
    if (value == 'total') {
      await _sincronizarManual();
      return;
    }
    if (value == 'animais') {
      await _sincronizarModulo(
        nomeModulo: 'Animais',
        acao: _syncController.sincronizarAnimais,
      );
      return;
    }
    if (value == 'nascimentos') {
      await _sincronizarModulo(
        nomeModulo: 'Nascimento',
        acao: _syncController.sincronizarNascimentos,
      );
      return;
    }
    if (value == 'baixas') {
      await _sincronizarModulo(
        nomeModulo: 'Baixas',
        acao: _syncController.sincronizarBaixas,
      );
      return;
    }
    if (value == 'transferencias') {
      await _sincronizarModulo(
        nomeModulo: 'Transferências',
        acao: _syncController.sincronizarTransferencias,
      );
      return;
    }
    if (value == 'usuarios') {
      await _sincronizarModulo(
        nomeModulo: 'Usuários',
        acao: _syncController.sincronizarUsuarios,
      );
    }
  }

  Future<void> _logout() async {
    await TokenService.limparToken();
    AppSession.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _card({
    required BuildContext context,
    required String title,
    required String assetName,
    required bool enabled,
    bool showOpenLabel = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    assetName,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (!enabled)
                const Text('Em breve',
                    style: TextStyle(fontSize: 12, color: Colors.black54))
              else if (showOpenLabel)
                const Text('Abrir',
                    style: TextStyle(fontSize: 12, color: Colors.black54))
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = AppSession.usuarioNome ?? 'Usuário';
    final fazenda = AppSession.fazendaSelecionada ?? 'Sem fazenda';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Mudar fazenda',
          icon: const Icon(Icons.agriculture),
          onPressed: () async {
            final mudou = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FazendaSelectPage(voltarAposSelecionar: true),
              ),
            );
            if (mudou == true && mounted) {
              setState(() {});
            }
          },
        ),
        title: Text('Rotinas • $nome • $fazenda'),
        actions: [
          if (AppSession.isAdmin)
            IconButton(
              tooltip: 'Admin',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUsersPage()),
              ),
              icon: const Icon(Icons.admin_panel_settings),
            ),
          _sincronizando
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Sincronizar com Nuvem',
                  icon: const Icon(Icons.cloud_upload),
                  onSelected: _onSyncOptionSelected,
                  itemBuilder: (_) {
                    final items = <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'total',
                        child: Text('Sincronização total'),
                      ),
                      const PopupMenuItem(
                        value: 'animais',
                        child: Text('Sincronizar Animais'),
                      ),
                      const PopupMenuItem(
                        value: 'nascimentos',
                        child: Text('Sincronizar Nascimento'),
                      ),
                      const PopupMenuItem(
                        value: 'baixas',
                        child: Text('Sincronizar Baixas'),
                      ),
                      const PopupMenuItem(
                        value: 'transferencias',
                        child: Text('Sincronizar Transferências'),
                      ),
                    ];
                    if (AppSession.isAdmin) {
                      items.add(
                        const PopupMenuItem(
                          value: 'usuarios',
                          child: Text('Sincronizar Usuários'),
                        ),
                      );
                    }
                    return items;
                  },
                ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Menu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _card(
                      context: context,
                      title: 'Nascimento',
                      assetName: 'assets/calf_born_add.png',
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NascimentoListPage()),
                      ),
                    ),
                    _card(
                      context: context,
                      title: 'Baixa',
                      assetName: 'assets/calf_born_death.png',
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MorteListPage()),
                      ),
                    ),
                    _card(
                      context: context,
                      title: 'Transferência',
                      assetName: 'assets/transfer.jpeg',
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TransferenciaListPage()),
                      ),
                    ),
                    _card(
                      context: context,
                      title: 'Vacina',
                      assetName: 'assets/vaccine.png',
                      enabled: false,
                    ),
                    _card(
                      context: context,
                      title: 'Pesagem',
                      assetName: 'assets/weighing_scale.png',
                      enabled: false,
                    ),
                    _card(
                      context: context,
                      title: 'Venda',
                      assetName: 'assets/cow_skull_sell.png',
                      enabled: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AppSession.isAdmin
          ? FloatingActionButton(
              tooltip: 'Animais',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimalListPage()),
              ),
              child: const Text(
                '🐄',
                style: TextStyle(fontSize: 24),
              ),
            )
          : null,
    );
  }
}
