import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.trim().isEmpty) {
      throw StateError('SUPABASE_URL não definido no .env');
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.trim().isEmpty) {
      throw StateError('SUPABASE_ANON_KEY não definido no .env');
    }
    return value;
  }
}
