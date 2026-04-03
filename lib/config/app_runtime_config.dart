import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppRuntimeConfig {
  static String get adminWhatsAppE164 {
    final value = dotenv.env['ADMIN_WHATSAPP_E164'];
    if (value == null || value.trim().isEmpty) {
      throw StateError('ADMIN_WHATSAPP_E164 não definido no .env');
    }
    return value;
  }

  static String get dropboxRequestUrl {
    final value = dotenv.env['DROPBOX_REQUEST_URL'];
    if (value == null || value.trim().isEmpty) {
      throw StateError('DROPBOX_REQUEST_URL não definido no .env');
    }
    return value;
  }
}
