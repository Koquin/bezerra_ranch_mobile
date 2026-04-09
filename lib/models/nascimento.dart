class Nascimento {
  static const String statusAtivo = 'ATIVO';
  static const String statusVendido = 'VENDIDO';
  static const String statusMorto = 'MORTO';
  static const String statusAbatido = 'ABATIDO';

  final int? id;
  final String cria;
  final String mae;
  final String sexo;
  final String raca;
  final double? peso;
  final String pelagem;
  final DateTime dataNascimento;
  final String fazenda;
  final String? lote;
  final String? pasto;
  final String? observacao;
  final String? foto1;
  final String? foto2;
  final String? foto3;
  final int usuarioId;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final String status;
  final String? locationCidade;
  final String? locationBairro;
  final double? locationLatitude;
  final double? locationLongitude;

  Nascimento({
    this.id,
    required this.cria,
    required this.mae,
    required this.sexo,
    required this.raca,
    this.peso,
    required this.pelagem,
    required this.dataNascimento,
    required this.fazenda,
    this.lote,
    this.pasto,
    this.observacao,
    this.foto1,
    this.foto2,
    this.foto3,
    required this.usuarioId,
    required this.criadoEm,
    DateTime? atualizadoEm,
    String? status,
    bool? morto,
    this.locationCidade,
    this.locationBairro,
    this.locationLatitude,
    this.locationLongitude,
  })  : status = status ?? ((morto ?? false) ? statusMorto : statusAtivo),
        atualizadoEm = atualizadoEm ?? criadoEm;

  bool get morto => status == statusMorto;

  bool get vendido => status == statusVendido;

  bool get abatido => status == statusAbatido;

  Map<String, Object?> toMap() => {
        'id': id,
        'cria': cria,
        'mae': mae,
        'sexo': sexo,
        'raca': raca,
        'peso': peso,
        'pelagem': pelagem,
        'data_nascimento': dataNascimento.toIso8601String(),
        'fazenda': fazenda,
        'lote': lote,
        'pasto': pasto,
        'observacao': observacao,
        'foto1': foto1,
        'foto2': foto2,
        'foto3': foto3,
        'usuario_id': usuarioId,
        'criado_em': criadoEm.toIso8601String(),
        'atualizado_em': atualizadoEm.toIso8601String(),
        'status': status,
        'location_cidade': locationCidade,
        'location_bairro': locationBairro,
        'location_latitude': locationLatitude,
        'location_longitude': locationLongitude,
      };

  static Nascimento fromMap(Map<String, Object?> m) => Nascimento(
        id: m['id'] as int?,
        cria: m['cria'] as String,
        mae: m['mae'] as String,
        sexo: m['sexo'] as String,
        raca: m['raca'] as String,
        peso: _parseDouble(m['peso']),
        pelagem: m['pelagem'] as String,
        dataNascimento: DateTime.parse(m['data_nascimento'] as String),
        fazenda: m['fazenda'] as String,
        lote: m['lote'] as String?,
        pasto: m['pasto'] as String?,
        observacao: m['observacao'] as String?,
        foto1: m['foto1'] as String?,
        foto2: m['foto2'] as String?,
        foto3: m['foto3'] as String?,
        usuarioId: m['usuario_id'] as int,
        criadoEm: DateTime.parse(m['criado_em'] as String),
        atualizadoEm: m['atualizado_em'] != null
            ? DateTime.parse(m['atualizado_em'] as String)
            : DateTime.parse(m['criado_em'] as String),
        locationCidade: m['location_cidade'] as String?,
        locationBairro: m['location_bairro'] as String?,
        locationLatitude: _parseDouble(m['location_latitude']),
        locationLongitude: _parseDouble(m['location_longitude']),
        status: (() {
          final s = (m['status'] as String?)?.trim().toUpperCase();
          if (s == statusMorto ||
              s == statusVendido ||
              s == statusAtivo ||
              s == statusAbatido) {
            return s;
          }

          final v = m['morto'];
          final isMorto = (() {
            if (v == null) return false;
            if (v is bool) return v;
            if (v is int) return v == 1;
            if (v is String) return v == '1' || v.toLowerCase() == 'true';
            return false;
          })();
          return isMorto ? statusMorto : statusAtivo;
        })(),
      );

  static double? _parseDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
