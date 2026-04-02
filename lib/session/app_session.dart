class AppSession {
  static int? usuarioId;
  static String? usuarioNome;
  static String? usuarioLogin;
  static bool isAdmin = false;
  static String? fazendaSelecionada;

  static String? criaPrefixo;
  static int? criaInicio;
  static int? criaMax;
  static String? lockedFazenda;
  static bool travaFazenda = false;
  static DateTime? lockedDataNascimento;
  static bool travaDataNascimento = false;

  static void clear() {
    print('Entrou no clear do AppSession');
    usuarioId = null;
    usuarioNome = null;
    usuarioLogin = null;
    isAdmin = false;
    fazendaSelecionada = null;
    criaPrefixo = null;
    criaInicio = null;
    criaMax = null;
    lockedFazenda = null;
    travaFazenda = false;
    lockedDataNascimento = null;
    travaDataNascimento = false;
  }
}
