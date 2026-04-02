# Bezerra Ranch App (Offline)

App Flutter offline para coleta de dados de **Nascimento de Bezerros**, com:

- Login por usuário
- **CRIA automática** por usuário (prefixo + sequência), com faixa (início/máximo) travada
- Bloqueio quando atingir limite (mensagem: "Limite atingido. Procure o Admin.")
- Contador de CRIAs restantes
- Solicitação de liberação de nova faixa via **WhatsApp** + registro local
- Tela Admin:
  - Cadastro/edição de usuários e faixas
  - Solicitações com filtro, export CSV, badge, prioridade (<= 10)

## Configurações rápidas

- WhatsApp do Admin (padrão no código): `+55 99 99953-6677`
- Link de envio Dropbox (padrão): `https://www.dropbox.com/request/DVjbvzFK1nLnJAPhOsgV`

Edite em:
- `lib/ui/nascimento/nascimento_list_page.dart`

## Como rodar

1) Instale Flutter + Android Studio
2) No terminal, dentro desta pasta:

```bash
flutter pub get
flutter run
```

## APK

```bash
flutter build apk --release
```

Saída:
`build/app/outputs/flutter-apk/app-release.apk`

## Login padrão (seed)

- usuário: `admin`
- senha: `admin123`

