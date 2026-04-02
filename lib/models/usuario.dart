class Usuario {
  final int id;
  final String nome;
  final String login;
  final bool ativo;
  final bool isAdmin;
  final String prefixo;
  final int inicio;
  final int maximo;

  Usuario({
    required this.id,
    required this.nome,
    required this.login,
    required this.ativo,
    required this.isAdmin,
    required this.prefixo,
    required this.inicio,
    required this.maximo,
  });

  static Usuario fromMap(Map<String, Object?> r) => Usuario(
        id: r['id'] as int,
        nome: r['nome'] as String,
        login: r['login'] as String,
        ativo: (r['ativo'] as int) == 1,
        isAdmin: (r['is_admin'] as int) == 1,
        prefixo: r['cria_prefixo'] as String,
        inicio: r['cria_inicio'] as int,
        maximo: r['cria_max'] as int,
      );
}
