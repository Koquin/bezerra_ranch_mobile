class Solicitacao {
  final int id;
  final int usuarioId;
  final String usuarioNome;
  final String prefixo;
  final int inicioAtual;
  final int maxAtual;
  final int restantes;
  final DateTime solicitadoEm;
  final String status;

  Solicitacao({
    required this.id,
    required this.usuarioId,
    required this.usuarioNome,
    required this.prefixo,
    required this.inicioAtual,
    required this.maxAtual,
    required this.restantes,
    required this.solicitadoEm,
    required this.status,
  });

  static Solicitacao fromMap(Map<String, Object?> r) => Solicitacao(
        id: r['id'] as int,
        usuarioId: r['usuario_id'] as int,
        usuarioNome: r['usuario_nome'] as String,
        prefixo: r['prefixo'] as String,
        inicioAtual: r['inicio_atual'] as int,
        maxAtual: r['max_atual'] as int,
        restantes: r['restantes'] as int,
        solicitadoEm: DateTime.parse(r['solicitado_em'] as String),
        status: r['status'] as String,
      );
}
