class TransferenciaLog {
  final int? id;
  final int animalId;
  final String fazendaOrigem;
  final String fazendaDestino;
  final String? loteOrigem;
  final String? loteDestino;
  final String? pastoOrigem;
  final String? pastoDestino;
  final int usuarioId;
  final DateTime dataTransferencia;
  final DateTime dataRegistro;
  final DateTime atualizadoEm;

  TransferenciaLog({
    this.id,
    required this.animalId,
    required this.fazendaOrigem,
    required this.fazendaDestino,
    this.loteOrigem,
    this.loteDestino,
    this.pastoOrigem,
    this.pastoDestino,
    required this.usuarioId,
    required this.dataTransferencia,
    required this.dataRegistro,
    DateTime? atualizadoEm,
  }) : atualizadoEm = atualizadoEm ?? dataRegistro;

  Map<String, Object?> toMap() => {
        'id': id,
        'animal_id': animalId,
        'fazenda_origem': fazendaOrigem,
        'fazenda_destino': fazendaDestino,
        'lote_origem': loteOrigem,
        'lote_destino': loteDestino,
        'pasto_origem': pastoOrigem,
        'pasto_destino': pastoDestino,
        'usuario_id': usuarioId,
        'data_transferencia': dataTransferencia.toIso8601String(),
        'data_registro': dataRegistro.toIso8601String(),
        'atualizado_em': atualizadoEm.toIso8601String(),
      };
}
