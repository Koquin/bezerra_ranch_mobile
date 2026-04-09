class Morte {
  static const String tipoMorte = 'MORTE';
  static const String tipoAbate = 'ABATE';

  final int? id;
  final int nascimentoId;
  final String tipoBaixa;
  final DateTime dataMorte;
  final String fazenda;
  final String? foto1;
  final String? foto2;
  final String? foto3;
  final String? audio;
  final String? descricao;
  final int usuarioId;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final String? locationCidade;
  final String? locationBairro;
  final double? locationLatitude;
  final double? locationLongitude;

  Morte({
    this.id,
    required this.nascimentoId,
    String? tipoBaixa,
    required this.dataMorte,
    required this.fazenda,
    this.foto1,
    this.foto2,
    this.foto3,
    this.audio,
    this.descricao,
    required this.usuarioId,
    required this.criadoEm,
    DateTime? atualizadoEm,
    this.locationCidade,
    this.locationBairro,
    this.locationLatitude,
    this.locationLongitude,
  })  : tipoBaixa = (tipoBaixa == null || tipoBaixa.trim().isEmpty)
            ? tipoMorte
            : tipoBaixa.trim().toUpperCase(),
        atualizadoEm = atualizadoEm ?? criadoEm;

  Map<String, Object?> toMap() => {
        'id': id,
        'nascimento_id': nascimentoId,
        'tipo_baixa': tipoBaixa,
        'data_morte': dataMorte.toIso8601String(),
        'fazenda': fazenda,
        'foto1': foto1,
        'foto2': foto2,
        'foto3': foto3,
        'audio': audio,
        'descricao': descricao,
        'usuario_id': usuarioId,
        'criado_em': criadoEm.toIso8601String(),
        'atualizado_em': atualizadoEm.toIso8601String(),
        'location_cidade': locationCidade,
        'location_bairro': locationBairro,
        'location_latitude': locationLatitude,
        'location_longitude': locationLongitude,
      };

  static Morte fromMap(Map<String, Object?> m) => Morte(
        id: m['id'] as int?,
        nascimentoId: m['nascimento_id'] as int,
        tipoBaixa: (m['tipo_baixa'] as String?) ?? tipoMorte,
        dataMorte: DateTime.parse(m['data_morte'] as String),
        fazenda: m['fazenda'] as String,
        foto1: m['foto1'] as String?,
        foto2: m['foto2'] as String?,
        foto3: m['foto3'] as String?,
        audio: m['audio'] as String?,
        descricao: m['descricao'] as String?,
        usuarioId: m['usuario_id'] as int,
        criadoEm: DateTime.parse(m['criado_em'] as String),
        atualizadoEm: m['atualizado_em'] != null
            ? DateTime.parse(m['atualizado_em'] as String)
            : DateTime.parse(m['criado_em'] as String),
        locationCidade: m['location_cidade'] as String?,
        locationBairro: m['location_bairro'] as String?,
        locationLatitude: _parseDouble(m['location_latitude']),
        locationLongitude: _parseDouble(m['location_longitude']),
      );

  static double? _parseDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
