import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_db.dart';
import '../session/app_session.dart';

class SupabaseSyncService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _chunkSize = 1000;
  static const int _localWriteChunkSize = 300;
  static const bool _verboseSyncDecisionLogs = false;

  static List<List<T>> _splitInChunks<T>(List<T> items, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  static Future<List<Map<String, dynamic>>> _downloadChunk(
    String table,
    String orderColumn,
    int offset,
  ) async {
    final response = await _supabase
        .from(table)
        .select()
        .order(orderColumn, ascending: false)
        .range(offset, offset + _chunkSize - 1);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static void _logChunkFetched({
    required String modulo,
    required int chunkNumber,
    required int offset,
    required int size,
  }) {
    print(
        '📦 [$modulo] chunk $chunkNumber baixado do Supabase (offset=$offset, tamanho=$size)');
  }

  static void _logChunkSaved({
    required String modulo,
    required int chunkNumber,
    required int size,
  }) {
    print('💾 [$modulo] chunk $chunkNumber salvo no BD local (tamanho=$size)');
  }

  static Future<bool> deveSincronizarAutomatico() async {
    try {
      final remoteVersion = await _buscarSyncVersionRemoto();
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString(_localSyncVersionKey);

      if (localVersion == null || localVersion.trim().isEmpty) {
        print('ℹ️ Sync automática inicial necessária (sem versão local).');
        return true;
      }

      final precisa = localVersion != remoteVersion;
      print(
          'ℹ️ Verificação de sync automática: local=$localVersion remoto=$remoteVersion precisaSincronizar=$precisa');
      return precisa;
    } catch (e) {
      print('⚠️ Falha ao verificar necessidade de sync automática: $e');
      return true;
    }
  }

  static Future<void> sincronizar() async {
    print('🔄 Iniciando sincronização com Supabase...');
    try {
      final resetFeito = await _verificarSyncVersionEReiniciar();
      if (resetFeito) {
        print('✅ Sincronização completa (reset local aplicado)');
        return;
      }

      await baixarUsuarios();
      await baixarAnimais();
      await baixarNascimentosLog();
      await sincronizarAnimalENascimentoLogLocal();
      await baixarTransferencias();
      await baixarMortes();
      await baixarSolicitacoes();

      if (AppSession.isAdmin) {
        await sincronizarUsuarios();
      }
      await sincronizarAnimais();
      await sincronizarNascimentosLog();
      await sincronizarAnimalENascimentoLogLocal();
      await sincronizarTransferencias();
      await sincronizarMortes();
      await sincronizarSolicitacoes();

      print('✅ Sincronização completa!');
    } catch (e) {
      print('❌ Erro na sincronização: $e');
      rethrow;
    }
  }

  static Future<bool> _prepararSincronizacaoComReset() async {
    final resetFeito = await _verificarSyncVersionEReiniciar();
    if (resetFeito) {
      print('✅ Sincronização finalizada via reset local aplicado');
      return true;
    }
    return false;
  }

  static Future<void> sincronizarModuloAnimais() async {
    print('🔄 Iniciando sincronização do módulo: Animais');
    if (await _prepararSincronizacaoComReset()) return;

    await baixarAnimais();
    await sincronizarAnimais();

    print('✅ Sincronização do módulo Animais concluída');
  }

  static Future<void> sincronizarModuloNascimentos() async {
    print('🔄 Iniciando sincronização do módulo: Nascimento');
    if (await _prepararSincronizacaoComReset()) return;

    await baixarNascimentosLog();
    await sincronizarNascimentosLog();
    await sincronizarAnimalENascimentoLogLocal();

    print('✅ Sincronização do módulo Nascimento concluída');
  }

  static Future<void> sincronizarModuloBaixas() async {
    print('🔄 Iniciando sincronização do módulo: Baixas');
    if (await _prepararSincronizacaoComReset()) return;

    await baixarMortes();
    await sincronizarMortes();

    print('✅ Sincronização do módulo Baixas concluída');
  }

  static Future<void> sincronizarModuloTransferencias() async {
    print('🔄 Iniciando sincronização do módulo: Transferências');
    if (await _prepararSincronizacaoComReset()) return;

    await baixarTransferencias();
    await sincronizarTransferencias();

    print('✅ Sincronização do módulo Transferências concluída');
  }

  // Sincronizar usuários
  static Future<void> sincronizarUsuarios() async {
    print('📤 Sincronizando usuários...');
    final db = await AppDb.getDb();
    final usuarios = await db.query('usuario');

    final byLogin = <String, Map<String, Object?>>{};
    for (final u in usuarios) {
      final login = u['login'] as String;
      byLogin[login] = u;
    }

    final payload = usuarios
        .map((u) => {
              'nome': u['nome'],
              'login': u['login'],
              'senha_hash': u['senha_hash'],
              'ativo': (u['ativo'] as int) == 1,
              'cria_prefixo': u['cria_prefixo'],
              'cria_inicio': u['cria_inicio'],
              'cria_max': u['cria_max'],
              'is_admin': (u['is_admin'] as int) == 1,
              'criado_em': u['criado_em'],
              'atualizado_em': u['atualizado_em'],
            })
        .toList();

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        final result = await _supabase
            .from('usuario')
            .upsert(chunk, onConflict: 'login')
            .select('id, login');

        final synced = (result as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        for (final row in synced) {
          final login = row['login']?.toString();
          final serverId = row['id'] as int?;
          if (login == null || serverId == null) continue;

          final local = byLogin[login];
          final localId = local?['id'] as int?;
          if (localId == null) continue;

          await _reconciliarUsuarioIdLocal(
            localId: localId,
            serverId: serverId,
            login: login,
          );
        }
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de usuários: $e');
      }
    }
  }

  // Sincronizar animais
  static Future<void> sincronizarAnimais() async {
    print('📤 Sincronizando animais...');
    final db = await AppDb.getDb();
    final animais = await db.query('animal');
    final userMap = <int, int?>{};
    final payload = <Map<String, Object?>>[];

    for (final n in animais) {
      try {
        final localUserId = n['usuario_id'] as int?;
        if (localUserId == null) continue;

        userMap[localUserId] ??=
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        final serverUserId = userMap[localUserId];
        if (serverUserId == null) continue;

        payload.add({
          'id': n['id'],
          'cria': n['cria'],
          'mae': n['mae'],
          'sexo': n['sexo'],
          'raca': n['raca'],
          'peso': n['peso'],
          'pelagem': n['pelagem'],
          'data_nascimento': n['data_nascimento'],
          'fazenda': n['fazenda'],
          'lote': n['lote'],
          'pasto': n['pasto'],
          'observacao': n['observacao'],
          'foto1': n['foto1'],
          'foto2': n['foto2'],
          'foto3': n['foto3'],
          'location_cidade': n['location_cidade'],
          'location_bairro': n['location_bairro'],
          'location_latitude': n['location_latitude'],
          'location_longitude': n['location_longitude'],
          'usuario_id': serverUserId,
          'criado_em': n['criado_em'],
          'atualizado_em': n['atualizado_em'],
          'status':
              (n['status'] ?? ((n['morto'] as int?) == 1 ? 'MORTO' : 'ATIVO')),
        });
      } catch (e) {
        print('✗ Erro ao preparar animal ${n['id']} para upload: $e');
      }
    }

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        await _supabase.from('animal').upsert(chunk, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de animais: $e');
      }
    }
  }

  static Future<void> sincronizarNascimentosLog() async {
    print('📤 Sincronizando log de nascimentos...');
    final db = await AppDb.getDb();
    final logs = await db.query('nascimento_log');

    final userMap = <int, int?>{};
    final payload = <Map<String, Object?>>[];
    for (final l in logs) {
      try {
        final localUserId = l['usuario_id'] as int?;
        if (localUserId == null) continue;

        userMap[localUserId] ??=
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        final serverUserId = userMap[localUserId];
        if (serverUserId == null) continue;

        payload.add({
          'id': l['id'],
          'animal_id': l['animal_id'],
          'cria': l['cria'],
          'mae': l['mae'],
          'sexo': l['sexo'],
          'raca': l['raca'],
          'peso': l['peso'],
          'pelagem': l['pelagem'],
          'data_nascimento': l['data_nascimento'],
          'fazenda': l['fazenda'],
          'lote': l['lote'],
          'pasto': l['pasto'],
          'observacao': l['observacao'],
          'foto1': l['foto1'],
          'foto2': l['foto2'],
          'foto3': l['foto3'],
          'location_cidade': l['location_cidade'],
          'location_bairro': l['location_bairro'],
          'location_latitude': l['location_latitude'],
          'location_longitude': l['location_longitude'],
          'usuario_id': serverUserId,
          'criado_em': l['criado_em'],
          'atualizado_em': l['atualizado_em'],
        });
      } catch (e) {
        print('✗ Erro ao preparar nascimento_log ${l['id']} para upload: $e');
      }
    }

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        await _supabase.from('nascimento_log').upsert(chunk, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de nascimento_log: $e');
      }
    }
  }

  static Future<void> sincronizarAnimalENascimentoLogLocal() async {
    print('🔁 Reconciliando tabelas locais: animal <-> nascimento_log...');
    final db = await AppDb.getDb();
    const reconcileTxnChunkSize = 200;

    final animais = await db.query('animal');
    final logs = await db.query('nascimento_log');

    final animaisPorId = <int, Map<String, Object?>>{};
    for (final a in animais) {
      final id = a['id'] as int?;
      if (id != null) animaisPorId[id] = a;
    }

    final logsPorId = <int, Map<String, Object?>>{};
    for (final l in logs) {
      final id = (l['animal_id'] as int?) ?? (l['id'] as int?);
      if (id != null) logsPorId[id] = l;
    }

    final allIds = <int>{...animaisPorId.keys, ...logsPorId.keys}.toList();

    for (var i = 0; i < allIds.length; i += reconcileTxnChunkSize) {
      final end = (i + reconcileTxnChunkSize < allIds.length)
          ? i + reconcileTxnChunkSize
          : allIds.length;
      final idChunk = allIds.sublist(i, end);

      await db.transaction((txn) async {
        for (final id in idChunk) {
          final animal = animaisPorId[id];
          final log = logsPorId[id];

          if (animal == null && log != null) {
            final criaLog = (log['cria']?.toString() ?? '').trim();
            if (criaLog.isNotEmpty) {
              final existentePorCria = await txn.query(
                'animal',
                columns: ['id'],
                where: 'cria = ?',
                whereArgs: [criaLog],
                limit: 1,
              );
              if (existentePorCria.isNotEmpty) {
                final idExistente = existentePorCria.first['id'];
                if (idExistente is int) {
                  print(
                      '⚠️ Reconciliar: log ${log['id']} com cria=$criaLog será relinkado para animal_id=$idExistente (evita duplicidade).');
                  await txn.update(
                    'nascimento_log',
                    {'animal_id': idExistente},
                    where: 'id = ?',
                    whereArgs: [log['id']],
                  );
                  continue;
                }
              }
            }

            final novoAnimal = {
              'id': id,
              'cria': log['cria'],
              'mae': log['mae'],
              'sexo': log['sexo'],
              'raca': log['raca'],
              'peso': log['peso'],
              'pelagem': log['pelagem'],
              'data_nascimento': log['data_nascimento'],
              'fazenda': log['fazenda'],
              'lote': log['lote'],
              'pasto': log['pasto'],
              'observacao': log['observacao'],
              'foto1': log['foto1'],
              'foto2': log['foto2'],
              'foto3': log['foto3'],
              'location_cidade': log['location_cidade'],
              'location_bairro': log['location_bairro'],
              'location_latitude': log['location_latitude'],
              'location_longitude': log['location_longitude'],
              'usuario_id': log['usuario_id'],
              'criado_em': log['criado_em'],
              'atualizado_em': log['atualizado_em'],
              'status': 'ATIVO',
            };
            await txn.insert('animal', novoAnimal,
                conflictAlgorithm: ConflictAlgorithm.replace);
            continue;
          }

          if (animal != null && log == null) {
            final novoLog = {
              'id': id,
              'animal_id': id,
              'cria': animal['cria'],
              'mae': animal['mae'],
              'sexo': animal['sexo'],
              'raca': animal['raca'],
              'peso': animal['peso'],
              'pelagem': animal['pelagem'],
              'data_nascimento': animal['data_nascimento'],
              'fazenda': animal['fazenda'],
              'lote': animal['lote'],
              'pasto': animal['pasto'],
              'observacao': animal['observacao'],
              'foto1': animal['foto1'],
              'foto2': animal['foto2'],
              'foto3': animal['foto3'],
              'location_cidade': animal['location_cidade'],
              'location_bairro': animal['location_bairro'],
              'location_latitude': animal['location_latitude'],
              'location_longitude': animal['location_longitude'],
              'usuario_id': animal['usuario_id'],
              'criado_em': animal['criado_em'],
              'atualizado_em': animal['atualizado_em'],
            };
            await txn.insert('nascimento_log', novoLog,
                conflictAlgorithm: ConflictAlgorithm.replace);
            continue;
          }

          if (animal == null || log == null) {
            continue;
          }

          final atualizadoAnimal = animal['atualizado_em'] as String?;
          final atualizadoLog = log['atualizado_em'] as String?;
          final logMaisRecente = atualizadoLog != null &&
              (atualizadoAnimal == null ||
                  atualizadoLog.compareTo(atualizadoAnimal) > 0);

          if (logMaisRecente) {
            final criaLog = (log['cria']?.toString() ?? '').trim();
            if (criaLog.isNotEmpty) {
              final existentePorCria = await txn.query(
                'animal',
                columns: ['id'],
                where: 'cria = ?',
                whereArgs: [criaLog],
                limit: 1,
              );
              if (existentePorCria.isNotEmpty) {
                final idExistente = existentePorCria.first['id'];
                if (idExistente is int && idExistente != id) {
                  print(
                      '⚠️ Reconciliar: conflito de cria=$criaLog entre id=$id e id=$idExistente. Relinkando log ${log['id']} para animal_id=$idExistente.');
                  await txn.update(
                    'nascimento_log',
                    {'animal_id': idExistente},
                    where: 'id = ?',
                    whereArgs: [log['id']],
                  );
                  continue;
                }
              }
            }

            await txn.update(
              'animal',
              {
                'cria': log['cria'],
                'mae': log['mae'],
                'sexo': log['sexo'],
                'raca': log['raca'],
                'peso': log['peso'],
                'pelagem': log['pelagem'],
                'data_nascimento': log['data_nascimento'],
                'fazenda': log['fazenda'],
                'lote': log['lote'],
                'pasto': log['pasto'],
                'observacao': log['observacao'],
                'foto1': log['foto1'],
                'foto2': log['foto2'],
                'foto3': log['foto3'],
                'location_cidade': log['location_cidade'],
                'location_bairro': log['location_bairro'],
                'location_latitude': log['location_latitude'],
                'location_longitude': log['location_longitude'],
                'usuario_id': log['usuario_id'],
                'criado_em': log['criado_em'],
                'atualizado_em': log['atualizado_em'],
                'status': animal['status'] ?? 'ATIVO',
              },
              where: 'id = ?',
              whereArgs: [id],
            );

            await txn.update(
              'nascimento_log',
              {'animal_id': id},
              where: 'id = ?',
              whereArgs: [id],
            );
          } else {
            await txn.update(
              'nascimento_log',
              {
                'animal_id': id,
                'cria': animal['cria'],
                'mae': animal['mae'],
                'sexo': animal['sexo'],
                'raca': animal['raca'],
                'peso': animal['peso'],
                'pelagem': animal['pelagem'],
                'data_nascimento': animal['data_nascimento'],
                'fazenda': animal['fazenda'],
                'lote': animal['lote'],
                'pasto': animal['pasto'],
                'observacao': animal['observacao'],
                'foto1': animal['foto1'],
                'foto2': animal['foto2'],
                'foto3': animal['foto3'],
                'location_cidade': animal['location_cidade'],
                'location_bairro': animal['location_bairro'],
                'location_latitude': animal['location_latitude'],
                'location_longitude': animal['location_longitude'],
                'usuario_id': animal['usuario_id'],
                'criado_em': animal['criado_em'],
                'atualizado_em': animal['atualizado_em'],
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      });
    }

    print('✅ Reconciliação local animal <-> nascimento_log concluída');
  }

  // Sincronizar mortes
  static Future<void> sincronizarMortes() async {
    print('📤 Sincronizando mortes...');
    final db = await AppDb.getDb();
    final mortes = await db.query('baixa_log');

    final userMap = <int, int?>{};
    final payload = <Map<String, Object?>>[];
    for (final m in mortes) {
      try {
        final localUserId = m['usuario_id'] as int?;
        if (localUserId == null) continue;

        userMap[localUserId] ??=
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        final serverUserId = userMap[localUserId];
        if (serverUserId == null) continue;

        payload.add({
          'id': m['id'],
          'nascimento_id': m['nascimento_id'],
          'tipo_baixa': m['tipo_baixa'],
          'data_morte': m['data_morte'],
          'fazenda': m['fazenda'],
          'foto1': m['foto1'],
          'foto2': m['foto2'],
          'foto3': m['foto3'],
          'audio': m['audio'],
          'descricao': m['descricao'],
          'location_cidade': m['location_cidade'],
          'location_bairro': m['location_bairro'],
          'location_latitude': m['location_latitude'],
          'location_longitude': m['location_longitude'],
          'usuario_id': serverUserId,
          'criado_em': m['criado_em'],
          'atualizado_em': m['atualizado_em'],
        });
      } catch (e) {
        print('✗ Erro ao preparar morte ${m['id']} para upload: $e');
      }
    }

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        await _supabase.from('baixa_log').upsert(chunk, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de mortes: $e');
      }
    }
  }

  // Sincronizar transferências
  static Future<void> sincronizarTransferencias() async {
    print('📤 Sincronizando transferências...');
    final db = await AppDb.getDb();
    final transferencias = await db.query('transferencia_log');

    final userMap = <int, int?>{};
    final payload = <Map<String, Object?>>[];
    for (final t in transferencias) {
      try {
        final localUserId = t['usuario_id'] as int?;
        if (localUserId == null) continue;

        userMap[localUserId] ??=
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        final serverUserId = userMap[localUserId];
        if (serverUserId == null) continue;

        payload.add({
          'id': t['id'],
          'animal_id': t['animal_id'],
          'fazenda_origem': t['fazenda_origem'],
          'fazenda_destino': t['fazenda_destino'],
          'lote_origem': t['lote_origem'],
          'lote_destino': t['lote_destino'],
          'pasto_origem': t['pasto_origem'],
          'pasto_destino': t['pasto_destino'],
          'is_inconsistency': t['is_inconsistency'],
          'usuario_id': serverUserId,
          'data_transferencia': t['data_transferencia'],
          'data_registro': t['data_registro'],
          'atualizado_em': t['atualizado_em'],
        });
      } catch (e) {
        print('✗ Erro ao preparar transferência ${t['id']} para upload: $e');
      }
    }

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        await _supabase
            .from('transferencia_log')
            .upsert(chunk, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de transferências: $e');
      }
    }
  }

  // Sincronizar solicitações
  static Future<void> sincronizarSolicitacoes() async {
    print('📤 Sincronizando solicitações...');
    final db = await AppDb.getDb();
    final solicitacoes = await db.query('solicitacao_faixa');

    final userMap = <int, int?>{};
    final payload = <Map<String, Object?>>[];
    for (final s in solicitacoes) {
      try {
        final localUserId = s['usuario_id'] as int?;
        if (localUserId == null) continue;

        userMap[localUserId] ??=
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        final serverUserId = userMap[localUserId];
        if (serverUserId == null) continue;

        payload.add({
          'id': s['id'],
          'usuario_id': serverUserId,
          'usuario_nome': s['usuario_nome'],
          'prefixo': s['prefixo'],
          'inicio_atual': s['inicio_atual'],
          'max_atual': s['max_atual'],
          'restantes': s['restantes'],
          'solicitado_em': s['solicitado_em'],
          'status': s['status'],
          'atualizado_em': s['atualizado_em'],
        });
      } catch (e) {
        print('✗ Erro ao preparar solicitação ${s['id']} para upload: $e');
      }
    }

    for (final chunk in _splitInChunks(payload, _chunkSize)) {
      try {
        await _supabase
            .from('solicitacao_faixa')
            .upsert(chunk, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar chunk de solicitações: $e');
      }
    }
  }

  // Verificar conexão com Supabase
  static Future<bool> verificarConexao() async {
    try {
      await _supabase.from('usuario').select('id').limit(1);
      return true;
    } catch (e) {
      print('❌ Sem conexão com Supabase: $e');
      return false;
    }
  }

  // ============================================
  // MÉTODOS DE DOWNLOAD (nuvem → local)
  // ============================================

  // Baixar usuários da nuvem
  static Future<void> baixarUsuarios() async {
    print('📥 Baixando usuários da nuvem...');
    try {
      final db = await AppDb.getDb();
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk = await _downloadChunk('usuario', 'atualizado_em', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'USUARIOS',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final u in chunk) {
            try {
              final local = await txn
                  .query('usuario', where: 'id = ?', whereArgs: [u['id']]);

              final dados = {
                'id': u['id'],
                'nome': u['nome'],
                'login': u['login'],
                'senha_hash': u['senha_hash'],
                'ativo': u['ativo'] == true ? 1 : 0,
                'cria_prefixo': u['cria_prefixo'],
                'cria_inicio': u['cria_inicio'],
                'cria_max': u['cria_max'],
                'is_admin': u['is_admin'] == true ? 1 : 0,
                'criado_em': u['criado_em'],
                'atualizado_em': u['atualizado_em'],
              };

              if (local.isEmpty) {
                await txn.insert('usuario', dados);
              } else {
                final timestampLocal =
                    (local.first['atualizado_em'] as String?) ??
                        (local.first['criado_em'] as String?);
                final timestampRemoto = u['atualizado_em'] as String?;

                if (_isRemoteMoreRecent(
                    remoteTimestamp: timestampRemoto,
                    localTimestamp: timestampLocal)) {
                  await txn.update('usuario', dados,
                      where: 'id = ?', whereArgs: [u['id']]);
                }
              }
            } catch (e) {
              print('✗ Erro ao processar usuário ${u['id']}: $e');
            }
          }
        });
        _logChunkSaved(
          modulo: 'USUARIOS',
          chunkNumber: chunkNumber,
          size: chunk.length,
        );

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print('✅ Download de usuários concluído');
    } catch (e) {
      print('❌ Erro ao baixar usuários: $e');
    }
  }

  // Baixar animais da nuvem
  static Future<void> baixarAnimais() async {
    print('📥 Baixando animais da nuvem...');
    try {
      final db = await AppDb.getDb();
      var inseridos = 0;
      var atualizados = 0;
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk = await _downloadChunk('animal', 'atualizado_em', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'ANIMAIS',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final writeChunk
              in _splitInChunks(chunk, _localWriteChunkSize)) {
            final ids = writeChunk
                .map((n) => n['id'])
                .whereType<int>()
                .toSet()
                .toList();
            final crias = writeChunk
                .map((n) => (n['cria']?.toString() ?? '').trim())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList();

            final localById = <int, Map<String, Object?>>{};
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              final rows = await txn.query(
                'animal',
                where: 'id IN ($placeholders)',
                whereArgs: ids,
              );
              for (final row in rows) {
                final id = row['id'];
                if (id is int) localById[id] = row;
              }
            }

            final localByCria = <String, Map<String, Object?>>{};
            if (crias.isNotEmpty) {
              final placeholders = List.filled(crias.length, '?').join(',');
              final rows = await txn.query(
                'animal',
                where: 'cria IN ($placeholders)',
                whereArgs: crias,
              );
              for (final row in rows) {
                final cria = (row['cria']?.toString() ?? '').trim();
                if (cria.isNotEmpty && !localByCria.containsKey(cria)) {
                  localByCria[cria] = row;
                }
              }
            }

            final batch = txn.batch();
            for (final n in writeChunk) {
              try {
                final remoteId = n['id'];
                if (remoteId is! int) continue;
                final remoteCria = (n['cria']?.toString() ?? '').trim();

                final local = localById[remoteId];
                final localByCriaRow =
                    remoteCria.isEmpty ? null : localByCria[remoteCria];

                final dados = {
                  'id': remoteId,
                  'cria': n['cria'],
                  'mae': n['mae'],
                  'sexo': n['sexo'],
                  'raca': n['raca'],
                  'peso': n['peso'],
                  'pelagem': n['pelagem'],
                  'data_nascimento': n['data_nascimento'],
                  'fazenda': n['fazenda'],
                  'lote': n['lote'],
                  'pasto': n['pasto'],
                  'observacao': n['observacao'],
                  'foto1': n['foto1'],
                  'foto2': n['foto2'],
                  'foto3': n['foto3'],
                  'location_cidade': n['location_cidade'],
                  'location_bairro': n['location_bairro'],
                  'location_latitude': n['location_latitude'],
                  'location_longitude': n['location_longitude'],
                  'usuario_id': n['usuario_id'],
                  'criado_em': n['criado_em'],
                  'atualizado_em': n['atualizado_em'],
                  'status': (n['status'] ??
                      ((n['morto'] == true) ? 'MORTO' : 'ATIVO')),
                };

                final dadosSemId = Map<String, Object?>.from(dados)
                  ..remove('id');
                final hasById = local != null;
                final hasByCria = localByCriaRow != null;
                final byIdPk = hasById ? local['id'] : null;
                final byCriaPk = hasByCria ? localByCriaRow['id'] : null;
                final conflitoIdVsCria =
                    hasById && hasByCria && byIdPk != byCriaPk;

                if (conflitoIdVsCria) {
                  final timestampLocal =
                      (localByCriaRow['atualizado_em'] as String?) ??
                          (localByCriaRow['criado_em'] as String?);
                  final timestampRemoto = n['atualizado_em'] as String?;
                  if (_isRemoteMoreRecent(
                    remoteTimestamp: timestampRemoto,
                    localTimestamp: timestampLocal,
                  )) {
                    batch.update(
                      'animal',
                      dadosSemId,
                      where: 'id = ?',
                      whereArgs: [byCriaPk],
                    );
                    atualizados++;
                  }
                  continue;
                }

                if (!hasById) {
                  if (hasByCria) {
                    final timestampLocal =
                        (localByCriaRow['atualizado_em'] as String?) ??
                            (localByCriaRow['criado_em'] as String?);
                    final timestampRemoto = n['atualizado_em'] as String?;
                    if (_isRemoteMoreRecent(
                      remoteTimestamp: timestampRemoto,
                      localTimestamp: timestampLocal,
                    )) {
                      batch.update(
                        'animal',
                        dadosSemId,
                        where: 'id = ?',
                        whereArgs: [byCriaPk],
                      );
                      atualizados++;
                    }
                    continue;
                  }

                  batch.insert(
                    'animal',
                    dados,
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                  inseridos++;
                } else {
                  final timestampLocal = (local['atualizado_em'] as String?) ??
                      (local['criado_em'] as String?);
                  final timestampRemoto = n['atualizado_em'] as String?;
                  if (_isRemoteMoreRecent(
                    remoteTimestamp: timestampRemoto,
                    localTimestamp: timestampLocal,
                  )) {
                    batch.update(
                      'animal',
                      dadosSemId,
                      where: 'id = ?',
                      whereArgs: [remoteId],
                    );
                    atualizados++;
                  }
                }
              } catch (e) {
                print('✗ Erro ao processar animal ${n['id']}: $e');
              }
            }

            await batch.commit(noResult: true, continueOnError: true);
            _logChunkSaved(
              modulo: 'ANIMAIS',
              chunkNumber: chunkNumber,
              size: writeChunk.length,
            );
          }
        });

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print(
          '✅ Download de animais concluído (inseridos: $inseridos, atualizados: $atualizados)');
    } catch (e) {
      print('❌ Erro ao baixar animais: $e');
    }
  }

  static Future<void> baixarNascimentosLog() async {
    print('📥 Baixando log de nascimentos da nuvem...');
    try {
      final db = await AppDb.getDb();
      var inseridos = 0;
      var atualizados = 0;
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk =
            await _downloadChunk('nascimento_log', 'atualizado_em', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'NASCIMENTOS_LOG',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final writeChunk
              in _splitInChunks(chunk, _localWriteChunkSize)) {
            final ids = writeChunk
                .map((l) => l['id'])
                .whereType<int>()
                .toSet()
                .toList();

            final localById = <int, Map<String, Object?>>{};
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              final locals = await txn.query(
                'nascimento_log',
                where: 'id IN ($placeholders)',
                whereArgs: ids,
              );
              for (final row in locals) {
                final id = row['id'];
                if (id is int) localById[id] = row;
              }
            }

            final batch = txn.batch();
            for (final l in writeChunk) {
              try {
                final id = l['id'];
                if (id is! int) continue;
                final local = localById[id];

                final dados = {
                  'id': id,
                  'animal_id': l['animal_id'],
                  'cria': l['cria'],
                  'mae': l['mae'],
                  'sexo': l['sexo'],
                  'raca': l['raca'],
                  'peso': l['peso'],
                  'pelagem': l['pelagem'],
                  'data_nascimento': l['data_nascimento'],
                  'fazenda': l['fazenda'],
                  'lote': l['lote'],
                  'pasto': l['pasto'],
                  'observacao': l['observacao'],
                  'foto1': l['foto1'],
                  'foto2': l['foto2'],
                  'foto3': l['foto3'],
                  'location_cidade': l['location_cidade'],
                  'location_bairro': l['location_bairro'],
                  'location_latitude': l['location_latitude'],
                  'location_longitude': l['location_longitude'],
                  'usuario_id': l['usuario_id'],
                  'criado_em': l['criado_em'],
                  'atualizado_em': l['atualizado_em'],
                };

                if (local == null) {
                  batch.insert('nascimento_log', dados,
                      conflictAlgorithm: ConflictAlgorithm.replace);
                  inseridos++;
                } else {
                  final timestampLocal = (local['atualizado_em'] as String?) ??
                      (local['criado_em'] as String?);
                  final timestampRemoto = l['atualizado_em'] as String?;

                  if (_isRemoteMoreRecent(
                      remoteTimestamp: timestampRemoto,
                      localTimestamp: timestampLocal)) {
                    batch.update('nascimento_log', dados,
                        where: 'id = ?', whereArgs: [id]);
                    atualizados++;
                  }
                }
              } catch (e) {
                print('✗ Erro ao processar nascimento_log ${l['id']}: $e');
              }
            }

            await batch.commit(noResult: true, continueOnError: true);
            _logChunkSaved(
              modulo: 'NASCIMENTOS_LOG',
              chunkNumber: chunkNumber,
              size: writeChunk.length,
            );
          }
        });

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print(
          '✅ Download de log de nascimentos concluído (inseridos: $inseridos, atualizados: $atualizados)');
    } catch (e) {
      print('❌ Erro ao baixar log de nascimentos: $e');
    }
  }

  // Baixar mortes da nuvem
  static Future<void> baixarMortes() async {
    print('📥 Baixando mortes da nuvem...');
    try {
      final db = await AppDb.getDb();
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk =
            await _downloadChunk('baixa_log', 'atualizado_em', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'BAIXAS',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final writeChunk
              in _splitInChunks(chunk, _localWriteChunkSize)) {
            final ids = writeChunk
                .map((m) => m['id'])
                .whereType<int>()
                .toSet()
                .toList();

            final localById = <int, Map<String, Object?>>{};
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              final locals = await txn.query(
                'baixa_log',
                where: 'id IN ($placeholders)',
                whereArgs: ids,
              );
              for (final row in locals) {
                final id = row['id'];
                if (id is int) localById[id] = row;
              }
            }

            final batch = txn.batch();
            for (final m in writeChunk) {
              try {
                final id = m['id'];
                if (id is! int) continue;
                final local = localById[id];
                final tipoBaixa = ((m['tipo_baixa'] as String?) ?? 'MORTE')
                    .trim()
                    .toUpperCase();
                final statusAnimal = tipoBaixa == 'ABATE' ? 'ABATIDO' : 'MORTO';

                final dados = {
                  'id': id,
                  'nascimento_id': m['nascimento_id'],
                  'tipo_baixa': tipoBaixa,
                  'data_morte': m['data_morte'],
                  'fazenda': m['fazenda'],
                  'foto1': m['foto1'],
                  'foto2': m['foto2'],
                  'foto3': m['foto3'],
                  'audio': m['audio'],
                  'descricao': m['descricao'],
                  'location_cidade': m['location_cidade'],
                  'location_bairro': m['location_bairro'],
                  'location_latitude': m['location_latitude'],
                  'location_longitude': m['location_longitude'],
                  'usuario_id': m['usuario_id'],
                  'criado_em': m['criado_em'],
                  'atualizado_em': m['atualizado_em'],
                };

                if (local == null) {
                  batch.insert('baixa_log', dados,
                      conflictAlgorithm: ConflictAlgorithm.replace);
                  batch.update(
                    'animal',
                    {
                      'status': statusAnimal,
                      'atualizado_em': m['atualizado_em'],
                    },
                    where: 'id = ?',
                    whereArgs: [m['nascimento_id']],
                  );
                } else {
                  final timestampLocal = (local['atualizado_em'] as String?) ??
                      (local['criado_em'] as String?);
                  final timestampRemoto = m['atualizado_em'] as String?;

                  if (_isRemoteMoreRecent(
                      remoteTimestamp: timestampRemoto,
                      localTimestamp: timestampLocal)) {
                    batch.update('baixa_log', dados,
                        where: 'id = ?', whereArgs: [id]);
                    batch.update(
                      'animal',
                      {
                        'status': statusAnimal,
                        'atualizado_em': m['atualizado_em'],
                      },
                      where: 'id = ?',
                      whereArgs: [m['nascimento_id']],
                    );
                  }
                }
              } catch (e) {
                print('✗ Erro ao processar morte ${m['id']}: $e');
              }
            }

            await batch.commit(noResult: true, continueOnError: true);
            _logChunkSaved(
              modulo: 'BAIXAS',
              chunkNumber: chunkNumber,
              size: writeChunk.length,
            );
          }
        });

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print('✅ Download de mortes concluído');
    } catch (e) {
      print('❌ Erro ao baixar mortes: $e');
    }
  }

  // Baixar transferências da nuvem
  static Future<void> baixarTransferencias() async {
    print('📥 Baixando transferências da nuvem...');
    try {
      final db = await AppDb.getDb();
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk =
            await _downloadChunk('transferencia_log', 'data_registro', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'TRANSFERENCIAS',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final writeChunk
              in _splitInChunks(chunk, _localWriteChunkSize)) {
            final ids = writeChunk
                .map((t) => t['id'])
                .whereType<int>()
                .toSet()
                .toList();

            final existingIds = <int>{};
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              final rows = await txn.query(
                'transferencia_log',
                columns: ['id'],
                where: 'id IN ($placeholders)',
                whereArgs: ids,
              );
              for (final row in rows) {
                final id = row['id'];
                if (id is int) existingIds.add(id);
              }
            }

            final batch = txn.batch();
            for (final t in writeChunk) {
              try {
                final id = t['id'];
                if (id is! int) continue;
                final dados = {
                  'id': id,
                  'animal_id': t['animal_id'],
                  'fazenda_origem': t['fazenda_origem'],
                  'fazenda_destino': t['fazenda_destino'],
                  'lote_origem': t['lote_origem'],
                  'lote_destino': t['lote_destino'],
                  'pasto_origem': t['pasto_origem'],
                  'pasto_destino': t['pasto_destino'],
                  'is_inconsistency': t['is_inconsistency'],
                  'usuario_id': t['usuario_id'],
                  'data_transferencia': t['data_transferencia'],
                  'data_registro': t['data_registro'],
                  'atualizado_em': t['atualizado_em'],
                };

                if (existingIds.contains(id)) {
                  batch.update('transferencia_log', dados,
                      where: 'id = ?', whereArgs: [id]);
                } else {
                  batch.insert('transferencia_log', dados,
                      conflictAlgorithm: ConflictAlgorithm.replace);
                }
              } catch (e) {
                print('✗ Erro ao processar transferencia ${t['id']}: $e');
              }
            }

            await batch.commit(noResult: true, continueOnError: true);
            _logChunkSaved(
              modulo: 'TRANSFERENCIAS',
              chunkNumber: chunkNumber,
              size: writeChunk.length,
            );
          }
        });

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print('✅ Download de transferências concluído');
    } catch (e) {
      print('❌ Erro ao baixar transferências: $e');
    }
  }

  // Baixar solicitações da nuvem
  static Future<void> baixarSolicitacoes() async {
    print('📥 Baixando solicitações da nuvem...');
    try {
      final db = await AppDb.getDb();
      var offset = 0;
      while (true) {
        final chunkNumber = (offset ~/ _chunkSize) + 1;
        final chunk =
            await _downloadChunk('solicitacao_faixa', 'solicitado_em', offset);
        if (chunk.isEmpty) break;
        _logChunkFetched(
          modulo: 'SOLICITACOES',
          chunkNumber: chunkNumber,
          offset: offset,
          size: chunk.length,
        );

        await db.transaction((txn) async {
          for (final writeChunk
              in _splitInChunks(chunk, _localWriteChunkSize)) {
            final ids = writeChunk
                .map((s) => s['id'])
                .whereType<int>()
                .toSet()
                .toList();

            final localById = <int, Map<String, Object?>>{};
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              final locals = await txn.query(
                'solicitacao_faixa',
                where: 'id IN ($placeholders)',
                whereArgs: ids,
              );
              for (final row in locals) {
                final id = row['id'];
                if (id is int) localById[id] = row;
              }
            }

            final batch = txn.batch();
            for (final s in writeChunk) {
              try {
                final id = s['id'];
                if (id is! int) continue;
                final local = localById[id];

                final dados = {
                  'id': id,
                  'usuario_id': s['usuario_id'],
                  'usuario_nome': s['usuario_nome'],
                  'prefixo': s['prefixo'],
                  'inicio_atual': s['inicio_atual'],
                  'max_atual': s['max_atual'],
                  'restantes': s['restantes'],
                  'solicitado_em': s['solicitado_em'],
                  'status': s['status'],
                  'atualizado_em': s['atualizado_em'],
                };

                if (local == null) {
                  batch.insert('solicitacao_faixa', dados,
                      conflictAlgorithm: ConflictAlgorithm.replace);
                } else {
                  final timestampLocal = (local['atualizado_em'] as String?) ??
                      (local['solicitado_em'] as String?);
                  final timestampRemoto = s['atualizado_em'] as String?;

                  if (_isRemoteMoreRecent(
                      remoteTimestamp: timestampRemoto,
                      localTimestamp: timestampLocal)) {
                    batch.update('solicitacao_faixa', dados,
                        where: 'id = ?', whereArgs: [id]);
                  }
                }
              } catch (e) {
                print('✗ Erro ao processar solicitação ${s['id']}: $e');
              }
            }

            await batch.commit(noResult: true, continueOnError: true);
            _logChunkSaved(
              modulo: 'SOLICITACOES',
              chunkNumber: chunkNumber,
              size: writeChunk.length,
            );
          }
        });

        if (chunk.length < _chunkSize) break;
        offset += _chunkSize;
      }
      print('✅ Download de solicitações concluído');
    } catch (e) {
      print('❌ Erro ao baixar solicitações: $e');
    }
  }

  // ============================================
  // CONTROLE DE VERSÃO DE SINCRONIZAÇÃO
  // ============================================

  static const String _localSyncVersionKey = 'local_sync_version';

  static Future<bool> _verificarSyncVersionEReiniciar() async {
    final remoteVersion = await _buscarSyncVersionRemoto();
    final prefs = await SharedPreferences.getInstance();
    var localVersion = prefs.getString(_localSyncVersionKey);

    // Se é a primeira sincronização (localVersion é null), inicializar com a versão remota
    if (localVersion == null) {
      print(
          '✓ Primeira sincronização - inicializando sync_version local com: $remoteVersion');
      await prefs.setString(_localSyncVersionKey, remoteVersion);
      return false; // Não é reset, apenas inicialização
    }

    if (localVersion == remoteVersion) {
      return false;
    }

    print(
        '⚠️ Versão de sync mudou ($localVersion → $remoteVersion). Resetando dados locais...');

    await _limparDadosLocais();

    await baixarUsuarios();
    await baixarAnimais();
    await baixarNascimentosLog();
    await baixarTransferencias();
    await baixarMortes();
    await baixarSolicitacoes();

    await prefs.setString(_localSyncVersionKey, remoteVersion);
    return true;
  }

  static Future<String> _buscarSyncVersionRemoto() async {
    final response = await _supabase
        .from('app_config')
        .select('value')
        .eq('key', 'sync_version')
        .maybeSingle();

    final value = response?['value']?.toString();
    if (value == null || value.isEmpty) {
      // Fallback seguro para ambientes sem app_config/sync_version.
      print(
          '⚠️ sync_version não encontrado em app_config. Usando versão padrão "1".');
      return '1';
    }
    return value;
  }

  static Future<void> _limparDadosLocais() async {
    final db = await AppDb.getDb();
    await db.transaction((txn) async {
      await txn.delete('baixa_log');
      await txn.delete('nascimento_log');
      await txn.delete('animal');
      await txn.delete('transferencia_log');
      await txn.delete('solicitacao_faixa');
      await txn.delete('usuario');
    });
  }

  static bool _isRemoteMoreRecent({
    required String? remoteTimestamp,
    required String? localTimestamp,
  }) {
    if (remoteTimestamp == null || remoteTimestamp.trim().isEmpty) {
      if (_verboseSyncDecisionLogs) {
        print(
            '🧭 Decisão sync: remoto sem timestamp válido -> NÃO sobrescrever local');
      }
      return false;
    }
    if (localTimestamp == null || localTimestamp.trim().isEmpty) {
      if (_verboseSyncDecisionLogs) {
        print(
            '🧭 Decisão sync: local sem timestamp válido -> remoto vence e pode sobrescrever');
      }
      return true;
    }

    final remoteDt = DateTime.tryParse(remoteTimestamp)?.toUtc();
    final localDt = DateTime.tryParse(localTimestamp)?.toUtc();

    if (remoteDt != null && localDt != null) {
      final isAfter = remoteDt.isAfter(localDt);
      if (_verboseSyncDecisionLogs) {
        print(
            '🧭 Decisão sync DateTime: remoto=$remoteDt local=$localDt -> remotoMaisRecente=$isAfter');
      }
      return isAfter;
    }

    final fallback = remoteTimestamp.compareTo(localTimestamp) > 0;
    if (_verboseSyncDecisionLogs) {
      print(
          '🧭 Decisão sync fallback string: remoto=$remoteTimestamp local=$localTimestamp -> remotoMaisRecente=$fallback');
    }
    return fallback;
  }

  static Future<void> _reconciliarUsuarioIdLocal({
    required int localId,
    required int serverId,
    required String login,
  }) async {
    if (localId == serverId) return;

    final db = await AppDb.getDb();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'usuario',
        where: 'id = ?',
        whereArgs: [serverId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.update(
          'usuario',
          {'id': serverId},
          where: 'id = ?',
          whereArgs: [localId],
        );
      } else {
        final existingLogin = existing.first['login'] as String?;
        if (existingLogin == login) {
          await txn.delete('usuario', where: 'id = ?', whereArgs: [localId]);
        } else {
          print(
              '⚠️ Conflito de ID local ($localId → $serverId) com login diferente: $existingLogin');
          await txn.delete('usuario', where: 'id = ?', whereArgs: [localId]);
        }
      }

      await txn.update('animal', {'usuario_id': serverId},
          where: 'usuario_id = ?', whereArgs: [localId]);
      await txn.update('nascimento_log', {'usuario_id': serverId},
          where: 'usuario_id = ?', whereArgs: [localId]);
      await txn.update('baixa_log', {'usuario_id': serverId},
          where: 'usuario_id = ?', whereArgs: [localId]);
      await txn.update('transferencia_log', {'usuario_id': serverId},
          where: 'usuario_id = ?', whereArgs: [localId]);
      await txn.update('solicitacao_faixa', {'usuario_id': serverId},
          where: 'usuario_id = ?', whereArgs: [localId]);
    });

    if (AppSession.usuarioId == localId) {
      AppSession.usuarioId = serverId;
    }
  }

  static Future<int?> _obterOuCriarUsuarioServidorPorId(int localUserId) async {
    final db = await AppDb.getDb();
    var currentLocalId = localUserId;
    var local = await db.query(
      'usuario',
      where: 'id = ?',
      whereArgs: [currentLocalId],
      limit: 1,
    );

    if (local.isEmpty && AppSession.usuarioId != null) {
      final fallbackId = AppSession.usuarioId!;
      final fallback = await db.query(
        'usuario',
        where: 'id = ?',
        whereArgs: [fallbackId],
        limit: 1,
      );

      if (fallback.isNotEmpty) {
        if (fallbackId != currentLocalId) {
          await db.transaction((txn) async {
            await txn.update('animal', {'usuario_id': fallbackId},
                where: 'usuario_id = ?', whereArgs: [currentLocalId]);
            await txn.update('nascimento_log', {'usuario_id': fallbackId},
                where: 'usuario_id = ?', whereArgs: [currentLocalId]);
            await txn.update('baixa_log', {'usuario_id': fallbackId},
                where: 'usuario_id = ?', whereArgs: [currentLocalId]);
            await txn.update('transferencia_log', {'usuario_id': fallbackId},
                where: 'usuario_id = ?', whereArgs: [currentLocalId]);
            await txn.update('solicitacao_faixa', {'usuario_id': fallbackId},
                where: 'usuario_id = ?', whereArgs: [currentLocalId]);
          });
          currentLocalId = fallbackId;
        }
        local = fallback;
      }
    }

    if (local.isEmpty) {
      print('✗ Usuário local $localUserId não encontrado');
      return null;
    }

    final u = local.first;
    final login = u['login'] as String;

    try {
      final dados = {
        'nome': u['nome'],
        'login': login,
        'senha_hash': u['senha_hash'],
        'ativo': (u['ativo'] as int) == 1,
        'cria_prefixo': u['cria_prefixo'],
        'cria_inicio': u['cria_inicio'],
        'cria_max': u['cria_max'],
        'is_admin': (u['is_admin'] as int) == 1,
        'criado_em': u['criado_em'],
        'atualizado_em': u['atualizado_em'],
      };

      final response = await _supabase
          .from('usuario')
          .upsert(dados, onConflict: 'login')
          .select('id')
          .single();

      final serverId = response['id'] as int;

      await _reconciliarUsuarioIdLocal(
        localId: currentLocalId,
        serverId: serverId,
        login: login,
      );

      return serverId;
    } catch (e) {
      print('✗ Erro ao garantir usuário no servidor ($login): $e');
      return null;
    }
  }
}
