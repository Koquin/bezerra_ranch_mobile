import 'package:flutter/material.dart';
import '../../controllers/usuario_controller.dart';
import '../../models/usuario.dart';

class UserFormPage extends StatefulWidget {
  final Usuario? edit;
  const UserFormPage({super.key, this.edit});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _usuarioController = UsuarioController();
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _login = TextEditingController();
  final _senha = TextEditingController();
  final _prefixo = TextEditingController();
  final _inicio = TextEditingController();
  final _maximo = TextEditingController();
  bool _ativo = true;
  bool _isAdmin = false;
  bool _saving = false;

  bool get _isNew => widget.edit == null;

  @override
  void initState() {
    super.initState();
    print('Entrou no initState do UserFormPage');
    final u = widget.edit;
    if (u != null) {
      _nome.text = u.nome;
      _login.text = u.login;
      _prefixo.text = u.prefixo;
      _inicio.text = u.inicio.toString();
      _maximo.text = u.maximo.toString();
      _ativo = u.ativo;
      _isAdmin = u.isAdmin;
    } else {
      _prefixo.text = 'E';
      _inicio.text = '10';
      _maximo.text = '1000';
      _ativo = true;
      _isAdmin = false;
    }
  }

  @override
  void dispose() {
    print('Entrou no dispose do UserFormPage');
    _nome.dispose();
    _login.dispose();
    _senha.dispose();
    _prefixo.dispose();
    _inicio.dispose();
    _maximo.dispose();
    super.dispose();
  }

  String? _valPrefixo(String? v) {
    print('Entrou no _valPrefixo do UserFormPage, v=$v');
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Informe o prefixo (1 letra)';
    if (s.length != 1) return 'Use apenas 1 letra';
    if (!RegExp(r'^[A-Za-z]$').hasMatch(s))
      return 'O prefixo deve ser uma letra';
    return null;
  }

  String? _valInt(String? v, String label) {
    print('Entrou no _valInt do UserFormPage, v=$v, label=$label');
    final s = (v ?? '').trim();
    final n = int.tryParse(s);
    if (n == null) return 'Informe $label válido';
    if (n < 0) return '$label não pode ser negativo';
    return null;
  }

  Future<void> _save() async {
    print('Entrou no _save do UserFormPage, isNew=$_isNew');
    if (!_formKey.currentState!.validate()) return;

    final nome = _nome.text.trim();
    final login = _login.text.trim();
    final prefixo = _prefixo.text.trim().toUpperCase();
    final inicio = int.parse(_inicio.text.trim());
    final maximo = int.parse(_maximo.text.trim());

    if (inicio > maximo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O número inicial não pode ser maior que o máximo.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Verifica se a faixa sobrepõe com outros usuários
      // Nota: Ao editar, o próprio usuário é excluído da verificação (excludeId)
      // permitindo que o admin altere dados sem conflito com a faixa atual do usuário
      final existe = await _usuarioController.existeFaixaSobreposta(
          prefixo, inicio, maximo,
          excludeId: _isNew ? null : widget.edit!.id);
      if (existe) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Faixa informada sobrepõe faixa de outro usuário.')));
        return;
      }

      if (_isNew) {
        final senha = _senha.text;
        if (senha.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Informe a senha do novo usuário.')),
          );
          return;
        }
        await _usuarioController.create(
          nome: nome,
          login: login,
          senha: senha,
          ativo: _ativo,
          isAdmin: _isAdmin,
          prefixo: prefixo,
          inicio: inicio,
          maximo: maximo,
        );
      } else {
        await _usuarioController.update(
          id: widget.edit!.id,
          nome: nome,
          login: login,
          ativo: _ativo,
          isAdmin: _isAdmin,
          prefixo: prefixo,
          inicio: inicio,
          maximo: maximo,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do UserFormPage');
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Novo usuário' : 'Editar usuário')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _login,
                decoration: const InputDecoration(labelText: 'Login'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o login' : null,
              ),
              const SizedBox(height: 12),
              if (_isNew)
                TextFormField(
                  controller: _senha,
                  decoration:
                      const InputDecoration(labelText: 'Senha (novo usuário)'),
                  obscureText: true,
                ),
              if (_isNew) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prefixo,
                      decoration: const InputDecoration(labelText: 'Prefixo'),
                      validator: _valPrefixo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _inicio,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Início'),
                      validator: (v) => _valInt(v, 'início'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Máximo'),
                      validator: (v) => _valInt(v, 'máximo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
                title: const Text('Usuário ativo'),
              ),
              SwitchListTile(
                value: _isAdmin,
                onChanged: (v) => setState(() => _isAdmin = v),
                title: const Text('É Admin'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Salvando...' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
