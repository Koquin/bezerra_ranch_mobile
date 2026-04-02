import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../session/app_session.dart';
import '../../services/token_service.dart';
import '../fazenda/fazenda_select_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authController = AuthController();
  final _syncController = SyncController();
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sincronizarUsuariosAoEntrar();
  }

  Future<void> _sincronizarUsuariosAoEntrar() async {
    try {
      final temConexao = await _syncController.verificarConexao();
      if (!temConexao) return;
      await _syncController.baixarUsuarios();
      print('✅ Usuários sincronizados ao abrir LoginPage');
    } catch (e) {
      print('❌ Erro ao sincronizar usuários na LoginPage: $e');
    }
  }

  @override
  void dispose() {
    print('Entrou no dispose do LoginPage');
    _loginCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    print('Entrou no _entrar do LoginPage, login=${_loginCtrl.text}');
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final u = await _authController.login(_loginCtrl.text, _senhaCtrl.text);
      if (u == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login ou senha inválidos, ou usuário inativo.')),
        );
        return;
      }

      // Configurar sessão
      AppSession.usuarioId = u.id;
      AppSession.usuarioNome = u.nome;
      AppSession.usuarioLogin = u.login;
      AppSession.isAdmin = u.isAdmin;
      AppSession.criaPrefixo = u.prefixo;
      AppSession.criaInicio = u.inicio;
      AppSession.criaMax = u.maximo;
      AppSession.fazendaSelecionada = null;

      // Salvar token para login automático
      await TokenService.salvarToken(
        usuarioId: u.id,
        nome: u.nome,
        login: u.login,
        isAdmin: u.isAdmin,
        criaPrefixo: u.prefixo,
        criaInicio: u.inicio,
        criaMax: u.maximo,
        travaFazenda: AppSession.travaFazenda,
        lockedFazenda: AppSession.lockedFazenda,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FazendaSelectPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro no login: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do LoginPage');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF45A625), Color(0xFF358a1d)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Form(
                      key: _formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/BRC_logo.jpeg',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Bezerra Ranch',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF45A625),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sistema de Gestão de CRIA',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _loginCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe o login'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Informe a senha'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _entrar,
                            icon: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _loading ? 'Entrando...' : 'Entrar',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
