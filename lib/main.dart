import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'ui/auth/login_page.dart';
import 'ui/fazenda/fazenda_select_page.dart';
import 'controllers/sync_controller.dart';
import 'config/supabase_config.dart';
import 'services/token_service.dart';
import 'session/app_session.dart';

void main() async {
  print('Entrou no main');
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    print('✅ Supabase inicializado com sucesso');
  } catch (e) {
    print('❌ Erro ao inicializar Supabase: $e');
  }

  runApp(const BezerraRanchApp());
}

class BezerraRanchApp extends StatefulWidget {
  const BezerraRanchApp({super.key});

  @override
  State<BezerraRanchApp> createState() => _BezerraRanchAppState();
}

class _BezerraRanchAppState extends State<BezerraRanchApp>
    with WidgetsBindingObserver {
  final _syncController = SyncController();
  bool _verificandoToken = true;
  bool _usuarioLogado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('Entrou no initState do BezerraRanchApp');
    _verificarTokenECarregarSessao();
  }

  Future<void> _verificarTokenECarregarSessao() async {
    print('🔐 Verificando token...');
    AppSession.fazendaSelecionada = null;

    // Garante que os usuários remotos estejam no banco local antes do login.
    await _sincronizarUsuariosInicial();

    final temToken = await TokenService.temToken();
    if (temToken) {
      final userData = await TokenService.obterDadosUsuario();
      if (userData != null) {
        // Restaurar sessão
        AppSession.usuarioId = userData['id'];
        AppSession.usuarioNome = userData['nome'];
        AppSession.usuarioLogin = userData['login'];
        AppSession.isAdmin = userData['isAdmin'];
        AppSession.criaPrefixo = userData['criaPrefixo'];
        AppSession.criaInicio = userData['criaInicio'];
        AppSession.criaMax = userData['criaMax'];
        AppSession.travaFazenda = userData['travaFazenda'] ?? false;
        AppSession.lockedFazenda = userData['lockedFazenda'];

        print('✅ Sessão restaurada do token: ${userData['login']}');

        setState(() {
          _usuarioLogado = true;
          _verificandoToken = false;
        });
        return;
      }
    }

    print('❌ Nenhum token válido encontrado');
    setState(() {
      _usuarioLogado = false;
      _verificandoToken = false;
    });
  }

  Future<void> _sincronizarUsuariosInicial() async {
    try {
      final temConexao = await _syncController.verificarConexao();
      if (!temConexao) {
        print('⚠️ Sem conexão para sincronização inicial de usuários');
        return;
      }

      await _syncController.baixarUsuarios();
      print('✅ Sincronização inicial de usuários concluída');
    } catch (e) {
      // Não bloqueia abertura do app; login offline/local continua possível.
      print('❌ Erro na sincronização inicial de usuários: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('Estado do app mudou para: $state');

    // Sincronizar quando o app volta ao primeiro plano
    if (state == AppLifecycleState.resumed) {
      print('📱 App voltou ao primeiro plano - sincronizando...');
      _sincronizar();
    }

    // Sincronizar quando o app vai para background
    if (state == AppLifecycleState.paused) {
      print('📱 App indo para background - sincronizando...');
      _sincronizar();
    }
  }

  Future<void> _sincronizar() async {
    try {
      final temConexao = await _syncController.verificarConexao();
      if (temConexao) {
        await _syncController.sincronizar();
      } else {
        print('⚠️ Sem conexão com internet, sincronização adiada');
      }
    } catch (e) {
      print('❌ Erro na sincronização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do BezerraRanchApp');

    if (_verificandoToken) {
      return MaterialApp(
        title: 'Bezerra Ranch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme(),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verificando autenticação...'),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Bezerra Ranch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      home: _usuarioLogado ? const FazendaSelectPage() : const LoginPage(),
    );
  }
}
