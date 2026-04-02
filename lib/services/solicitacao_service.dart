import 'app_db.dart';
import '../models/solicitacao.dart';

class SolicitacaoService {
  Future<int> criar({
    required int usuarioId,
    required String usuarioNome,
    required String prefixo,
    required int inicioAtual,
    required int maxAtual,
    required int restantes,
  }) async {
    print(
        'Entrou no criar do SolicitacaoService, usuarioId=$usuarioId, prefixo=$prefixo, inicioAtual=$inicioAtual, maxAtual=$maxAtual, restantes=$restantes');
    final db = await AppDb.getDb();
    return db.insert('solicitacao_faixa', {
      'usuario_id': usuarioId,
      'usuario_nome': usuarioNome,
      'prefixo': prefixo,
      'inicio_atual': inicioAtual,
      'max_atual': maxAtual,
      'restantes': restantes,
      'solicitado_em': DateTime.now().toIso8601String(),
      'status': 'PENDENTE',
      'atualizado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Solicitacao>> list() async {
    print('Entrou no list do SolicitacaoService');
    final db = await AppDb.getDb();
    final rows = await db.query('solicitacao_faixa',
        orderBy: 'status ASC, solicitado_em DESC');
    return rows.map(Solicitacao.fromMap).toList();
  }

  Future<List<Solicitacao>> listByStatus(String status) async {
    print('Entrou no listByStatus do SolicitacaoService, status=$status');
    final db = await AppDb.getDb();
    final where = (status == 'TODAS') ? null : 'status = ?';
    final args = (status == 'TODAS') ? null : [status];

    final rows = await db.query(
      'solicitacao_faixa',
      where: where,
      whereArgs: args,
      orderBy: 'status ASC, solicitado_em DESC',
    );

    return rows.map(Solicitacao.fromMap).toList();
  }

  Future<int> marcarAtendida(int id) async {
    print('Entrou no marcarAtendida do SolicitacaoService, id=$id');
    final db = await AppDb.getDb();
    return db.update(
        'solicitacao_faixa',
        {
          'status': 'ATENDIDA',
          'atualizado_em': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<int> countPendentes() async {
    print('Entrou no countPendentes do SolicitacaoService');
    final db = await AppDb.getDb();
    final rows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM solicitacao_faixa WHERE status = 'PENDENTE'");
    return (rows.first['c'] as int?) ?? 0;
  }
}
