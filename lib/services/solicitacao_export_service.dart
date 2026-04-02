import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'solicitacao_service.dart';

class SolicitacaoExportService {
  final _service = SolicitacaoService();

  Future<File> exportarCsv({required String status}) async {
    print('Entrou no exportarCsv do SolicitacaoExportService, status=$status');
    final items = await _service.listByStatus(status);

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/solicitacoes_${status}_$stamp.csv');

    final fmt = DateFormat('dd/MM/yyyy - HH:mm:ss');
    final b = StringBuffer();
    b.writeln(
        'STATUS,USUARIO,USUARIO_ID,PREFIXO,INICIO_ATUAL,MAX_ATUAL,RESTANTES,SOLICITADO_EM');

    String esc(String v) => '"${v.replaceAll('"', '""')}"';

    for (final s in items) {
      b.writeln([
        esc(s.status),
        esc(s.usuarioNome),
        s.usuarioId.toString(),
        esc(s.prefixo),
        s.inicioAtual.toString(),
        s.maxAtual.toString(),
        s.restantes.toString(),
        esc(fmt.format(s.solicitadoEm)),
      ].join(','));
    }

    return file.writeAsString(b.toString(), flush: true);
  }
}
