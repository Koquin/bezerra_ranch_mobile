import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TokenService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserData = 'user_data';

  // Salvar token e dados do usuário
  static Future<void> salvarToken({
    required int usuarioId,
    required String nome,
    required String login,
    required bool isAdmin,
    required String criaPrefixo,
    required int criaInicio,
    required int criaMax,
    required bool travaFazenda,
    String? lockedFazenda,
  }) async {
    print('📝 Salvando token para usuário: $login (id: $usuarioId)');
    final prefs = await SharedPreferences.getInstance();

    // Gerar token simples (timestamp + userId)
    final token = '${DateTime.now().millisecondsSinceEpoch}_$usuarioId';

    // Salvar dados
    final userData = {
      'id': usuarioId,
      'nome': nome,
      'login': login,
      'isAdmin': isAdmin,
      'criaPrefixo': criaPrefixo,
      'criaInicio': criaInicio,
      'criaMax': criaMax,
      'travaFazenda': travaFazenda,
      'lockedFazenda': lockedFazenda,
    };

    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyUserId, usuarioId);
    await prefs.setString(_keyUserData, json.encode(userData));

    print('✅ Token salvo com sucesso');
  }

  // Verificar se tem token válido
  static Future<bool> temToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }

  // Obter dados do usuário do token
  static Future<Map<String, dynamic>?> obterDadosUsuario() async {
    print('🔍 Buscando dados do usuário do token...');
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString(_keyUserData);

    if (userDataStr == null) {
      print('❌ Nenhum dado de usuário encontrado');
      return null;
    }

    try {
      final userData = json.decode(userDataStr) as Map<String, dynamic>;
      print('✅ Dados do usuário recuperados: ${userData['login']}');
      return userData;
    } catch (e) {
      print('❌ Erro ao decodificar dados do usuário: $e');
      return null;
    }
  }

  // Limpar token (logout)
  static Future<void> limparToken() async {
    print('🗑️ Limpando token...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserData);
    print('✅ Token limpo');
  }

  // Obter ID do usuário
  static Future<int?> obterUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }
}
