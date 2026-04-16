import 'app_db.dart';
import '../models/nascimento.dart';

class NascimentoService {
  int? _extractNumeroFromCria({
    required String cria,
    required String prefixo,
  }) {
    if (!cria.startsWith(prefixo)) return null;
    final sufixo = cria.substring(prefixo.length);
    return int.tryParse(sufixo);
  }

  Future<List<Nascimento>> list({String? q}) async {
    print('[NascimentoService.list] q=$q');
    final db = await AppDb.getDb();
    if (q == null || q.trim().isEmpty) {
      final rows = await db.query('nascimento_log', orderBy: 'criado_em DESC');
      final result = rows.map(Nascimento.fromMap).toList();
      print('[NascimentoService.list] total=${result.length} (sem filtro)');
      return result;
    }
    final term = '%${q.trim()}%';
    final rows = await db.query(
      'nascimento_log',
      where: 'cria LIKE ?',
      whereArgs: [term],
      orderBy: 'criado_em DESC',
    );
    final result = rows.map(Nascimento.fromMap).toList();
    print('[NascimentoService.list] total=${result.length} (com pesquisa)');
    return result;
  }

  Future<List<Nascimento>> listPorFaixa({
    required String prefixo,
    required int inicio,
    required int maximo,
    String? fazenda,
    int? usuarioId,
    String? q,
  }) async {
    print(
        '[NascimentoService.listPorFaixa] prefixo=$prefixo inicio=$inicio maximo=$maximo q=$q');
    final db = await AppDb.getDb();
    String baseWhere =
        'UPPER(TRIM(cria)) LIKE UPPER(TRIM(?)) AND CAST(SUBSTR(TRIM(cria), LENGTH(TRIM(?)) + 1) AS INTEGER) BETWEEN ? AND ?';
    final List<Object?> baseArgs = ['${prefixo}%', prefixo, inicio, maximo];

    String faixaWhere = baseWhere;
    final List<Object?> whereArgs = [...baseArgs];

    if (q != null && q.trim().isNotEmpty) {
      final term = '%${q.trim()}%';
      faixaWhere += ' AND cria LIKE ?';
      whereArgs.add(term);
    }

    final rows = await db.query(
      'nascimento_log',
      where: faixaWhere,
      whereArgs: whereArgs,
      orderBy: 'criado_em DESC',
    );
    final result = rows.map(Nascimento.fromMap).toList();
    print('[NascimentoService.listPorFaixa] total=${result.length}');
    return result;
  }

  Future<int> insert(Nascimento n) async {
    print('[NascimentoService.insert] cria=${n.cria} usuarioId=${n.usuarioId}');
    final db = await AppDb.getDb();
    final result = await db.insert('animal', n.toMap());
    final log = Map<String, Object?>.from(n.toMap())
      ..['id'] = result
      ..remove('status')
      ..['animal_id'] = result;
    await db.insert('nascimento_log', log);
    print('[NascimentoService.insert] id=$result');
    return result;
  }

  Future<int> update(Nascimento n) async {
    print('[NascimentoService.update] id=${n.id} cria=${n.cria}');
    final db = await AppDb.getDb();
    final animalMap = n.toMap();
    final logMap = Map<String, Object?>.from(n.toMap())..remove('status');

    await db.update('animal', animalMap, where: 'id = ?', whereArgs: [n.id]);
    final result = await db
        .update('nascimento_log', logMap, where: 'id = ?', whereArgs: [n.id]);
    print('[NascimentoService.update] linhasAfetadas=$result');
    return result;
  }

  Future<int> delete(int id) async {
    print('[NascimentoService.delete] id=$id');
    final db = await AppDb.getDb();
    final result =
        await db.delete('nascimento_log', where: 'id = ?', whereArgs: [id]);
    await db.delete('animal', where: 'id = ?', whereArgs: [id]);
    print('[NascimentoService.delete] linhasAfetadas=$result');
    return result;
  }

  Future<String> gerarProximaCriaPorUsuario({
    required int usuarioId,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) async {
    print(
        '[NascimentoService.gerarProximaCriaPorUsuario] usuarioId=$usuarioId prefixo=$prefixo inicio=$inicio maximo=$maximo');
    final db = await AppDb.getDb();

    return db.transaction<String>((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT cria FROM animal
        WHERE usuario_id = ? AND cria LIKE ?
        ORDER BY LENGTH(cria) DESC, cria DESC
        LIMIT 1
        ''',
        [usuarioId, '$prefixo%'],
      );

      int proximoNumero;
      if (rows.isEmpty) {
        proximoNumero = inicio;
      } else {
        final ultima = (rows.first['cria'] as String).trim();
        final numeroStr = ultima.replaceFirst(prefixo, '');
        final numero = int.tryParse(numeroStr) ?? (inicio - 1);
        proximoNumero = numero + 1;
      }

      if (proximoNumero > maximo) {
        throw Exception('LIMITE_ATINGIDO');
      }

      final result = '$prefixo$proximoNumero';
      print(
          '[NascimentoService.gerarProximaCriaPorUsuario] proximaCria=$result');
      return result;
    });
  }

  Future<int> obterUltimoNumeroUsado({
    required int usuarioId,
    required String prefixo,
  }) async {
    print(
        '[NascimentoService.obterUltimoNumeroUsado] usuarioId=$usuarioId prefixo=$prefixo');
    final db = await AppDb.getDb();

    final rows = await db.rawQuery(
      '''
      SELECT cria FROM animal
      WHERE usuario_id = ? AND cria LIKE ?
      ORDER BY LENGTH(cria) DESC, cria DESC
      LIMIT 1
      ''',
      [usuarioId, '$prefixo%'],
    );

    if (rows.isEmpty) return -1;

    final ultima = (rows.first['cria'] as String).trim();
    final numStr = ultima.replaceFirst(prefixo, '');
    return int.tryParse(numStr) ?? -1;
  }

  Future<int> obterUltimoNumeroUsadoPorPrefixo({
    required String prefixo,
  }) async {
    print(
        '[NascimentoService.obterUltimoNumeroUsadoPorPrefixo] prefixo="$prefixo"');
    final db = await AppDb.getDb();

    final rows = await db.rawQuery(
      '''
      SELECT cria FROM animal
      WHERE cria LIKE ?
      ''',
      ['$prefixo%'],
    );

    var maior = -1;
    for (final row in rows) {
      final cria = row['cria']?.toString() ?? '';
      final numero = _extractNumeroFromCria(cria: cria, prefixo: prefixo);
      if (numero != null && numero > maior) {
        maior = numero;
      }
    }
    return maior;
  }

  Future<int> obterPrimeiroNumeroDisponivelPorPrefixo({
    required String prefixo,
    required int inicio,
    required int maximo,
  }) async {
    print(
        '[NascimentoService.obterPrimeiroNumeroDisponivelPorPrefixo] prefixo="$prefixo" inicio=$inicio maximo=$maximo');
    final db = await AppDb.getDb();

    final usados = <int>{};

    final animais = await db.rawQuery(
      '''
      SELECT cria FROM animal
      WHERE cria LIKE ?
      ''',
      ['$prefixo%'],
    );
    for (final row in animais) {
      final cria = row['cria']?.toString() ?? '';
      final numero = _extractNumeroFromCria(cria: cria, prefixo: prefixo);
      if (numero != null) usados.add(numero);
    }

    final logs = await db.rawQuery(
      '''
      SELECT cria FROM nascimento_log
      WHERE cria LIKE ?
      ''',
      ['$prefixo%'],
    );
    for (final row in logs) {
      final cria = row['cria']?.toString() ?? '';
      final numero = _extractNumeroFromCria(cria: cria, prefixo: prefixo);
      if (numero != null) usados.add(numero);
    }

    for (var numero = inicio; numero <= maximo; numero++) {
      if (!usados.contains(numero)) {
        return numero;
      }
    }

    throw Exception('LIMITE_ATINGIDO');
  }

  Future<int> calcularRestantes({
    required int usuarioId,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) async {
    print(
        '[NascimentoService.calcularRestantes] usuarioId=$usuarioId prefixo=$prefixo inicio=$inicio maximo=$maximo');
    final ultimo =
        await obterUltimoNumeroUsado(usuarioId: usuarioId, prefixo: prefixo);
    final proximo = (ultimo < inicio) ? inicio : (ultimo + 1);
    final restantes = maximo - proximo + 1;
    print(
        '[NascimentoService.calcularRestantes] restantes=${restantes < 0 ? 0 : restantes}');
    return restantes < 0 ? 0 : restantes;
  }
}
