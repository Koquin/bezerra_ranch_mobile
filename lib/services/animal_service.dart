import 'app_db.dart';
import '../models/nascimento.dart';

class AnimalService {
  Future<Nascimento?> getByCria(String cria) async {
    print('[AnimalService.getByCria] cria=$cria');
    final db = await AppDb.getDb();
    final rows = await db.query(
      'animal',
      where: 'UPPER(TRIM(cria)) = UPPER(TRIM(?))',
      whereArgs: [cria],
      limit: 1,
    );
    if (rows.isEmpty) {
      print('[AnimalService.getByCria] nao encontrado');
      return null;
    }
    final animal = Nascimento.fromMap(rows.first);
    print(
        '[AnimalService.getByCria] encontrado id=${animal.id} sexo=${animal.sexo} fazenda=${animal.fazenda} status=${animal.status}');
    return animal;
  }

  Future<List<Nascimento>> list({String? q}) async {
    print('Entrou no list do AnimalService, q=$q');
    final db = await AppDb.getDb();

    if (q == null || q.trim().isEmpty) {
      final rows = await db.query('animal', orderBy: 'criado_em DESC');
      final result = rows.map(Nascimento.fromMap).toList();
      print(
          'AnimalService.list retornou ${result.length} registros (sem filtro).');
      return result;
    }

    final term = '%${q.trim()}%';
    final rows = await db.query(
      'animal',
      where:
          'cria LIKE ? OR mae LIKE ? OR fazenda LIKE ? OR raca LIKE ? OR pelagem LIKE ? OR sexo LIKE ?',
      whereArgs: [term, term, term, term, term, term],
      orderBy: 'criado_em DESC',
    );
    final result = rows.map(Nascimento.fromMap).toList();
    print(
        'AnimalService.list retornou ${result.length} registros (com filtro).');
    return result;
  }
}
