import '../services/solicitacao_service.dart';
import '../models/solicitacao.dart';

class SolicitacaoController {
  final SolicitacaoService _solicitacaoService;

  SolicitacaoController({SolicitacaoService? solicitacaoService})
      : _solicitacaoService = solicitacaoService ?? SolicitacaoService();

  Future<int> criar({
    required int usuarioId,
    required String usuarioNome,
    required String prefixo,
    required int inicioAtual,
    required int maxAtual,
    required int restantes,
  }) {
    return _solicitacaoService.criar(
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      prefixo: prefixo,
      inicioAtual: inicioAtual,
      maxAtual: maxAtual,
      restantes: restantes,
    );
  }

  Future<List<Solicitacao>> listByStatus(String status) =>
      _solicitacaoService.listByStatus(status);

  Future<int> countPendentes() => _solicitacaoService.countPendentes();

  Future<int> marcarAtendida(int id) => _solicitacaoService.marcarAtendida(id);
}
