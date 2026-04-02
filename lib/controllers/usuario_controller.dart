import '../services/usuario_service.dart';
import '../models/usuario.dart';

class UsuarioController {
  final UsuarioService _usuarioService;

  UsuarioController({UsuarioService? usuarioService})
      : _usuarioService = usuarioService ?? UsuarioService();

  Future<List<Usuario>> list() => _usuarioService.list();

  Future<Usuario?> getById(int id) => _usuarioService.getById(id);

  Future<int> create({
    required String nome,
    required String login,
    required String senha,
    required bool ativo,
    required bool isAdmin,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) {
    return _usuarioService.create(
      nome: nome,
      login: login,
      senha: senha,
      ativo: ativo,
      isAdmin: isAdmin,
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
    );
  }

  Future<int> update({
    required int id,
    required String nome,
    required String login,
    required bool ativo,
    required bool isAdmin,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) {
    return _usuarioService.update(
      id: id,
      nome: nome,
      login: login,
      ativo: ativo,
      isAdmin: isAdmin,
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
    );
  }

  Future<int> resetSenha({required int id, required String novaSenha}) {
    return _usuarioService.resetSenha(id: id, novaSenha: novaSenha);
  }

  Future<bool> existeFaixaSobreposta(String prefixo, int inicio, int maximo,
      {int? excludeId}) {
    return _usuarioService.existeFaixaSobreposta(prefixo, inicio, maximo,
        excludeId: excludeId);
  }
}
