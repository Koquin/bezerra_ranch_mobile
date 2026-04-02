import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDb {
  static Database? _db;

  static Future<Database> getDb() async {
    print('Entrou no getDb do AppDb');
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'bezerra_ranch.db');

    _db = await openDatabase(
      path,
      version: 10,
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
            status TEXT NOT NULL DEFAULT 'ATIVO' CHECK(status IN ('ATIVO','VENDIDO','MORTO'))
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

        // Seed: usuário admin padrão
        // login: admin | senha: admin123
        final adminHash = sha256.convert(utf8.encode('admin123')).toString();

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
          await db.execute("ALTER TABLE nascimento RENAME TO nascimento_log;");

          await db.execute('''
            CREATE TABLE animal (
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
              status TEXT NOT NULL DEFAULT 'ATIVO' CHECK(status IN ('ATIVO','VENDIDO','MORTO'))
            );
          ''');

          await db.execute(
              "INSERT INTO animal (id, cria, mae, sexo, raca, pelagem, data_nascimento, fazenda, observacao, foto1, foto2, foto3, location_cidade, location_bairro, location_latitude, location_longitude, usuario_id, criado_em, atualizado_em, status) SELECT id, cria, mae, sexo, raca, pelagem, data_nascimento, fazenda, observacao, foto1, foto2, foto3, location_cidade, location_bairro, location_latitude, location_longitude, usuario_id, criado_em, atualizado_em, CASE WHEN IFNULL(morto,0)=1 THEN 'MORTO' ELSE 'ATIVO' END FROM nascimento_log;");

          await db.execute(
              "ALTER TABLE nascimento_log ADD COLUMN animal_id INTEGER;");
          await db.execute(
              "UPDATE nascimento_log SET animal_id = id WHERE animal_id IS NULL;");
        }
        if (oldVersion < 8) {
          await db.execute("ALTER TABLE animal ADD COLUMN peso REAL;");
          await db.execute("ALTER TABLE nascimento_log ADD COLUMN peso REAL;");
        }
        if (oldVersion < 9) {
          await db.execute(
              "ALTER TABLE animal ADD COLUMN status TEXT NOT NULL DEFAULT 'ATIVO';");
          await db.execute(
              "UPDATE animal SET status = CASE WHEN IFNULL(morto, 0) = 1 THEN 'MORTO' ELSE 'ATIVO' END WHERE status IS NULL OR TRIM(status) = '';");
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
      },
    );

    return _db!;
  }
}
