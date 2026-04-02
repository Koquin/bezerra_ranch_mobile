import '../services/usuario_service.dart';
import '../models/usuario.dart';

class AuthController {
  final UsuarioService _usuarioService;

  AuthController({UsuarioService? usuarioService})
      : _usuarioService = usuarioService ?? UsuarioService();

  Future<Usuario?> login(String login, String senha) {
    return _usuarioService.login(login, senha);
  }
}
