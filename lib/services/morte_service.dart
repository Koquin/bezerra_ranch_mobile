import 'app_db.dart';
import '../models/morte.dart';

class MorteService {
  Future<List<Morte>> list({String? q}) async {
    print('Entrou no list do MorteService, q=$q');
    final db = await AppDb.getDb();
    final rows = await db.query('baixa_log', orderBy: 'criado_em DESC');
    final result = rows.map(Morte.fromMap).toList();

    final animalRows = await db.query(
      'animal',
      columns: ['id', 'cria'],
      where: 'cria = ?',
      whereArgs: ['I102966'],
      limit: 1,
    );
    if (animalRows.isEmpty) {
      print('DEBUG baixa I102966: animal não encontrado no banco local.');
    } else {
      final animalId = animalRows.first['id'] as int;
      final baixaRows = await db.query(
        'baixa_log',
        where: 'nascimento_id = ?',
        whereArgs: [animalId],
        limit: 1,
      );

      if (baixaRows.isEmpty) {
        print('DEBUG baixa I102966: animal encontrado (id=$animalId), sem baixa.');
      } else {
        print('DEBUG baixa I102966: ${baixaRows.first}');
      }
    }

    return result;
  }

  Future<Morte?> getPorNascimentoId(int nascimentoId) async {
    print('Buscando dados da morte para nascimentoId: $nascimentoId');
    final db = await AppDb.getDb();
    final rows = await db.query(
      'baixa_log',
      where: 'nascimento_id = ?',
      whereArgs: [nascimentoId],
      limit: 1,
    );
    if (rows.isEmpty) {
      print('Nenhuma morte encontrada para nascimentoId: $nascimentoId');
      return null;
    }
    final morte = Morte.fromMap(rows.first);
    print('Morte encontrada: ${morte.toMap()}');
    return morte;
  }

  Future<void> salvar({
    required Morte morte,
    required int animalId,
    int? morteExistenteId,
  }) async {
    final db = await AppDb.getDb();
    if (morteExistenteId != null) {
      await db.update('baixa_log', morte.toMap(),
          where: 'id = ?', whereArgs: [morteExistenteId]);
      final novoStatus =
          morte.tipoBaixa == Morte.tipoAbate ? 'ABATIDO' : 'MORTO';
      await db.update('animal', {'status': novoStatus},
          where: 'id = ?', whereArgs: [animalId]);
      return;
    }

    await db.insert('baixa_log', morte.toMap());
    final novoStatus = morte.tipoBaixa == Morte.tipoAbate ? 'ABATIDO' : 'MORTO';
    await db.update('animal', {'status': novoStatus},
        where: 'id = ?', whereArgs: [animalId]);
  }

  Future<void> deletarPorNascimento({
    required int nascimentoId,
    required int morteId,
  }) async {
    final db = await AppDb.getDb();
    await db.delete('baixa_log', where: 'id = ?', whereArgs: [morteId]);
    await db.update('animal', {'status': 'ATIVO'},
        where: 'id = ?', whereArgs: [nascimentoId]);
  }
}
