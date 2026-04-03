import 'package:sqflite/sqflite.dart';

import '../models/nascimento.dart';
import '../models/transferencia_log.dart';
import 'app_db.dart';

class TransferenciaService {
  Future<void> registrarTransferencias({
    required List<Nascimento> animais,
    required String fazendaOrigem,
    required String fazendaDestino,
    required String loteDestino,
    required String pastoDestino,
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
