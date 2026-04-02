import '../services/supabase_sync_service.dart';

class SyncController {
  Future<bool> verificarConexao() => SupabaseSyncService.verificarConexao();

  Future<void> sincronizar() => SupabaseSyncService.sincronizar();

  Future<void> baixarUsuarios() => SupabaseSyncService.baixarUsuarios();

  Future<void> baixarSolicitacoes() => SupabaseSyncService.baixarSolicitacoes();
}
