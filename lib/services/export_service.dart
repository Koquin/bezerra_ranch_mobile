import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/usuario.dart';
import 'app_db.dart';

class ExportService {
  Future<List<Map<String, Object?>>> getTableDataByName(
    String tableName, {
    String? orderBy,
    bool descending = true,
  }) async {
    // Avoid dynamic SQL injection via table/order names.
    final safeName = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!safeName.hasMatch(tableName)) {
      throw ArgumentError('Nome de tabela inválido: $tableName');
    }

    if (orderBy != null && !safeName.hasMatch(orderBy)) {
      throw ArgumentError('Nome de coluna inválido para ordenação: $orderBy');
    }

    final db = await AppDb.getDb();
    final rows = await db.query(
      tableName,
      orderBy:
          orderBy == null ? null : '$orderBy ${descending ? 'DESC' : 'ASC'}',
    );
    return rows.cast<Map<String, Object?>>();
  }

  List<Map<String, Object?>> filterColumns(
    List<Map<String, Object?>> rows,
    List<String> columns,
  ) {
    return rows.map((row) {
      final filtered = <String, Object?>{};
      for (final c in columns) {
        filtered[c] = row[c];
      }
      return filtered;
    }).toList();
  }

  Future<File> exportTransferenciasCsv() async {
    final rows = await getTableDataByName(
      'transferencia_log',
      orderBy: 'data_registro',
    );

    final filtered = filterColumns(rows, [
      'usuario_id',
      'data_transferencia',
      'animal_id',
      'fazenda_origem',
      'fazenda_destino',
      'lote_origem',
      'lote_destino',
      'pasto_origem',
      'pasto_destino',
      'data_registro',
      'is_inconsistency',
    ]);

    final usuarios = await getTableDataByName('usuario');
    final usuarioNomeById = <int, String>{
      for (final u in usuarios)
        if (u['id'] is int) (u['id'] as int): (u['nome']?.toString() ?? '')
    };

    final animais = await getTableDataByName('animal');
    final criaByAnimalId = <int, String>{
      for (final a in animais)
        if (a['id'] is int) (a['id'] as int): (a['cria']?.toString() ?? '')
    };

    final data = filtered.map((r) {
      final usuarioId = r['usuario_id'] as int?;
      final animalId = r['animal_id'] as int?;
      final inconsistencia = (r['is_inconsistency'] as int? ?? 0) == 1;
      return <String, Object?>{
        'usuario_nome': usuarioNomeById[usuarioId] ?? '',
        'dt_transferencia': _formatDate(r['data_transferencia']?.toString()),
        'cod_animal': criaByAnimalId[animalId] ?? (animalId?.toString() ?? ''),
        'fazenda_origem': r['fazenda_origem'],
        'fazenda_destino': r['fazenda_destino'],
        'lote_origem': r['lote_origem'],
        'lote_destino': r['lote_destino'],
        'pasto_origem': r['pasto_origem'],
        'pasto_destino': r['pasto_destino'],
        'dt_registro': _formatDateTime(r['data_registro']?.toString()),
        'inconsistencia': inconsistencia ? 'SIM' : 'NAO',
      };
    }).toList();

    return _writeCsv(
      filePrefix: 'transferencias',
      headers: const [
        'usuario',
        'dt_transferencia',
        'cod_animal',
        'fazenda_origem',
        'fazenda_destino',
        'lote_origem',
        'lote_destino',
        'pasto_origem',
        'pasto_destino',
        'dt_registro',
        'inconsistencia',
      ],
      rows: data,
      headerToKey: const {
        'usuario': 'usuario_nome',
        'dt_transferencia': 'dt_transferencia',
        'cod_animal': 'cod_animal',
        'fazenda_origem': 'fazenda_origem',
        'fazenda_destino': 'fazenda_destino',
        'lote_origem': 'lote_origem',
        'lote_destino': 'lote_destino',
        'pasto_origem': 'pasto_origem',
        'pasto_destino': 'pasto_destino',
        'dt_registro': 'dt_registro',
        'inconsistencia': 'inconsistencia',
      },
    );
  }

  Future<File> exportAnimaisCsv() async {
    final rows = await getTableDataByName('animal', orderBy: 'atualizado_em');
    final filtered = filterColumns(rows, [
      'fazenda',
      'id',
      'cria',
      'sexo',
      'data_nascimento',
      'raca',
      'pelagem',
      'mae',
      'lote',
      'pasto',
    ]);

    final data = filtered.map((r) {
      final dataNasc = r['data_nascimento']?.toString();
      return <String, Object?>{
        'fazenda': r['fazenda'],
        'id_animal': r['id'],
        'cod_animal': r['cria'],
        'sexo': r['sexo'],
        'nascimento': _formatDate(dataNasc),
        'idade_meses': _idadeMeses(dataNasc),
        'raca': r['raca'],
        'pelagem': r['pelagem'],
        'mae': r['mae'],
        'lote': r['lote'],
        'pasto': r['pasto'],
      };
    }).toList();

    return _writeCsv(
      filePrefix: 'animais',
      headers: const [
        'fazenda',
        'id_animal',
        'cod_animal',
        'sexo',
        'nascimento',
        'idade_meses',
        'raca',
        'pelagem',
        'mae',
        'lote',
        'pasto',
      ],
      rows: data,
      headerToKey: const {
        'fazenda': 'fazenda',
        'id_animal': 'id_animal',
        'cod_animal': 'cod_animal',
        'sexo': 'sexo',
        'nascimento': 'nascimento',
        'idade_meses': 'idade_meses',
        'raca': 'raca',
        'pelagem': 'pelagem',
        'mae': 'mae',
        'lote': 'lote',
        'pasto': 'pasto',
      },
    );
  }

  Future<File> exportMortesCsv() async {
    final rows = await getTableDataByName('baixa_log', orderBy: 'criado_em');
    final filtered = filterColumns(rows, [
      'nascimento_id',
      'data_morte',
      'fazenda',
      'descricao',
      'usuario_id',
      'criado_em',
    ]);

    final usuarios = await getTableDataByName('usuario');
    final usuarioNomeById = <int, String>{
      for (final u in usuarios)
        if (u['id'] is int) (u['id'] as int): (u['nome']?.toString() ?? '')
    };

    final animais = await getTableDataByName('animal');
    final criaById = <int, String>{
      for (final a in animais)
        if (a['id'] is int) (a['id'] as int): (a['cria']?.toString() ?? '')
    };

    final nascimentos = await getTableDataByName('nascimento_log');
    for (final n in nascimentos) {
      final id = n['id'];
      if (id is int && !criaById.containsKey(id)) {
        criaById[id] = n['cria']?.toString() ?? '';
      }
    }

    final data = filtered.map((r) {
      final nascimentoId = r['nascimento_id'] as int?;
      final usuarioId = r['usuario_id'] as int?;
      return <String, Object?>{
        'cria': criaById[nascimentoId] ?? (nascimentoId?.toString() ?? ''),
        'data_morte': _formatDate(r['data_morte']?.toString()),
        'fazenda': r['fazenda'],
        'descricao': r['descricao'],
        'usuario': usuarioNomeById[usuarioId] ?? '',
        'data_registro': _formatDateTime(r['criado_em']?.toString()),
      };
    }).toList();

    return _writeCsv(
      filePrefix: 'mortes',
      headers: const [
        'cria',
        'data_morte',
        'fazenda',
        'descricao',
        'usuario',
        'data_registro',
      ],
      rows: data,
      headerToKey: const {
        'cria': 'cria',
        'data_morte': 'data_morte',
        'fazenda': 'fazenda',
        'descricao': 'descricao',
        'usuario': 'usuario',
        'data_registro': 'data_registro',
      },
    );
  }

  Future<File> exportNascimentosCsv() async {
    final rows =
        await getTableDataByName('nascimento_log', orderBy: 'criado_em');
    final filtered = filterColumns(rows, [
      'cria',
      'mae',
      'sexo',
      'raca',
      'pelagem',
      'data_nascimento',
      'fazenda',
      'observacao',
      'usuario_id',
      'criado_em',
      'peso',
      'lote',
      'pasto',
    ]);

    final usuarios = await getTableDataByName('usuario');
    final usuarioNomeById = <int, String>{
      for (final u in usuarios)
        if (u['id'] is int) (u['id'] as int): (u['nome']?.toString() ?? '')
    };

    final data = filtered.map((r) {
      final usuarioId = r['usuario_id'] as int?;
      return <String, Object?>{
        'cria': r['cria'],
        'mae': r['mae'],
        'sexo': r['sexo'],
        'raca': r['raca'],
        'pelagem': r['pelagem'],
        'data_nascimento': _formatDate(r['data_nascimento']?.toString()),
        'fazenda': r['fazenda'],
        'observacao': r['observacao'],
        'usuario': usuarioNomeById[usuarioId] ?? '',
        'data_registro': _formatDateTime(r['criado_em']?.toString()),
        'peso': r['peso'],
        'lote': r['lote'],
        'pasto': r['pasto'],
      };
    }).toList();

    return _writeCsv(
      filePrefix: 'nascimentos',
      headers: const [
        'cria',
        'mae',
        'sexo',
        'raca',
        'pelagem',
        'data_nascimento',
        'fazenda',
        'observacao',
        'usuario',
        'data_registro',
        'peso',
        'lote',
        'pasto',
      ],
      rows: data,
      headerToKey: const {
        'cria': 'cria',
        'mae': 'mae',
        'sexo': 'sexo',
        'raca': 'raca',
        'pelagem': 'pelagem',
        'data_nascimento': 'data_nascimento',
        'fazenda': 'fazenda',
        'observacao': 'observacao',
        'usuario': 'usuario',
        'data_registro': 'data_registro',
        'peso': 'peso',
        'lote': 'lote',
        'pasto': 'pasto',
      },
    );
  }

  Future<File> exportUsuariosCsv(List<Usuario> items) async {
    print(
        'Entrou no exportUsuariosCsv do ExportService, itens=${items.length}');
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/usuarios_$stamp.csv');

    final b = StringBuffer();
    b.writeln('ID,NOME,LOGIN,ATIVO,IS_ADMIN,PREFIXO,INICIO,MAXIMO');

    String esc(String? v) => v == null ? '' : '"${v.replaceAll('"', '""')}"';

    for (final u in items) {
      b.writeln([
        u.id.toString(),
        esc(u.nome),
        esc(u.login),
        u.ativo ? 'SIM' : 'NÃO',
        u.isAdmin ? 'SIM' : 'NÃO',
        esc(u.prefixo),
        u.inicio.toString(),
        u.maximo.toString(),
      ].join(','));
    }

    return file.writeAsString(b.toString(), flush: true);
  }

  Future<File> _writeCsv({
    required String filePrefix,
    required List<String> headers,
    required List<Map<String, Object?>> rows,
    required Map<String, String> headerToKey,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/${filePrefix}_$stamp.csv');

    final b = StringBuffer();
    b.writeln(headers.join(';'));

    for (final row in rows) {
      final values = headers.map((h) {
        final key = headerToKey[h] ?? h;
        return _esc(row[key]?.toString());
      }).join(';');
      b.writeln(values);
    }

    return file.writeAsString(b.toString(), flush: true);
  }

  String _esc(String? value) {
    if (value == null) return '';
    final v = value.replaceAll('"', '""');
    return '"$v"';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso.trim());
    if (dt == null) return iso;
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso.trim());
    if (dt == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
  }

  int _idadeMeses(String? dataNascimentoIso) {
    if (dataNascimentoIso == null || dataNascimentoIso.trim().isEmpty) return 0;
    final nascimento = DateTime.tryParse(dataNascimentoIso.trim());
    if (nascimento == null) return 0;

    final agora = DateTime.now();
    var meses =
        (agora.year - nascimento.year) * 12 + (agora.month - nascimento.month);
    if (agora.day < nascimento.day) {
      meses -= 1;
    }
    return meses < 0 ? 0 : meses;
  }
}
