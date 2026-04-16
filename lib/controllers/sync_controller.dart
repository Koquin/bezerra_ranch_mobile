import '../services/supabase_sync_service.dart';

class SyncController {
  Future<bool> verificarConexao() => SupabaseSyncService.verificarConexao();

  Future<bool> deveSincronizarAutomatico() =>
      SupabaseSyncService.deveSincronizarAutomatico();

  Future<void> sincronizar() => SupabaseSyncService.sincronizar();

  Future<void> sincronizarAnimais() =>
      SupabaseSyncService.sincronizarModuloAnimais();

  Future<void> sincronizarNascimentos() =>
      SupabaseSyncService.sincronizarModuloNascimentos();

  Future<void> sincronizarBaixas() =>
      SupabaseSyncService.sincronizarModuloBaixas();

  Future<void> sincronizarTransferencias() =>
      SupabaseSyncService.sincronizarModuloTransferencias();

  Future<void> sincronizarUsuarios() =>
      SupabaseSyncService.sincronizarModuloUsuarios();

  Future<void> baixarUsuarios() => SupabaseSyncService.baixarUsuarios();

  Future<void> baixarSolicitacoes() => SupabaseSyncService.baixarSolicitacoes();
}
