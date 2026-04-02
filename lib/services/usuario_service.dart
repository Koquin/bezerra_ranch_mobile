import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'app_db.dart';
import '../models/usuario.dart';

class UsuarioService {
  String hashSenha(String senha) =>
      sha256.convert(utf8.encode(senha)).toString();

  Future<Usuario?> login(String login, String senha) async {
    print('Entrou no login do UsuarioService, login=$login');
    final db = await AppDb.getDb();
    final rows = await db.query(
      'usuario',
      where: 'login = ? AND senha_hash = ? AND ativo = 1',
      whereArgs: [login.trim(), hashSenha(senha)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Usuario.fromMap(rows.first);
  }

  Future<List<Usuario>> list() async {
    print('Entrou no list do UsuarioService');
    final db = await AppDb.getDb();
    final rows = await db.query('usuario', orderBy: 'nome ASC');
    return rows.map(Usuario.fromMap).toList();
  }

  Future<Usuario?> getById(int id) async {
    print('Entrou no getById do UsuarioService, id=$id');
    final db = await AppDb.getDb();
    final rows =
        await db.query('usuario', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Usuario.fromMap(rows.first);
  }

  Future<int> create({
    required String nome,
    required String login,
    required String senha,
    required bool ativo,
    required bool isAdmin,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) async {
    print(
        'Entrou no create do UsuarioService, nome=$nome, login=$login, prefixo=$prefixo, inicio=$inicio, maximo=$maximo, isAdmin=$isAdmin');
    final db = await AppDb.getDb();
    return db.insert('usuario', {
      'nome': nome.trim(),
      'login': login.trim(),
      'senha_hash': hashSenha(senha),
      'ativo': ativo ? 1 : 0,
      'cria_prefixo': prefixo.trim().toUpperCase(),
      'cria_inicio': inicio,
      'cria_max': maximo,
      'is_admin': isAdmin ? 1 : 0,
      'criado_em': DateTime.now().toIso8601String(),
      'atualizado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> existeFaixaSobreposta(String prefixo, int inicio, int maximo,
      {int? excludeId}) async {
    print(
        'Entrou no existeFaixaSobreposta do UsuarioService, prefixo=$prefixo inicio=$inicio maximo=$maximo excludeId=$excludeId');
    final db = await AppDb.getDb();
    final up = prefixo.trim().toUpperCase();

    final todosUsuarios = await db.query('usuario');
    print('TODOS OS USUARIOS NO BANCO: $todosUsuarios');

    var where = 'cria_prefixo = ? AND NOT (cria_max < ? OR cria_inicio > ?)';
    final args = [up, inicio, maximo];
    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }

    print('Query SQL: SELECT * FROM usuario WHERE $where');
    print('Args: $args');

    final rows = await db.rawQuery('SELECT * FROM usuario WHERE $where', args);
    print('Usuarios que sobrepoem a faixa: $rows');

    final countRows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM usuario WHERE $where', args);
    final count = (countRows.first['c'] as int?) ?? 0;
    print('Count de sobreposicoes: $count');

    return count > 0;
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
  }) async {
    print(
        'Entrou no update do UsuarioService, id=$id, nome=$nome, login=$login, prefixo=$prefixo, inicio=$inicio, maximo=$maximo, isAdmin=$isAdmin');
    final db = await AppDb.getDb();
    return db.update(
      'usuario',
      {
        'nome': nome.trim(),
        'login': login.trim(),
        'ativo': ativo ? 1 : 0,
        'cria_prefixo': prefixo.trim().toUpperCase(),
        'cria_inicio': inicio,
        'cria_max': maximo,
        'is_admin': isAdmin ? 1 : 0,
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> resetSenha({required int id, required String novaSenha}) async {
    print('Entrou no resetSenha do UsuarioService, id=$id');
    final db = await AppDb.getDb();
    return db.update(
      'usuario',
      {
        'senha_hash': hashSenha(novaSenha),
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
