import '../models/nascimento.dart';
import '../session/app_session.dart';
import '../services/nascimento_service.dart';

class NascimentoController {
  final NascimentoService _nascimentoService;

  NascimentoController({NascimentoService? nascimentoService})
      : _nascimentoService = nascimentoService ?? NascimentoService();

  Future<List<Nascimento>> list({String? q}) {
    print('[NascimentoController.list] q=$q');
    return _nascimentoService.list(q: q);
  }

  Future<List<Nascimento>> listPorFaixa({
    required String prefixo,
    required int inicio,
    required int maximo,
    String? fazenda,
    int? usuarioId,
    String? q,
  }) {
    print(
        '[NascimentoController.listPorFaixa] prefixo=$prefixo inicio=$inicio maximo=$maximo fazenda=$fazenda usuarioId=$usuarioId q=$q');
    return _nascimentoService.listPorFaixa(
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
      fazenda: fazenda,
      usuarioId: usuarioId,
      q: q,
    );
  }

  Future<int> insert(Nascimento n) {
    print('[NascimentoController.insert] id=${n.id} cria=${n.cria}');
    return _nascimentoService.insert(n);
  }

  Future<int> update(Nascimento n) {
    print('[NascimentoController.update] id=${n.id} cria=${n.cria}');
    return _nascimentoService.update(n);
  }

  Future<int> delete(int id) {
    if (!AppSession.isAdmin) {
      throw StateError('Apenas administradores podem excluir animais.');
    }

    print('[NascimentoController.delete] id=$id');
    return _nascimentoService.delete(id);
  }

  Future<String> gerarProximaCriaPorUsuario({
    required int usuarioId,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) {
    print(
        '[NascimentoController.gerarProximaCriaPorUsuario] usuarioId=$usuarioId prefixo=$prefixo inicio=$inicio maximo=$maximo');
    return _nascimentoService.gerarProximaCriaPorUsuario(
      usuarioId: usuarioId,
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
    );
  }

  Future<int> calcularRestantes({
    required int usuarioId,
    required String prefixo,
    required int inicio,
    required int maximo,
  }) {
    print(
        '[NascimentoController.calcularRestantes] usuarioId=$usuarioId prefixo=$prefixo inicio=$inicio maximo=$maximo');
    return _nascimentoService.calcularRestantes(
      usuarioId: usuarioId,
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
    );
  }

  Future<int> obterUltimoNumeroUsadoPorPrefixo({
    required String prefixo,
  }) {
    print(
        '[NascimentoController.obterUltimoNumeroUsadoPorPrefixo] prefixo="$prefixo"');
    return _nascimentoService.obterUltimoNumeroUsadoPorPrefixo(
      prefixo: prefixo,
    );
  }

  Future<int> obterPrimeiroNumeroDisponivelPorPrefixo({
    required String prefixo,
    required int inicio,
    required int maximo,
  }) {
    print(
        '[NascimentoController.obterPrimeiroNumeroDisponivelPorPrefixo] prefixo="$prefixo" inicio=$inicio maximo=$maximo');
    return _nascimentoService.obterPrimeiroNumeroDisponivelPorPrefixo(
      prefixo: prefixo,
      inicio: inicio,
      maximo: maximo,
    );
  }
}
