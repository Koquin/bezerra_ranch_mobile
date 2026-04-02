# Bezerra Ranch Rotinas — Preparação para Android (produção)

Este pacote contém **overrides** prontos (ícones + splash) e um guia para aplicar em um projeto Flutter.

> Observação: este ZIP contém apenas a pasta `lib/` e configurações do app. Para gerar as pastas nativas (`android/`, `ios/`), execute **no seu PC**:
>
> ```bash
> flutter create .
> ```
>
> Isso cria a estrutura padrão do Android. Em seguida, aplique os arquivos deste pacote.

## 1) Nome do app
Nome sugerido (exibido no celular): **Bezerra Ranch Rotinas**

No arquivo abaixo do Android (após `flutter create .`):

- `android/app/src/main/res/values/strings.xml`

Defina:

```xml
<string name="app_name">Bezerra Ranch Rotinas</string>
```

## 2) applicationId (pacote Android)
applicationId sugerido:

- **com.bezerraranch.rotinas**

No arquivo:

- `android/app/build.gradle`

Localize o bloco `defaultConfig` e ajuste:

```gradle
applicationId "com.bezerraranch.rotinas"
```

## 3) Ícone do app (launcher)
Os ícones prontos estão em:

- `production_overrides/android/app/src/main/res/mipmap-*`
- `production_overrides/android/app/src/main/res/mipmap-anydpi-v26/`

Copie **substituindo** a pasta `res` do Android:

- Origem: `production_overrides/android/app/src/main/res/`
- Destino: `android/app/src/main/res/`

## 4) Splash (tela de abertura)
O splash usa:

- `drawable/launch_background.xml`
- `drawable/splash_image.png`
- `values/colors.xml` (cor de fundo)

Estes arquivos já estão incluídos na mesma pasta `production_overrides/.../res`.

## 5) Verificação final
Depois de copiar os overrides e editar `strings.xml` e `build.gradle`:

```bash
flutter pub get
flutter run
```

Para gerar APK release:

```bash
flutter build apk --release
```

## 6) Ajustes fáceis
- Para trocar a cor do splash, edite `android/app/src/main/res/values/colors.xml` (`splash_bg`).
- Para trocar o nome do app, edite `strings.xml` (`app_name`).
