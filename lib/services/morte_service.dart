import 'app_db.dart';
import '../models/morte.dart';

class MorteService {
  Future<List<Morte>> list({String? q}) async {
    print('Entrou no list do MorteService, q=$q');
    final db = await AppDb.getDb();
    final rows = await db.query('morte_log', orderBy: 'criado_em DESC');
    final result = rows.map(Morte.fromMap).toList();
    print(
        'MorteService.list retornando ${result.length} registros: ${result.map((m) => m.toMap()).toList()}');
    return result;
  }

  Future<Morte?> getPorNascimentoId(int nascimentoId) async {
    print('Buscando dados da morte para nascimentoId: $nascimentoId');
    final db = await AppDb.getDb();
    final rows = await db.query(
      'morte_log',
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
      await db.update('morte_log', morte.toMap(),
          where: 'id = ?', whereArgs: [morteExistenteId]);
      return;
    }

    await db.insert('morte_log', morte.toMap());
    await db.update('animal', {'status': 'MORTO'},
        where: 'id = ?', whereArgs: [animalId]);
  }

  Future<void> deletarPorNascimento({
    required int nascimentoId,
    required int morteId,
  }) async {
    final db = await AppDb.getDb();
    await db.delete('morte_log', where: 'id = ?', whereArgs: [morteId]);
    await db.update('animal', {'status': 'ATIVO'},
        where: 'id = ?', whereArgs: [nascimentoId]);
  }
}
