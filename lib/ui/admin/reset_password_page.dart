import 'package:flutter/material.dart';
import '../../controllers/usuario_controller.dart';
import '../../models/usuario.dart';

class ResetPasswordPage extends StatefulWidget {
  final Usuario user;
  const ResetPasswordPage({super.key, required this.user});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _usuarioController = UsuarioController();
  final _formKey = GlobalKey<FormState>();
  final _senha = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    print('Entrou no dispose do ResetPasswordPage');
    _senha.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    print('Entrou no _reset do ResetPasswordPage, userId=${widget.user.id}');
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _usuarioController.resetSenha(
          id: widget.user.id, novaSenha: _senha.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resetar senha • ${widget.user.nome}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _senha,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a nova senha' : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _reset,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.key),
                  label: Text(_saving ? 'Salvando...' : 'Confirmar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
