import 'package:sqflite/sqflite.dart';

import '../models/nascimento.dart';
import '../models/transferencia_log.dart';
import 'app_db.dart';

class TransferenciaService {
  Future<List<Map<String, Object?>>> listarTransferencias({String? q}) async {
    final db = await AppDb.getDb();
    final filtro = q?.trim() ?? '';

    if (filtro.isEmpty) {
      final rows = await db.rawQuery('''
        SELECT
          t.*, a.cria AS animal_cria
        FROM transferencia_log t
        LEFT JOIN animal a ON a.id = t.animal_id
        ORDER BY t.data_registro DESC
      ''');
      return rows.cast<Map<String, Object?>>();
    }

    final term = '%$filtro%';
    final rows = await db.rawQuery('''
      SELECT
        t.*, a.cria AS animal_cria
      FROM transferencia_log t
      LEFT JOIN animal a ON a.id = t.animal_id
      WHERE
        a.cria LIKE ? OR
        t.fazenda_origem LIKE ? OR
        t.fazenda_destino LIKE ? OR
        IFNULL(t.lote_origem, '') LIKE ? OR
        IFNULL(t.lote_destino, '') LIKE ? OR
        IFNULL(t.pasto_origem, '') LIKE ? OR
        IFNULL(t.pasto_destino, '') LIKE ? OR
        t.data_transferencia LIKE ?
      ORDER BY t.data_registro DESC
    ''', [term, term, term, term, term, term, term, term]);

    return rows.cast<Map<String, Object?>>();
  }

  Future<void> registrarTransferencias({
    required List<Nascimento> animais,
    required String fazendaOrigem,
    required String fazendaDestino,
    required String loteDestino,
    required String pastoDestino,
    required bool isInconsistency,
    required DateTime dataTransferencia,
    required int usuarioId,
  }) async {
    final db = await AppDb.getDb();
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (final animal in animais) {
        final log = TransferenciaLog(
          animalId: animal.id!,
          fazendaOrigem: fazendaOrigem,
          fazendaDestino: fazendaDestino,
          loteOrigem: animal.lote,
          loteDestino: loteDestino,
          pastoOrigem: animal.pasto,
          pastoDestino: pastoDestino,
          isInconsistency: isInconsistency,
          usuarioId: usuarioId,
          dataTransferencia: dataTransferencia,
          dataRegistro: now,
          atualizadoEm: now,
        );

        await txn.insert(
          'transferencia_log',
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.update(
          'animal',
          {
            'fazenda': fazendaDestino,
            'lote': loteDestino,
            'pasto': pastoDestino,
            'atualizado_em': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [animal.id],
        );
      }
    });
  }
}
