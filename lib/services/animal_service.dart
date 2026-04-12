import 'app_db.dart';
import '../models/nascimento.dart';

class AnimalService {
  Future<Nascimento?> getById(int id) async {
    final db = await AppDb.getDb();
    final rows = await db.query(
      'animal',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Nascimento.fromMap(rows.first);
  }

  Future<Nascimento?> getByCria(String cria) async {
    final db = await AppDb.getDb();
    final rows = await db.query(
      'animal',
      where: 'UPPER(TRIM(cria)) = UPPER(TRIM(?))',
      whereArgs: [cria],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Nascimento.fromMap(rows.first);
  }

  Future<List<Nascimento>> list({String? q}) async {
    final db = await AppDb.getDb();

    if (q == null || q.trim().isEmpty) {
      final rows = await db.query('animal', orderBy: 'criado_em DESC');
      return rows.map(Nascimento.fromMap).toList();
    }

    final term = '%${q.trim()}%';
    final rows = await db.query(
      'animal',
      where: 'cria LIKE ?',
      whereArgs: [term],
      orderBy: 'criado_em DESC',
    );
    return rows.map(Nascimento.fromMap).toList();
  }

  Future<List<Nascimento>> listVivos({String? q}) async {
    final listAll = await list(q: q);
    return listAll.where((n) => n.status == Nascimento.statusAtivo).toList();
  }
}
