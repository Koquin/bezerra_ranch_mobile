import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';
import 'app_db.dart';

class ImportResult {
  final bool cancelled;
  final int imported;
  final int skipped;
  final List<String> warnings;

  const ImportResult({
    required this.cancelled,
    required this.imported,
    required this.skipped,
    this.warnings = const [],
  });
}

class ExportService {
  static const int _chunkSize = 1000;
  static const int _localWriteChunkSize = 300;
  final SupabaseClient _supabase = Supabase.instance.client;

  List<List<T>> _splitInChunks<T>(List<T> items, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

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
      'status',
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
        'status': r['status'],
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
        'status',
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
        'status': 'status',
      },
    );
  }

  Future<File> exportMortesCsv() async {
    final rows = await getTableDataByName('baixa_log', orderBy: 'criado_em');
    final filtered = filterColumns(rows, [
      'nascimento_id',
      'tipo_baixa',
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
        'tipo_baixa': r['tipo_baixa'] ?? 'MORTE',
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
        'tipo_baixa',
        'data_morte',
        'fazenda',
        'descricao',
        'usuario',
        'data_registro',
      ],
      rows: data,
      headerToKey: const {
        'cria': 'cria',
        'tipo_baixa': 'tipo_baixa',
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

  Future<ImportResult> importAnimaisCsv({
    required int usuarioId,
    String? fazendaFallback,
  }) async {
    final file = await _pickCsvFile();
    if (file == null) {
      return const ImportResult(cancelled: true, imported: 0, skipped: 0);
    }

    final rows = await _readCsvRows(file);
    var imported = 0;
    var skipped = 0;
    final warnings = <String>[];

    final payload = <Map<String, Object?>>[];
    final criasNoArquivo = <String>{};

    for (final row in rows) {
      final cria = _valAliases(row, const [
        'cod_animal',
        'codanimal',
        'codigo_animal',
        'cod_animal',
      ]);
      if (cria.isEmpty) {
        skipped++;
        warnings.add('Linha sem cod_animal foi ignorada.');
        continue;
      }

      // Duplicado no mesmo arquivo CSV: ignora.
      if (!criasNoArquivo.add(cria)) {
        skipped++;
        warnings.add('CRIA duplicada no CSV foi ignorada: $cria');
        continue;
      }

      final fazendaRaw = _valAliases(row, const ['fazenda']);
      final maeRaw = _valAliases(row, const ['mae', 'mãe']);
      final sexoRaw = _valAliases(row, const ['sexo']);
      final racaRaw = _valAliases(row, const ['raca', 'raça']);
      final pelagemRaw = _valAliases(row, const ['pelagem']);
      final loteRaw = _valAliases(row, const ['lote']);
      final pastoRaw = _valAliases(row, const ['pasto']);
      final nascimentoRaw = _valAliases(
          row, const ['nascimento', 'data_nascimento', 'data nascimento']);
      final statusRaw = _valAliases(row, const ['status']);
      final pesoRaw = _valAliases(row, const ['peso']);

      final now = DateTime.now().toIso8601String();
      final status = _normalizeStatus(statusRaw);
      final dataNascimento =
          _parseDateToIso(nascimentoRaw) ?? DateTime.now().toIso8601String();
      final fazenda = fazendaRaw.isEmpty
          ? (fazendaFallback?.trim().isNotEmpty == true
              ? fazendaFallback!.trim()
              : 'GERAL')
          : fazendaRaw;

      payload.add({
        'cria': cria,
        'mae': maeRaw.isEmpty ? 'N/I' : maeRaw,
        'sexo': sexoRaw.isEmpty ? 'N/I' : sexoRaw,
        'raca': racaRaw.isEmpty ? 'N/I' : racaRaw,
        'peso': _parseDouble(pesoRaw),
        'pelagem': pelagemRaw.isEmpty ? 'N/I' : pelagemRaw,
        'data_nascimento': dataNascimento,
        'fazenda': fazenda,
        'lote': _nullable(loteRaw),
        'pasto': _nullable(pastoRaw),
        'usuario_id': usuarioId,
        'criado_em': now,
        'atualizado_em': now,
        'status': status,
      });
    }

    for (var i = 0; i < payload.length; i += _chunkSize) {
      final end =
          (i + _chunkSize < payload.length) ? i + _chunkSize : payload.length;
      final chunk = payload.sublist(i, end);

      try {
        final chunkCrias = chunk
            .map((e) => (e['cria']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();

        final existing = await _supabase
            .from('animal')
            .select('cria')
            .inFilter('cria', chunkCrias);

        final existingCrias = (existing as List)
            .map((e) => (e['cria']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet();

        final toInsert = chunk
            .where((e) =>
                !existingCrias.contains((e['cria']?.toString() ?? '').trim()))
            .toList();

        if (toInsert.isNotEmpty) {
          final insertedRows =
              await _supabase.from('animal').insert(toInsert).select('cria');
          imported += (insertedRows as List).length;
        }

        skipped += (chunk.length - toInsert.length);
      } catch (e) {
        throw Exception('Falha ao enviar chunk de animais para Supabase: $e');
      }
    }

    return ImportResult(
      cancelled: false,
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<ImportResult> importNascimentosCsv({
    required int usuarioId,
    String? fazendaFallback,
  }) async {
    final file = await _pickCsvFile();
    if (file == null) {
      return const ImportResult(cancelled: true, imported: 0, skipped: 0);
    }

    final rows = await _readCsvRows(file);
    final db = await AppDb.getDb();
    var imported = 0;
    var skipped = 0;
    final warnings = <String>[];

    await db.transaction((txn) async {
      for (final rowChunk in _splitInChunks(rows, _localWriteChunkSize)) {
        final crias = rowChunk
            .map((r) => _val(r, 'cria'))
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        final userNames = rowChunk
            .map((r) => _valAliases(r, const ['usuario', 'usuário']))
            .where((u) => u.isNotEmpty)
            .toSet()
            .toList();

        final userByName = <String, int>{};
        if (userNames.isNotEmpty) {
          final placeholders = List.filled(userNames.length, '?').join(',');
          final users = await txn.query(
            'usuario',
            columns: ['id', 'nome'],
            where: 'nome IN ($placeholders)',
            whereArgs: userNames,
          );
          for (final u in users) {
            final id = u['id'];
            final nome = (u['nome']?.toString() ?? '').trim();
            if (id is int && nome.isNotEmpty) userByName[nome] = id;
          }
        }

        final animalByCria = <String, Map<String, Object?>>{};
        if (crias.isNotEmpty) {
          final placeholders = List.filled(crias.length, '?').join(',');
          final animals = await txn.query(
            'animal',
            columns: ['id', 'cria', 'criado_em'],
            where: 'cria IN ($placeholders)',
            whereArgs: crias,
          );
          for (final a in animals) {
            final cria = (a['cria']?.toString() ?? '').trim();
            if (cria.isNotEmpty) animalByCria[cria] = a;
          }
        }

        final batch = txn.batch();
        for (final row in rowChunk) {
          final cria = _val(row, 'cria');
          if (cria.isEmpty) {
            skipped++;
            warnings.add('Linha sem cria foi ignorada.');
            continue;
          }

          final usuarioNomeRaw = _valAliases(row, const ['usuario', 'usuário']);
          final usuarioIdFinal = userByName[usuarioNomeRaw] ?? usuarioId;

          final nowIso = DateTime.now().toIso8601String();
          final dataRegistro =
              _parseDateTimeToIso(_val(row, 'data_registro')) ?? nowIso;
          final dataNascimento =
              _parseDateToIso(_val(row, 'data_nascimento')) ?? dataRegistro;
          final fazenda = _val(row, 'fazenda').isEmpty
              ? (fazendaFallback?.trim().isNotEmpty == true
                  ? fazendaFallback!.trim()
                  : 'GERAL')
              : _val(row, 'fazenda');

          final animalBase = <String, Object?>{
            'cria': cria,
            'mae': _val(row, 'mae').isEmpty ? 'N/I' : _val(row, 'mae'),
            'sexo': _val(row, 'sexo').isEmpty ? 'N/I' : _val(row, 'sexo'),
            'raca': _val(row, 'raca').isEmpty ? 'N/I' : _val(row, 'raca'),
            'peso': _parseDouble(_val(row, 'peso')),
            'pelagem':
                _val(row, 'pelagem').isEmpty ? 'N/I' : _val(row, 'pelagem'),
            'data_nascimento': dataNascimento,
            'fazenda': fazenda,
            'lote': _nullable(_val(row, 'lote')),
            'pasto': _nullable(_val(row, 'pasto')),
            'observacao': _nullable(_val(row, 'observacao')),
            'usuario_id': usuarioIdFinal,
            'atualizado_em': dataRegistro,
            'status': 'ATIVO',
          };

          final existingAnimal = animalByCria[cria];
          int animalId;
          String animalCreated = dataRegistro;
          if (existingAnimal == null) {
            animalId = await txn.insert('animal', {
              ...animalBase,
              'criado_em': dataRegistro,
            });
            animalByCria[cria] = {
              'id': animalId,
              'cria': cria,
              'criado_em': dataRegistro,
            };
          } else {
            animalId = existingAnimal['id'] as int;
            animalCreated =
                (existingAnimal['criado_em'] as String?) ?? dataRegistro;
            batch.update(
              'animal',
              {
                ...animalBase,
                'criado_em': animalCreated,
              },
              where: 'id = ?',
              whereArgs: [animalId],
            );
          }

          final existingLog = await txn.query(
            'nascimento_log',
            columns: ['id', 'criado_em'],
            where: 'animal_id = ?',
            whereArgs: [animalId],
            limit: 1,
          );

          final logBase = <String, Object?>{
            'animal_id': animalId,
            'cria': cria,
            'mae': _val(row, 'mae').isEmpty ? 'N/I' : _val(row, 'mae'),
            'sexo': _val(row, 'sexo').isEmpty ? 'N/I' : _val(row, 'sexo'),
            'raca': _val(row, 'raca').isEmpty ? 'N/I' : _val(row, 'raca'),
            'peso': _parseDouble(_val(row, 'peso')),
            'pelagem':
                _val(row, 'pelagem').isEmpty ? 'N/I' : _val(row, 'pelagem'),
            'data_nascimento': dataNascimento,
            'fazenda': fazenda,
            'lote': _nullable(_val(row, 'lote')),
            'pasto': _nullable(_val(row, 'pasto')),
            'observacao': _nullable(_val(row, 'observacao')),
            'usuario_id': usuarioIdFinal,
            'atualizado_em': dataRegistro,
          };

          if (existingLog.isEmpty) {
            batch.insert('nascimento_log', {
              ...logBase,
              'criado_em': dataRegistro,
            });
          } else {
            final created =
                (existingLog.first['criado_em'] as String?) ?? dataRegistro;
            batch.update(
              'nascimento_log',
              {
                ...logBase,
                'criado_em': created,
              },
              where: 'id = ?',
              whereArgs: [existingLog.first['id']],
            );
          }

          imported++;
        }

        await batch.commit(noResult: true, continueOnError: true);
      }
    });

    return ImportResult(
      cancelled: false,
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<ImportResult> importBaixasCsv({
    required int usuarioId,
    String? fazendaFallback,
  }) async {
    final file = await _pickCsvFile();
    if (file == null) {
      return const ImportResult(cancelled: true, imported: 0, skipped: 0);
    }

    final rows = await _readCsvRows(file);
    final db = await AppDb.getDb();
    var imported = 0;
    var skipped = 0;
    final warnings = <String>[];

    await db.transaction((txn) async {
      for (final rowChunk in _splitInChunks(rows, _localWriteChunkSize)) {
        final crias = rowChunk
            .map((r) => _val(r, 'cria'))
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        final userNames = rowChunk
            .map((r) => _valAliases(r, const ['usuario', 'usuário']))
            .where((u) => u.isNotEmpty)
            .toSet()
            .toList();

        final userByName = <String, int>{};
        if (userNames.isNotEmpty) {
          final placeholders = List.filled(userNames.length, '?').join(',');
          final users = await txn.query(
            'usuario',
            columns: ['id', 'nome'],
            where: 'nome IN ($placeholders)',
            whereArgs: userNames,
          );
          for (final u in users) {
            final id = u['id'];
            final nome = (u['nome']?.toString() ?? '').trim();
            if (id is int && nome.isNotEmpty) userByName[nome] = id;
          }
        }

        final animalByCria = <String, Map<String, Object?>>{};
        if (crias.isNotEmpty) {
          final placeholders = List.filled(crias.length, '?').join(',');
          final animals = await txn.query(
            'animal',
            columns: ['id', 'cria', 'criado_em'],
            where: 'cria IN ($placeholders)',
            whereArgs: crias,
          );
          for (final a in animals) {
            final cria = (a['cria']?.toString() ?? '').trim();
            if (cria.isNotEmpty) animalByCria[cria] = a;
          }
        }

        final batch = txn.batch();
        for (final row in rowChunk) {
          final cria = _val(row, 'cria');
          if (cria.isEmpty) {
            skipped++;
            warnings.add('Linha de baixa sem cria foi ignorada.');
            continue;
          }

          final usuarioNomeRaw = _valAliases(row, const ['usuario', 'usuário']);
          final usuarioIdFinal = userByName[usuarioNomeRaw] ?? usuarioId;

          final nowIso = DateTime.now().toIso8601String();
          final dataRegistro =
              _parseDateTimeToIso(_val(row, 'data_registro')) ?? nowIso;
          final dataMorte =
              _parseDateToIso(_val(row, 'data_morte')) ?? dataRegistro;
          final tipoBaixa = _normalizeTipoBaixa(_val(row, 'tipo_baixa'));
          final statusAnimal = tipoBaixa == 'ABATE' ? 'ABATIDO' : 'MORTO';

          final fazendaBaixa = _val(row, 'fazenda').isEmpty
              ? (fazendaFallback?.trim().isNotEmpty == true
                  ? fazendaFallback!.trim()
                  : 'GERAL')
              : _val(row, 'fazenda');

          final animal = animalByCria[cria];
          int animalId;
          if (animal == null) {
            animalId = await txn.insert('animal', {
              'cria': cria,
              'mae': 'N/I',
              'sexo': 'N/I',
              'raca': 'N/I',
              'peso': null,
              'pelagem': 'N/I',
              'data_nascimento': dataMorte,
              'fazenda': fazendaBaixa,
              'lote': null,
              'pasto': null,
              'observacao': 'Criado automaticamente no import de baixas.',
              'usuario_id': usuarioIdFinal,
              'criado_em': dataRegistro,
              'atualizado_em': dataRegistro,
              'status': statusAnimal,
            });
            animalByCria[cria] = {
              'id': animalId,
              'cria': cria,
              'criado_em': dataRegistro,
            };
          } else {
            animalId = animal['id'] as int;
          }

          final existing = await txn.query(
            'baixa_log',
            columns: ['id', 'criado_em'],
            where: 'nascimento_id = ?',
            whereArgs: [animalId],
            limit: 1,
          );

          final baixaBase = <String, Object?>{
            'nascimento_id': animalId,
            'tipo_baixa': tipoBaixa,
            'data_morte': dataMorte,
            'fazenda': fazendaBaixa,
            'descricao': _nullable(_val(row, 'descricao')),
            'usuario_id': usuarioIdFinal,
            'atualizado_em': dataRegistro,
          };

          if (existing.isEmpty) {
            batch.insert('baixa_log', {
              ...baixaBase,
              'criado_em': dataRegistro,
            });
          } else {
            final created =
                (existing.first['criado_em'] as String?) ?? dataRegistro;
            batch.update(
              'baixa_log',
              {
                ...baixaBase,
                'criado_em': created,
              },
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          }

          batch.update(
            'animal',
            {
              'status': statusAnimal,
              'atualizado_em': dataRegistro,
            },
            where: 'id = ?',
            whereArgs: [animalId],
          );

          imported++;
        }

        await batch.commit(noResult: true, continueOnError: true);
      }
    });

    return ImportResult(
      cancelled: false,
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<ImportResult> importTransferenciasCsv({
    required int usuarioId,
  }) async {
    final file = await _pickCsvFile();
    if (file == null) {
      return const ImportResult(cancelled: true, imported: 0, skipped: 0);
    }

    final rows = await _readCsvRows(file);
    final db = await AppDb.getDb();
    var imported = 0;
    var skipped = 0;
    final warnings = <String>[];

    await db.transaction((txn) async {
      for (final rowChunk in _splitInChunks(rows, _localWriteChunkSize)) {
        final crias = rowChunk
            .map((r) => _valAliases(
                r, const ['cod_animal', 'codanimal', 'codigo_animal']))
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        final userNames = rowChunk
            .map((r) => _valAliases(r, const ['usuario', 'usuário']))
            .where((u) => u.isNotEmpty)
            .toSet()
            .toList();

        final userByName = <String, int>{};
        if (userNames.isNotEmpty) {
          final placeholders = List.filled(userNames.length, '?').join(',');
          final users = await txn.query(
            'usuario',
            columns: ['id', 'nome'],
            where: 'nome IN ($placeholders)',
            whereArgs: userNames,
          );
          for (final u in users) {
            final id = u['id'];
            final nome = (u['nome']?.toString() ?? '').trim();
            if (id is int && nome.isNotEmpty) userByName[nome] = id;
          }
        }

        final animalByCria = <String, Map<String, Object?>>{};
        if (crias.isNotEmpty) {
          final placeholders = List.filled(crias.length, '?').join(',');
          final animals = await txn.query(
            'animal',
            columns: ['id', 'cria', 'fazenda', 'lote', 'pasto'],
            where: 'cria IN ($placeholders)',
            whereArgs: crias,
          );
          for (final a in animals) {
            final cria = (a['cria']?.toString() ?? '').trim();
            if (cria.isNotEmpty) animalByCria[cria] = a;
          }
        }

        final batch = txn.batch();
        for (final row in rowChunk) {
          final cria = _valAliases(row, const [
            'cod_animal',
            'codanimal',
            'codigo_animal',
          ]);
          if (cria.isEmpty) {
            skipped++;
            warnings.add('Linha de transferência sem cod_animal foi ignorada.');
            continue;
          }

          final dataTransferenciaRaw = _valAliases(row, const [
            'dt_transferencia',
            'datatransferencia',
            'data_transferencia',
          ]);
          final dataRegistroRaw = _valAliases(row, const [
            'dt_registro',
            'datahoraregistro',
            'data_hora_registro',
            'dataregistro',
          ]);
          final fazendaOrigemRaw = _valAliases(row, const [
            'fazenda_origem',
            'fazendaorigem',
          ]);
          final fazendaDestinoRaw = _valAliases(row, const [
            'fazenda_destino',
            'fazendadestino',
          ]);
          final loteOrigemRaw = _valAliases(row, const [
            'lote_origem',
            'loteorigem',
          ]);
          final loteDestinoRaw = _valAliases(row, const [
            'lote_destino',
            'lotedestino',
          ]);
          final pastoOrigemRaw = _valAliases(row, const [
            'pasto_origem',
            'pastoorigem',
          ]);
          final pastoDestinoRaw = _valAliases(row, const [
            'pasto_destino',
            'pastodestino',
          ]);
          final inconsistenciaRaw = _valAliases(row, const [
            'inconsistencia',
            'is_inconsistency',
          ]);
          final usuarioNomeRaw = _valAliases(row, const ['usuario', 'usuário']);

          final nowIso = DateTime.now().toIso8601String();
          final dataTransferencia =
              _parseDateToIso(dataTransferenciaRaw) ?? nowIso;
          final dataRegistro = _parseDateTimeToIso(dataRegistroRaw) ?? nowIso;
          final inconsistencia = _toBooleanSimNao(inconsistenciaRaw) ? 1 : 0;

          final existingAnimal = animalByCria[cria];
          int animalId;
          Map<String, Object?> animalBase;
          if (existingAnimal == null) {
            final fazendaInicial = fazendaDestinoRaw.isNotEmpty
                ? fazendaDestinoRaw
                : (fazendaOrigemRaw.isNotEmpty ? fazendaOrigemRaw : 'GERAL');
            final loteInicial = _nullable(
                loteDestinoRaw.isNotEmpty ? loteDestinoRaw : loteOrigemRaw);
            final pastoInicial = _nullable(
                pastoDestinoRaw.isNotEmpty ? pastoDestinoRaw : pastoOrigemRaw);

            animalId = await txn.insert('animal', {
              'cria': cria,
              'mae': 'N/I',
              'sexo': 'N/I',
              'raca': 'N/I',
              'peso': null,
              'pelagem': 'N/I',
              'data_nascimento': dataTransferencia,
              'fazenda': fazendaInicial,
              'lote': loteInicial,
              'pasto': pastoInicial,
              'usuario_id': usuarioId,
              'criado_em': dataRegistro,
              'atualizado_em': dataRegistro,
              'status': 'ATIVO',
            });

            animalBase = {
              'id': animalId,
              'fazenda': fazendaInicial,
              'lote': loteInicial,
              'pasto': pastoInicial,
            };
            animalByCria[cria] = {
              'id': animalId,
              'cria': cria,
              'fazenda': fazendaInicial,
              'lote': loteInicial,
              'pasto': pastoInicial,
            };
            warnings.add(
                'Animal $cria não existia e foi criado automaticamente para importar a transferência.');
          } else {
            animalId = existingAnimal['id'] as int;
            animalBase = existingAnimal;
          }

          final usuarioIdFinal = userByName[usuarioNomeRaw] ?? usuarioId;
          final fazendaOrigem = fazendaOrigemRaw.isEmpty
              ? ((animalBase['fazenda'] as String?) ?? 'GERAL')
              : fazendaOrigemRaw;
          final fazendaDestino =
              fazendaDestinoRaw.isEmpty ? fazendaOrigem : fazendaDestinoRaw;
          final loteOrigem = _nullable(loteOrigemRaw) ??
              _nullable((animalBase['lote'] as String?) ?? '');
          final loteDestino = _nullable(loteDestinoRaw);
          final pastoOrigem = _nullable(pastoOrigemRaw) ??
              _nullable((animalBase['pasto'] as String?) ?? '');
          final pastoDestino = _nullable(pastoDestinoRaw);

          batch.insert('transferencia_log', {
            'animal_id': animalId,
            'fazenda_origem': fazendaOrigem,
            'fazenda_destino': fazendaDestino,
            'lote_origem': loteOrigem,
            'lote_destino': loteDestino,
            'pasto_origem': pastoOrigem,
            'pasto_destino': pastoDestino,
            'is_inconsistency': inconsistencia,
            'usuario_id': usuarioIdFinal,
            'data_transferencia': dataTransferencia,
            'data_registro': dataRegistro,
            'atualizado_em': dataRegistro,
          });

          batch.update(
            'animal',
            {
              'fazenda': fazendaDestino,
              'lote': loteDestino,
              'pasto': pastoDestino,
              'atualizado_em': dataRegistro,
            },
            where: 'id = ?',
            whereArgs: [animalId],
          );

          imported++;
        }

        await batch.commit(noResult: true, continueOnError: true);
      }
    });

    return ImportResult(
      cancelled: false,
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<File?> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) return null;
    return File(path);
  }

  Future<List<Map<String, String>>> _readCsvRows(File file) async {
    final bytes = await file.readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      // Alguns CSVs exportados em Windows/ANSI não vêm em UTF-8.
      content = latin1.decode(bytes);
    }

    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1);
    }

    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];

    final delimiter = lines.first.contains(';') ? ';' : ',';
    final headers =
        _parseCsvLine(lines.first, delimiter).map(_normalizeHeader).toList();

    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i], delimiter);
      if (values.every((v) => v.trim().isEmpty)) continue;

      final row = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        row[headers[c]] = c < values.length ? values[c].trim() : '';
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _parseCsvLine(String line, String delimiter) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      final isQuote = ch == '"';
      if (isQuote) {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && ch == delimiter) {
        result.add(sb.toString());
        sb.clear();
        continue;
      }
      sb.write(ch);
    }

    result.add(sb.toString());
    return result;
  }

  String _val(Map<String, String> row, String key) {
    return (row[_normalizeHeader(key)] ?? '').trim();
  }

  String _valAliases(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final v = _val(row, alias);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _normalizeHeader(String value) {
    final lower = value.trim().toLowerCase();
    final noAccent = lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');

    return noAccent.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _nullable(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  String _normalizeStatus(String value) {
    final v = value.trim().toUpperCase();
    if (v == 'MORTO' || v == 'ABATIDO' || v == 'VENDIDO') return v;
    return 'ATIVO';
  }

  String _normalizeTipoBaixa(String value) {
    final v = value.trim().toUpperCase();
    if (v == 'ABATE' || v == 'ABATIDO') return 'ABATE';
    return 'MORTE';
  }

  bool _toBooleanSimNao(String value) {
    final v = value.trim().toUpperCase();
    return v == 'SIM' || v == '1' || v == 'TRUE';
  }

  double? _parseDouble(String value) {
    final v = value.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  String? _parseDateToIso(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;

    final iso = DateTime.tryParse(v);
    if (iso != null) return iso.toIso8601String();

    final br = DateFormat('dd/MM/yyyy').tryParse(v);
    if (br != null) return br.toIso8601String();

    final brWithTime = DateFormat('dd/MM/yyyy HH:mm:ss').tryParse(v);
    if (brWithTime != null) return brWithTime.toIso8601String();

    return null;
  }

  String? _parseDateTimeToIso(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;

    final iso = DateTime.tryParse(v);
    if (iso != null) return iso.toIso8601String();

    final brWithTime = DateFormat('dd/MM/yyyy HH:mm:ss').tryParse(v);
    if (brWithTime != null) return brWithTime.toIso8601String();

    final br = DateFormat('dd/MM/yyyy').tryParse(v);
    if (br != null) return br.toIso8601String();

    return null;
  }
}
