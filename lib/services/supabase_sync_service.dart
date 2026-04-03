import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_db.dart';
import '../session/app_session.dart';

class SupabaseSyncService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Método principal de sincronização (bidirecional)
  static Future<void> sincronizar() async {
    print('🔄 Iniciando sincronização com Supabase...');
    try {
      final resetFeito = await _verificarSyncVersionEReiniciar();
      if (resetFeito) {
        print('✅ Sincronização completa (reset local aplicado)');
        return;
      }

      // Download: nuvem → local (primeiro)
      await baixarUsuarios();
      await baixarAnimais();
      await baixarNascimentosLog();
      await sincronizarAnimalENascimentoLogLocal();
      await baixarTransferencias();
      await baixarMortes();
      await baixarSolicitacoes();

      // Upload: local → nuvem (depois)
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

  // Sincronizar usuários
  static Future<void> sincronizarUsuarios() async {
    print('📤 Sincronizando usuários...');
    final db = await AppDb.getDb();
    final usuarios = await db.query('usuario');

    for (final u in usuarios) {
      try {
        final localId = u['id'] as int;
        final login = u['login'] as String;
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

        // Upsert pelo login para garantir consistência entre dispositivos
        final response = await _supabase
            .from('usuario')
            .upsert(dados, onConflict: 'login')
            .select('id')
            .single();

        final serverId = response['id'] as int;
        await _reconciliarUsuarioIdLocal(
          localId: localId,
          serverId: serverId,
          login: login,
        );

        print('✓ Usuário $login sincronizado (id servidor: $serverId)');
      } catch (e) {
        print('✗ Erro ao sincronizar usuário ${u['id']}: $e');
      }
    }
  }

  // Sincronizar animais
  static Future<void> sincronizarAnimais() async {
    print('📤 Sincronizando animais...');
    final db = await AppDb.getDb();
    final nascimentos = await db.query('animal');

    for (final n in nascimentos) {
      try {
        final localUserId = n['usuario_id'] as int?;
        if (localUserId == null) {
          print('✗ Animal ${n['id']} sem usuario_id local');
          continue;
        }

        final serverUserId =
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        if (serverUserId == null) {
          print('✗ Animal ${n['id']} sem usuário válido no servidor');
          continue;
        }

        final dados = {
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
        };

        await _supabase.from('animal').upsert(dados, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar animal ${n['id']}: $e');
      }
    }
  }

  static Future<void> sincronizarNascimentosLog() async {
    print('📤 Sincronizando log de nascimentos...');
    final db = await AppDb.getDb();
    final logs = await db.query('nascimento_log');

    for (final l in logs) {
      try {
        final localUserId = l['usuario_id'] as int?;
        if (localUserId == null) continue;

        final serverUserId =
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        if (serverUserId == null) continue;

        final dados = {
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
        };

        await _supabase.from('nascimento_log').upsert(dados, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar nascimento_log ${l['id']}: $e');
      }
    }
  }

  static Future<void> sincronizarAnimalENascimentoLogLocal() async {
    print('🔁 Reconciliando tabelas locais: animal <-> nascimento_log...');
    final db = await AppDb.getDb();

    await db.transaction((txn) async {
      final animais = await txn.query('animal');
      final logs = await txn.query('nascimento_log');

      final animaisPorId = <int, Map<String, Object?>>{};
      for (final a in animais) {
        final id = a['id'] as int?;
        if (id != null) animaisPorId[id] = a;
      }

      final logsPorId = <int, Map<String, Object?>>{};
      for (final l in logs) {
        final id = l['id'] as int?;
        if (id != null) logsPorId[id] = l;
      }

      final allIds = <int>{...animaisPorId.keys, ...logsPorId.keys};

      for (final id in allIds) {
        final animal = animaisPorId[id];
        final log = logsPorId[id];

        if (animal == null && log != null) {
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

    print('✅ Reconciliação local animal <-> nascimento_log concluída');
  }

  // Sincronizar mortes
  static Future<void> sincronizarMortes() async {
    print('📤 Sincronizando mortes...');
    final db = await AppDb.getDb();
    final mortes = await db.query('morte_log');

    for (final m in mortes) {
      try {
        final localUserId = m['usuario_id'] as int?;
        if (localUserId == null) {
          print('✗ Morte ${m['id']} sem usuario_id local');
          continue;
        }

        final serverUserId =
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        if (serverUserId == null) {
          print('✗ Morte ${m['id']} sem usuário válido no servidor');
          continue;
        }

        final dados = {
          'id': m['id'],
          'nascimento_id': m['nascimento_id'],
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
        };

        await _supabase.from('morte_log').upsert(dados, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar morte ${m['id']}: $e');
      }
    }
  }

  // Sincronizar transferências
  static Future<void> sincronizarTransferencias() async {
    print('📤 Sincronizando transferências...');
    final db = await AppDb.getDb();
    final transferencias = await db.query('transferencia_log');

    for (final t in transferencias) {
      try {
        final dados = {
          'id': t['id'],
          'animal_id': t['animal_id'],
          'fazenda_origem': t['fazenda_origem'],
          'fazenda_destino': t['fazenda_destino'],
          'lote_origem': t['lote_origem'],
          'lote_destino': t['lote_destino'],
          'pasto_origem': t['pasto_origem'],
          'pasto_destino': t['pasto_destino'],
          'usuario_id': t['usuario_id'],
          'data_transferencia': t['data_transferencia'],
          'data_registro': t['data_registro'],
          'atualizado_em': t['atualizado_em'],
        };

        await _supabase
            .from('transferencia_log')
            .upsert(dados, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar transferencia ${t['id']}: $e');
      }
    }
  }

  // Sincronizar solicitações
  static Future<void> sincronizarSolicitacoes() async {
    print('📤 Sincronizando solicitações...');
    final db = await AppDb.getDb();
    final solicitacoes = await db.query('solicitacao_faixa');

    for (final s in solicitacoes) {
      try {
        final localUserId = s['usuario_id'] as int?;
        if (localUserId == null) {
          print('✗ Solicitação ${s['id']} sem usuario_id local');
          continue;
        }

        final serverUserId =
            await _obterOuCriarUsuarioServidorPorId(localUserId);
        if (serverUserId == null) {
          print('✗ Solicitação ${s['id']} sem usuário válido no servidor');
          continue;
        }

        final dados = {
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
        };

        await _supabase
            .from('solicitacao_faixa')
            .upsert(dados, onConflict: 'id');
      } catch (e) {
        print('✗ Erro ao sincronizar solicitação ${s['id']}: $e');
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
      final response = await _supabase
          .from('usuario')
          .select()
          .order('atualizado_em', ascending: false);

      final usuarios = response as List<dynamic>;

      for (final u in usuarios) {
        try {
          // Verifica se usuário existe localmente
          final local =
              await db.query('usuario', where: 'id = ?', whereArgs: [u['id']]);

          final dados = {
            'id': u['id'],
            'nome': u['nome'],
            'login': u['login'],
            'senha_hash': u['senha_hash'],
            'ativo': u['ativo'] ? 1 : 0,
            'cria_prefixo': u['cria_prefixo'],
            'cria_inicio': u['cria_inicio'],
            'cria_max': u['cria_max'],
            'is_admin': u['is_admin'] ? 1 : 0,
            'criado_em': u['criado_em'],
            'atualizado_em': u['atualizado_em'],
          };

          if (local.isEmpty) {
            await db.insert('usuario', dados);
            print('✓ Usuário ${u['login']} inserido do servidor');
          } else {
            // Compara timestamp para ver qual é mais recente
            final timestampLocal = (local.first['atualizado_em'] as String?) ??
                (local.first['criado_em'] as String?);
            final timestampRemoto = u['atualizado_em'] as String?;

            // Atualiza se o remoto for mais recente ou se não houver timestamp
            if (timestampRemoto != null &&
                (timestampLocal == null ||
                    timestampRemoto.compareTo(timestampLocal) > 0)) {
              await db.update('usuario', dados,
                  where: 'id = ?', whereArgs: [u['id']]);
              print('✓ Usuário ${u['login']} atualizado do servidor');
            }
          }
        } catch (e) {
          print('✗ Erro ao processar usuário ${u['id']}: $e');
        }
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
      final response = await _supabase
          .from('animal')
          .select()
          .order('atualizado_em', ascending: false);

      final nascimentos = response as List<dynamic>;
      var inseridos = 0;
      var atualizados = 0;

      for (final n in nascimentos) {
        try {
          final local =
              await db.query('animal', where: 'id = ?', whereArgs: [n['id']]);

          final dados = {
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
            'usuario_id': n['usuario_id'],
            'criado_em': n['criado_em'],
            'atualizado_em': n['atualizado_em'],
            'status':
                (n['status'] ?? ((n['morto'] == true) ? 'MORTO' : 'ATIVO')),
          };

          if (local.isEmpty) {
            await db.insert('animal', dados);
            inseridos++;
            print('✓ Animal ${n['cria']} inserido do servidor');
          } else {
            await db
                .update('animal', dados, where: 'id = ?', whereArgs: [n['id']]);
            atualizados++;
            print('✓ Animal ${n['cria']} atualizado do servidor');
          }
        } catch (e) {
          print('✗ Erro ao processar animal ${n['id']}: $e');
        }
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
      final response = await _supabase
          .from('nascimento_log')
          .select()
          .order('atualizado_em', ascending: false);

      final logs = response as List<dynamic>;
      var inseridos = 0;
      var atualizados = 0;

      for (final l in logs) {
        try {
          final local = await db
              .query('nascimento_log', where: 'id = ?', whereArgs: [l['id']]);

          final dados = {
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
            'usuario_id': l['usuario_id'],
            'criado_em': l['criado_em'],
            'atualizado_em': l['atualizado_em'],
          };

          if (local.isEmpty) {
            await db.insert('nascimento_log', dados);
            inseridos++;
            print('✓ Nascimento_log ${l['cria']} inserido do servidor');
          } else {
            await db.update('nascimento_log', dados,
                where: 'id = ?', whereArgs: [l['id']]);
            atualizados++;
            print('✓ Nascimento_log ${l['cria']} atualizado do servidor');
          }
        } catch (e) {
          print('✗ Erro ao processar nascimento_log ${l['id']}: $e');
        }
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
      final response = await _supabase
          .from('morte_log')
          .select()
          .order('atualizado_em', ascending: false);

      final mortes = response as List<dynamic>;

      for (final m in mortes) {
        try {
          final local = await db
              .query('morte_log', where: 'id = ?', whereArgs: [m['id']]);

          final dados = {
            'id': m['id'],
            'nascimento_id': m['nascimento_id'],
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

          if (local.isEmpty) {
            await db.insert('morte_log', dados);
          } else {
            final timestampLocal = (local.first['atualizado_em'] as String?) ??
                (local.first['criado_em'] as String?);
            final timestampRemoto = m['atualizado_em'] as String?;

            if (timestampRemoto != null &&
                (timestampLocal == null ||
                    timestampRemoto.compareTo(timestampLocal) > 0)) {
              await db.update('morte_log', dados,
                  where: 'id = ?', whereArgs: [m['id']]);
            }
          }
        } catch (e) {
          print('✗ Erro ao processar morte ${m['id']}: $e');
        }
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
      final response = await _supabase
          .from('transferencia_log')
          .select()
          .order('data_registro', ascending: false);

      final transferencias = response as List<dynamic>;
      for (final t in transferencias) {
        try {
          final local = await db.query('transferencia_log',
              where: 'id = ?', whereArgs: [t['id']]);

          final dados = {
            'id': t['id'],
            'animal_id': t['animal_id'],
            'fazenda_origem': t['fazenda_origem'],
            'fazenda_destino': t['fazenda_destino'],
            'lote_origem': t['lote_origem'],
            'lote_destino': t['lote_destino'],
            'pasto_origem': t['pasto_origem'],
            'pasto_destino': t['pasto_destino'],
            'usuario_id': t['usuario_id'],
            'data_transferencia': t['data_transferencia'],
            'data_registro': t['data_registro'],
            'atualizado_em': t['atualizado_em'],
          };

          if (local.isEmpty) {
            await db.insert('transferencia_log', dados);
          } else {
            await db.update('transferencia_log', dados,
                where: 'id = ?', whereArgs: [t['id']]);
          }
        } catch (e) {
          print('✗ Erro ao processar transferencia ${t['id']}: $e');
        }
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
      final response = await _supabase
          .from('solicitacao_faixa')
          .select()
          .order('solicitado_em', ascending: false);

      final solicitacoes = response as List<dynamic>;

      for (final s in solicitacoes) {
        try {
          final local = await db.query('solicitacao_faixa',
              where: 'id = ?', whereArgs: [s['id']]);

          final dados = {
            'id': s['id'],
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

          if (local.isEmpty) {
            await db.insert('solicitacao_faixa', dados);
          } else {
            final timestampLocal = (local.first['atualizado_em'] as String?) ??
                (local.first['solicitado_em'] as String?);
            final timestampRemoto = s['atualizado_em'] as String?;

            if (timestampRemoto != null &&
                (timestampLocal == null ||
                    timestampRemoto.compareTo(timestampLocal) > 0)) {
              await db.update('solicitacao_faixa', dados,
                  where: 'id = ?', whereArgs: [s['id']]);
            }
          }
        } catch (e) {
          print('✗ Erro ao processar solicitação ${s['id']}: $e');
        }
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
      await txn.delete('morte_log');
      await txn.delete('nascimento_log');
      await txn.delete('animal');
      await txn.delete('transferencia_log');
      await txn.delete('solicitacao_faixa');
      await txn.delete('usuario');
    });
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
      await txn.update('morte_log', {'usuario_id': serverId},
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
            await txn.update('morte_log', {'usuario_id': fallbackId},
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
