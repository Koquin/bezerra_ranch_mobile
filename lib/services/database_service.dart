import 'package:sqflite/sqflite.dart';

import 'app_db.dart';

class DatabaseService {
  Future<Database> db() => AppDb.getDb();
}
