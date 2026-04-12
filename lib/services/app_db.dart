import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDb {
  static Database? _db;

  static Future<void> _garantirColunaIsInconsistency(Database db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='transferencia_log'");
    if (tables.isEmpty) return;

    final cols = await db.rawQuery("PRAGMA table_info(transferencia_log);");
    final hasIsInconsistency = cols.any((c) => c['name'] == 'is_inconsistency');
    if (!hasIsInconsistency) {
      await db.execute(
          "ALTER TABLE transferencia_log ADD COLUMN is_inconsistency INTEGER NOT NULL DEFAULT 0;");
    }
  }

  static Future<void> _garantirBaixaLog(Database db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('baixa_log','morte_log')");
    final hasBaixaLog = tables.any((t) => t['name'] == 'baixa_log');
    final hasMorteLog = tables.any((t) => t['name'] == 'morte_log');

    if (!hasBaixaLog && hasMorteLog) {
      await db.execute("ALTER TABLE morte_log RENAME TO baixa_log;");
    }

    if (!hasBaixaLog && !hasMorteLog) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS baixa_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nascimento_id INTEGER NOT NULL,
          tipo_baixa TEXT NOT NULL DEFAULT 'MORTE',
          data_morte TEXT NOT NULL,
          fazenda TEXT NOT NULL,
          foto1 TEXT,
          foto2 TEXT,
          foto3 TEXT,
          audio TEXT,
          descricao TEXT,
          location_cidade TEXT,
          location_bairro TEXT,
          location_latitude REAL,
          location_longitude REAL,
          usuario_id INTEGER NOT NULL,
          criado_em TEXT NOT NULL,
          atualizado_em TEXT NOT NULL,
          FOREIGN KEY(nascimento_id) REFERENCES animal(id)
        );
      ''');
    }

    final cols = await db.rawQuery("PRAGMA table_info(baixa_log);");
    final hasTipoBaixa = cols.any((c) => c['name'] == 'tipo_baixa');
    if (!hasTipoBaixa) {
      await db.execute(
          "ALTER TABLE baixa_log ADD COLUMN tipo_baixa TEXT NOT NULL DEFAULT 'MORTE';");
    }
  }

  static Future<Database> getDb() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'bezerra_ranch.db');

    _db = await openDatabase(
      path,
      version: 14,
      onOpen: (db) async {
        await _garantirColunaIsInconsistency(db);
        await _garantirBaixaLog(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuario (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            login TEXT NOT NULL UNIQUE,
            senha_hash TEXT NOT NULL,
            ativo INTEGER NOT NULL DEFAULT 1,
            cria_prefixo TEXT NOT NULL,
            cria_inicio INTEGER NOT NULL,
            cria_max INTEGER NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            criado_em TEXT NOT NULL,
            atualizado_em TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE animal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cria TEXT NOT NULL UNIQUE,
            mae TEXT NOT NULL,
            sexo TEXT NOT NULL,
            raca TEXT NOT NULL,
            peso REAL,
            pelagem TEXT NOT NULL,
            data_nascimento TEXT NOT NULL,
            fazenda TEXT NOT NULL,
            lote TEXT,
            pasto TEXT,
            observacao TEXT,
            foto1 TEXT,
            foto2 TEXT,
            foto3 TEXT,
            location_cidade TEXT,
            location_bairro TEXT,
            location_latitude REAL,
            location_longitude REAL,
            usuario_id INTEGER NOT NULL,
            criado_em TEXT NOT NULL,
            atualizado_em TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'ATIVO' CHECK(status IN ('ATIVO','VENDIDO','MORTO','ABATIDO'))
          );
        ''');

        await db.execute('''
          CREATE TABLE nascimento_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            animal_id INTEGER NOT NULL,
            cria TEXT NOT NULL,
            mae TEXT NOT NULL,
            sexo TEXT NOT NULL,
            raca TEXT NOT NULL,
            peso REAL,
            pelagem TEXT NOT NULL,
            data_nascimento TEXT NOT NULL,
            fazenda TEXT NOT NULL,
            lote TEXT,
            pasto TEXT,
            observacao TEXT,
            foto1 TEXT,
            foto2 TEXT,
            foto3 TEXT,
            location_cidade TEXT,
            location_bairro TEXT,
            location_latitude REAL,
            location_longitude REAL,
            usuario_id INTEGER NOT NULL,
            criado_em TEXT NOT NULL,
            atualizado_em TEXT NOT NULL,
            FOREIGN KEY(animal_id) REFERENCES animal(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE baixa_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nascimento_id INTEGER NOT NULL,
            tipo_baixa TEXT NOT NULL DEFAULT 'MORTE',
            data_morte TEXT NOT NULL,
            fazenda TEXT NOT NULL,
            foto1 TEXT,
            foto2 TEXT,
            foto3 TEXT,
            audio TEXT,
            descricao TEXT,
            location_cidade TEXT,
            location_bairro TEXT,
            location_latitude REAL,
            location_longitude REAL,
            usuario_id INTEGER NOT NULL,
            criado_em TEXT NOT NULL,
            atualizado_em TEXT NOT NULL,
            FOREIGN KEY(nascimento_id) REFERENCES animal(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE solicitacao_faixa (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            usuario_nome TEXT NOT NULL,
            prefixo TEXT NOT NULL,
            inicio_atual INTEGER NOT NULL,
            max_atual INTEGER NOT NULL,
            restantes INTEGER NOT NULL,
            solicitado_em TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDENTE',
            atualizado_em TEXT NOT NULL 
          );
        ''');

        await db.execute('''
          CREATE TABLE transferencia_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            animal_id INTEGER NOT NULL,
            fazenda_origem TEXT NOT NULL,
            fazenda_destino TEXT NOT NULL,
            lote_origem TEXT,
            lote_destino TEXT,
            pasto_origem TEXT,
            pasto_destino TEXT,
            is_inconsistency INTEGER NOT NULL DEFAULT 0,
            usuario_id INTEGER NOT NULL,
            data_transferencia TEXT NOT NULL,
            data_registro TEXT NOT NULL,
            atualizado_em TEXT,
            FOREIGN KEY(animal_id) REFERENCES animal(id)
          );
        ''');

        // Seed: usuário admin padrão (senha vinda do .env)
        final adminPassword = dotenv.env['ADMIN_DEFAULT_PASSWORD'];
        if (adminPassword == null || adminPassword.trim().isEmpty) {
          throw StateError('ADMIN_DEFAULT_PASSWORD não definido no .env');
        }
        final adminHash = sha256.convert(utf8.encode(adminPassword)).toString();

        await db.insert('usuario', {
          'nome': 'Administrador',
          'login': 'admin',
          'senha_hash': adminHash,
          'ativo': 1,
          'cria_prefixo': 'E',
          'cria_inicio': 10,
          'cria_max': 1000,
          'is_admin': 1,
          'criado_em': DateTime.now().toIso8601String(),
          'atualizado_em': DateTime.now().toIso8601String(),
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // add photo columns
          await db.execute("ALTER TABLE nascimento ADD COLUMN foto1 TEXT;");
          await db.execute("ALTER TABLE nascimento ADD COLUMN foto2 TEXT;");
          await db.execute("ALTER TABLE nascimento ADD COLUMN foto3 TEXT;");
        }
        if (oldVersion < 3) {
          await db.execute(
              "ALTER TABLE nascimento ADD COLUMN morto INTEGER NOT NULL DEFAULT 0;");
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE morte (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nascimento_id INTEGER NOT NULL,
              data_morte TEXT NOT NULL,
              fazenda TEXT NOT NULL,
              foto1 TEXT,
              foto2 TEXT,
              foto3 TEXT,
              audio TEXT,
              descricao TEXT,
            location_cidade TEXT,
            location_bairro TEXT,
            location_latitude REAL,
            location_longitude REAL,
              usuario_id INTEGER NOT NULL,
              criado_em TEXT NOT NULL,
              FOREIGN KEY(nascimento_id) REFERENCES nascimento(id)
            );
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
              "ALTER TABLE nascimento ADD COLUMN location_cidade TEXT;");
          await db.execute(
              "ALTER TABLE nascimento ADD COLUMN location_bairro TEXT;");
          await db.execute(
              "ALTER TABLE nascimento ADD COLUMN location_latitude REAL;");
          await db.execute(
              "ALTER TABLE nascimento ADD COLUMN location_longitude REAL;");
          await db
              .execute("ALTER TABLE morte ADD COLUMN location_cidade TEXT;");
          await db
              .execute("ALTER TABLE morte ADD COLUMN location_bairro TEXT;");
          await db
              .execute("ALTER TABLE morte ADD COLUMN location_latitude REAL;");
          await db
              .execute("ALTER TABLE morte ADD COLUMN location_longitude REAL;");
        }
        if (oldVersion < 6) {
          await db
              .execute("ALTER TABLE usuario ADD COLUMN atualizado_em TEXT;");
          await db
              .execute("ALTER TABLE nascimento ADD COLUMN atualizado_em TEXT;");
          await db.execute("ALTER TABLE morte ADD COLUMN atualizado_em TEXT;");
          await db.execute(
              "ALTER TABLE solicitacao_faixa ADD COLUMN atualizado_em TEXT;");

          await db.execute(
              "UPDATE usuario SET atualizado_em = criado_em WHERE atualizado_em IS NULL;");
          await db.execute(
              "UPDATE nascimento SET atualizado_em = criado_em WHERE atualizado_em IS NULL;");
          await db.execute(
              "UPDATE morte SET atualizado_em = criado_em WHERE atualizado_em IS NULL;");
          await db.execute(
              "UPDATE solicitacao_faixa SET atualizado_em = solicitado_em WHERE atualizado_em IS NULL;");
        }
        if (oldVersion < 7) {
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('nascimento','nascimento_log','animal')");
          final hasNascimento = tables.any((t) => t['name'] == 'nascimento');
          final hasNascimentoLog =
              tables.any((t) => t['name'] == 'nascimento_log');

          if (hasNascimento && !hasNascimentoLog) {
            await db
                .execute("ALTER TABLE nascimento RENAME TO nascimento_log;");
          }

          await db.execute('''
            CREATE TABLE IF NOT EXISTS animal (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cria TEXT NOT NULL UNIQUE,
              mae TEXT NOT NULL,
              sexo TEXT NOT NULL,
              raca TEXT NOT NULL,
              pelagem TEXT NOT NULL,
              data_nascimento TEXT NOT NULL,
              fazenda TEXT NOT NULL,
              observacao TEXT,
              foto1 TEXT,
              foto2 TEXT,
              foto3 TEXT,
              location_cidade TEXT,
              location_bairro TEXT,
              location_latitude REAL,
              location_longitude REAL,
              usuario_id INTEGER NOT NULL,
              criado_em TEXT NOT NULL,
              atualizado_em TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'ATIVO' CHECK(status IN ('ATIVO','VENDIDO','MORTO','ABATIDO'))
            );
          ''');

          final tablesAfterRename = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='nascimento_log'");
          final hasNascimentoLogAfterRename = tablesAfterRename.isNotEmpty;

          if (hasNascimentoLogAfterRename) {
            final colsNascLog =
                await db.rawQuery("PRAGMA table_info(nascimento_log);");
            final hasMortoOnLog = colsNascLog.any((c) => c['name'] == 'morto');
            final hasAnimalId =
                colsNascLog.any((c) => c['name'] == 'animal_id');

            final statusExpr = hasMortoOnLog
                ? "CASE WHEN IFNULL(morto,0)=1 THEN 'MORTO' ELSE 'ATIVO' END"
                : "'ATIVO'";

            await db.execute(
                "INSERT OR IGNORE INTO animal (id, cria, mae, sexo, raca, pelagem, data_nascimento, fazenda, observacao, foto1, foto2, foto3, location_cidade, location_bairro, location_latitude, location_longitude, usuario_id, criado_em, atualizado_em, status) SELECT id, cria, mae, sexo, raca, pelagem, data_nascimento, fazenda, observacao, foto1, foto2, foto3, location_cidade, location_bairro, location_latitude, location_longitude, usuario_id, criado_em, atualizado_em, $statusExpr FROM nascimento_log;");

            if (!hasAnimalId) {
              await db.execute(
                  "ALTER TABLE nascimento_log ADD COLUMN animal_id INTEGER;");
            }
            await db.execute(
                "UPDATE nascimento_log SET animal_id = id WHERE animal_id IS NULL;");
          }
        }
        if (oldVersion < 8) {
          final animalCols = await db.rawQuery("PRAGMA table_info(animal);");
          final hasAnimalPeso = animalCols.any((c) => c['name'] == 'peso');
          if (!hasAnimalPeso) {
            await db.execute("ALTER TABLE animal ADD COLUMN peso REAL;");
          }

          final nascLogExists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='nascimento_log'");
          if (nascLogExists.isNotEmpty) {
            final nascLogCols =
                await db.rawQuery("PRAGMA table_info(nascimento_log);");
            final hasNascLogPeso = nascLogCols.any((c) => c['name'] == 'peso');
            if (!hasNascLogPeso) {
              await db
                  .execute("ALTER TABLE nascimento_log ADD COLUMN peso REAL;");
            }
          }
        }
        if (oldVersion < 9) {
          final cols = await db.rawQuery("PRAGMA table_info(animal);");
          final hasStatus = cols.any((c) => c['name'] == 'status');
          final hasMorto = cols.any((c) => c['name'] == 'morto');

          if (!hasStatus) {
            await db.execute(
                "ALTER TABLE animal ADD COLUMN status TEXT NOT NULL DEFAULT 'ATIVO';");
          }

          if (hasMorto) {
            await db.execute(
                "UPDATE animal SET status = CASE WHEN IFNULL(morto, 0) = 1 THEN 'MORTO' ELSE 'ATIVO' END WHERE status IS NULL OR TRIM(CAST(status AS TEXT)) = '';");
          } else {
            await db.execute('''
              UPDATE animal
              SET status = CASE
                WHEN UPPER(TRIM(CAST(status AS TEXT))) IN ('ATIVO','VENDIDO','MORTO','ABATIDO')
                  THEN UPPER(TRIM(CAST(status AS TEXT)))
                WHEN TRIM(CAST(status AS TEXT)) IN ('1', 'true', 'TRUE')
                  THEN 'MORTO'
                ELSE 'ATIVO'
              END;
            ''');
          }
        }
        if (oldVersion < 10) {
          final cols = await db.rawQuery("PRAGMA table_info(animal);");
          final hasStatus = cols.any((c) => c['name'] == 'status');
          final hasMorto = cols.any((c) => c['name'] == 'morto');

          if (!hasStatus && hasMorto) {
            await db
                .execute("ALTER TABLE animal RENAME COLUMN morto TO status;");
          } else if (!hasStatus) {
            await db.execute(
                "ALTER TABLE animal ADD COLUMN status TEXT NOT NULL DEFAULT 'ATIVO';");
          }

          await db.execute('''
            UPDATE animal
            SET status = CASE
              WHEN UPPER(TRIM(CAST(status AS TEXT))) IN ('ATIVO','VENDIDO','MORTO')
                THEN UPPER(TRIM(CAST(status AS TEXT)))
              WHEN TRIM(CAST(status AS TEXT)) IN ('1', 'true', 'TRUE')
                THEN 'MORTO'
              ELSE 'ATIVO'
            END;
          ''');

          // Se as duas colunas existirem (bancos intermediários), prioriza status e não quebra migração.
          final colsAfter = await db.rawQuery("PRAGMA table_info(animal);");
          final hasStatusAfter = colsAfter.any((c) => c['name'] == 'status');
          final hasMortoAfter = colsAfter.any((c) => c['name'] == 'morto');
          if (hasStatusAfter && hasMortoAfter) {
            await db.execute(
                "UPDATE animal SET status = CASE WHEN IFNULL(morto, 0) = 1 THEN 'MORTO' ELSE status END;");
          }
        }
        if (oldVersion < 11) {
          final animalCols = await db.rawQuery("PRAGMA table_info(animal);");
          final hasLoteAnimal = animalCols.any((c) => c['name'] == 'lote');
          final hasPastoAnimal = animalCols.any((c) => c['name'] == 'pasto');
          if (!hasLoteAnimal) {
            await db.execute("ALTER TABLE animal ADD COLUMN lote TEXT;");
          }
          if (!hasPastoAnimal) {
            await db.execute("ALTER TABLE animal ADD COLUMN pasto TEXT;");
          }

          final nascLogExists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='nascimento_log'");
          if (nascLogExists.isNotEmpty) {
            final nascLogCols =
                await db.rawQuery("PRAGMA table_info(nascimento_log);");
            final hasLoteNascLog = nascLogCols.any((c) => c['name'] == 'lote');
            final hasPastoNascLog =
                nascLogCols.any((c) => c['name'] == 'pasto');
            if (!hasLoteNascLog) {
              await db
                  .execute("ALTER TABLE nascimento_log ADD COLUMN lote TEXT;");
            }
            if (!hasPastoNascLog) {
              await db
                  .execute("ALTER TABLE nascimento_log ADD COLUMN pasto TEXT;");
            }
          }

          await db.execute('''
            CREATE TABLE IF NOT EXISTS transferencia_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              animal_id INTEGER NOT NULL,
              fazenda_origem TEXT NOT NULL,
              fazenda_destino TEXT NOT NULL,
              lote_origem TEXT,
              lote_destino TEXT,
              pasto_origem TEXT,
              pasto_destino TEXT,
              is_inconsistency INTEGER NOT NULL DEFAULT 0,
              usuario_id INTEGER NOT NULL,
              data_transferencia TEXT NOT NULL,
              data_registro TEXT NOT NULL,
              atualizado_em TEXT,
              FOREIGN KEY(animal_id) REFERENCES animal(id)
            );
          ''');
        }
        if (oldVersion < 12) {
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('morte','morte_log','baixa_log')");
          final hasMorte = tables.any((t) => t['name'] == 'morte');
          final hasMorteLog = tables.any((t) => t['name'] == 'morte_log');
          final hasBaixaLog = tables.any((t) => t['name'] == 'baixa_log');
          if (hasMorte && !hasMorteLog && !hasBaixaLog) {
            await db.execute("ALTER TABLE morte RENAME TO baixa_log;");
          } else if (hasMorte && !hasBaixaLog) {
            await db.execute("ALTER TABLE morte RENAME TO morte_log;");
          }
        }
        if (oldVersion < 13) {
          await _garantirColunaIsInconsistency(db);
        }
        if (oldVersion < 14) {
          await _garantirBaixaLog(db);

          await db.execute('''
            UPDATE animal
            SET status = CASE
              WHEN UPPER(TRIM(CAST(status AS TEXT))) IN ('ATIVO','VENDIDO','MORTO','ABATIDO')
                THEN UPPER(TRIM(CAST(status AS TEXT)))
              ELSE 'ATIVO'
            END;
          ''');
        }
      },
    );

    return _db!;
  }
}
