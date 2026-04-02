import '../models/morte.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/nascimento.dart';
import '../models/usuario.dart';
import 'usuario_service.dart';

class ExportService {
  Future<File> exportMortesCsv(List<Morte> items) async {
    print('Entrou no exportMortesCsv do ExportService, itens=${items.length}');
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/mortes_$stamp.csv');

    final fmt = DateFormat('dd/MM/yyyy');
    final fmtIns = DateFormat('dd/MM/yyyy - HH:mm:ss');

    final b = StringBuffer();
    b.writeln(
        'ID,NASCIMENTO_ID,DATA_MORTE,FAZENDA,AUDIO,DESCRICAO,CIDADE,BAIRRO,LATITUDE,LONGITUDE,USUARIO_NOME,USUARIO_LOGIN,INSERIDO_EM');

    String esc(String? v) => v == null ? '' : '"${v.replaceAll('"', '""')}"';

    final usuarioService = UsuarioService();
    for (final m in items) {
      final usuario = await usuarioService.getById(m.usuarioId);
      b.writeln([
        m.id?.toString() ?? '',
        m.nascimentoId.toString(),
        esc(fmt.format(m.dataMorte)),
        esc(m.fazenda),
        esc(m.audio),
        esc(m.descricao),
        esc(m.locationCidade ?? ''),
        esc(m.locationBairro ?? ''),
        m.locationLatitude?.toString() ?? '',
        m.locationLongitude?.toString() ?? '',
        esc(usuario?.nome ?? ''),
        esc(usuario?.login ?? ''),
        esc(fmtIns.format(m.criadoEm)),
      ].join(','));
    }

    return file.writeAsString(b.toString(), flush: true);
  }

  Future<File> exportNascimentosCsv(List<Nascimento> items) async {
    print(
        'Entrou no exportNascimentosCsv do ExportService, itens=${items.length}');
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/nascimentos_$stamp.csv');

    final fmt = DateFormat('dd/MM/yyyy');
    final fmtIns = DateFormat('dd/MM/yyyy - HH:mm:ss');

    final b = StringBuffer();
    b.writeln(
        'CRIA,MAE,SEXO,RACA,PELAGEM,DATA_NASCIMENTO,FAZENDA,OBSERVACAO,CIDADE,BAIRRO,LATITUDE,LONGITUDE,USUARIO_NOME,USUARIO_LOGIN,INSERIDO_EM');

    String esc(String? v) => v == null ? '' : '"${v.replaceAll('"', '""')}"';

    final usuarioService = UsuarioService();
    for (final n in items) {
      final usuario = await usuarioService.getById(n.usuarioId);
      b.writeln([
        esc(n.cria),
        esc(n.mae),
        esc(n.sexo),
        esc(n.raca),
        esc(n.pelagem),
        esc(fmt.format(n.dataNascimento)),
        esc(n.fazenda),
        esc(n.observacao ?? ''),
        esc(n.locationCidade ?? ''),
        esc(n.locationBairro ?? ''),
        n.locationLatitude?.toString() ?? '',
        n.locationLongitude?.toString() ?? '',
        esc(usuario?.nome ?? ''),
        esc(usuario?.login ?? ''),
        esc(fmtIns.format(n.criadoEm)),
      ].join(','));
    }

    return file.writeAsString(b.toString(), flush: true);
  }

  Future<File> exportUsuariosCsv(List<Usuario> items) async {
    print(
        'Entrou no exportUsuariosCsv do ExportService, itens=${items.length}');
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/usuarios_$stamp.csv');

    final b = StringBuffer();
    b.writeln('ID,NOME,LOGIN,ATIVO,IS_ADMIN,PREFIXO,INICIO,MAXIMO');

    String esc(String? v) => v == null ? '' : '"${v.replaceAll('"', '""')}"';

    for (final u in items) {
      b.writeln([
        u.id.toString(),
        esc(u.nome),
        esc(u.login),
        u.ativo ? 'SIM' : 'NÃO',
        u.isAdmin ? 'SIM' : 'NÃO',
        esc(u.prefixo),
        u.inicio.toString(),
        u.maximo.toString(),
      ].join(','));
    }

    return file.writeAsString(b.toString(), flush: true);
  }
}
