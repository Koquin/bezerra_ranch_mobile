import '../models/nascimento.dart';
import '../services/transferencia_service.dart';

class TransferenciaController {
  final TransferenciaService _service;

  TransferenciaController({TransferenciaService? service})
      : _service = service ?? TransferenciaService();

  Future<List<Map<String, Object?>>> listarTransferencias({String? q}) {
    return _service.listarTransferencias(q: q);
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
  }) {
    return _service.registrarTransferencias(
      animais: animais,
      fazendaOrigem: fazendaOrigem,
      fazendaDestino: fazendaDestino,
      loteDestino: loteDestino,
      pastoDestino: pastoDestino,
      isInconsistency: isInconsistency,
      dataTransferencia: dataTransferencia,
      usuarioId: usuarioId,
    );
  }
}
