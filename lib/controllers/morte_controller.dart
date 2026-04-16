import '../models/morte.dart';
import '../session/app_session.dart';
import '../services/morte_service.dart';

class MorteController {
  final MorteService _morteService;

  MorteController({MorteService? morteService})
      : _morteService = morteService ?? MorteService();

  Future<List<Morte>> list({String? q}) => _morteService.list(q: q);

  Future<Morte?> getPorNascimentoId(int nascimentoId) =>
      _morteService.getPorNascimentoId(nascimentoId);

  Future<void> salvar({
    required Morte morte,
    required int animalId,
    int? morteExistenteId,
  }) async {
    await _morteService.salvar(
      morte: morte,
      animalId: animalId,
      morteExistenteId: morteExistenteId,
    );
  }

  Future<void> deletarPorNascimento({
    required int nascimentoId,
    required int morteId,
  }) async {
    if (!AppSession.isAdmin) {
      throw StateError('Apenas administradores podem excluir baixas.');
    }

    await _morteService.deletarPorNascimento(
      nascimentoId: nascimentoId,
      morteId: morteId,
    );
  }
}
