# 💊 Alarme de Medicamentos — Flutter

App multiplataforma para gerenciar medicamentos e configurar alarmes de dose, construído com Flutter + pacote `alarm`.

---

## ✅ Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel `stable`) com Dart SDK `^3.9.2`
- Um editor com suporte a Flutter (VS Code ou Android Studio)
- Para rodar em dispositivo/emulador: Android Studio (Android) e/ou Xcode (iOS/macOS, apenas em Mac)

Verifique se tudo está instalado corretamente:

```bash
flutter doctor
```

---

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                          # Entry point + MaterialApp + Provider
├── models/
│   ├── medicamento.dart               # Model + TipoMedicamento enum
│   ├── medicamentos_provider.dart     # Estado global (ChangeNotifier)
│   ├── alarm_service.dart             # Wrapper do pacote alarm (mobile) + fallback Web
│   └── alarm_impl/
│       ├── web_notifier.dart          # Exporta a implementação certa por plataforma
│       ├── web_notifier_web.dart      # Notificação nativa do navegador (Web)
│       └── web_notifier_stub.dart     # Stub usado fora da Web
├── screens/
│   ├── home_screen.dart               # Tela principal (ListView/GridView)
│   └── formulario_medicamento.dart    # Cadastro/edição (Form completo)
└── widgets/
    ├── medicamento_card.dart          # Card reutilizável com ListTile
    └── urgencia_cores.dart            # Cores de destaque conforme urgência da dose

assets/
├── alarm.mp3              # Som tocado ao disparar o alarme
└── images/
    ├── app_logo.png          # Logo no AppBar
    ├── medicine_banner.png   # Banner no formulário
    └── empty_state.png       # Imagem estado vazio
```

---

## 🧩 Widgets Utilizados

| Widget | Onde é usado |
|---|---|
| `Scaffold` | Base de todas as telas |
| `AppBar` | Barra superior com busca integrada |
| `ListView.builder` | Lista de cards no **mobile** |
| `GridView.builder` | Grid de cards na **web/tablet** |
| `Card` | Container visual de cada medicamento |
| `ListTile` | Layout interno dos cards e horários |
| `CircleAvatar` | Avatar do tipo/imagem do medicamento |
| `Image.asset` | Logo no AppBar, banner e estado vazio |
| `IconButton` | Lixeira, toggle notificação, fechar horário |
| `Icon` | Ícones de status e decoração |
| `FloatingActionButton` | Botão "+" para novo medicamento |
| `Form` | Container do formulário de cadastro |
| `TextFormField` | Nome, dosagem, observações |
| `DropdownButtonFormField` | Seleção do tipo de medicamento |
| `showTimePicker` | Relógio de seleção de horário |
| `ElevatedButton` | Botão "Adicionar Medicamento" |
| `SizedBox` | Espaçamentos no formulário |
| `MediaQuery` | Detecção de largura → mobile vs web |

---

## 📦 Dependências

```yaml
dependencies:
  cupertino_icons: ^1.0.8          # Ícones estilo iOS
  alarm: ^4.0.3                    # Alarmes nativos (Android/iOS/desktop)
  shared_preferences: ^2.3.2       # Persistência local dos medicamentos
  provider: ^6.1.2                 # Gerenciamento de estado
  intl: ^0.19.0                    # Formatação de hora (HH:mm)
  uuid: ^4.5.1                     # IDs únicos para medicamentos
  permission_handler: ^11.3.1      # Solicitação de permissões
  flutter_local_notifications: ^17.2.4  # Notificações locais (fallback desktop/web)
  audioplayers: ^6.1.0             # Reprodução do som do alarme (usado no fallback Web)
  local_notifier: ^0.1.6           # Notificações nativas em desktop (Windows/Linux/macOS)

dev_dependencies:
  flutter_lints: ^5.0.0            # Regras de lint recomendadas
```

Instale tudo com:

```bash
flutter pub get
```

---

## ⚙️ Configuração

### 1. Android — Permissões

O `AndroidManifest.xml` já inclui todas as permissões necessárias:
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`
- `FOREGROUND_SERVICE`
- `RECEIVE_BOOT_COMPLETED` (re-agendamento após reboot)
- `POST_NOTIFICATIONS` (Android 13+)

**minSdk deve ser 23** (já configurado no `build.gradle.kts`).

### 2. iOS — Background Modes

O `Info.plist` já tem:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

### 3. Adicionar imagens (opcional)

Coloque seus PNGs em `assets/images/`:
- `app_logo.png` — ícone branco 32×32px para o AppBar
- `medicine_banner.png` — imagem 128×128px para o formulário
- `empty_state.png` — ilustração para estado vazio

> **Nota:** Se as imagens não existirem, o app usa `Icon` como fallback (já tratado com `errorBuilder`).

---

## 🔔 Como funciona o alarm

O pacote `alarm` agenda alarmes nativos que tocam mesmo com o app fechado:

```dart
// Agendar
await Alarm.set(alarmSettings: AlarmSettings(
  id: 1234,
  dateTime: DateTime.now().add(Duration(hours: 1)),
  assetAudioPath: 'assets/alarm.mp3',
  notificationSettings: NotificationSettings(
    title: '💊 Losartana',
    body: '50mg — Hora de tomar!',
  ),
));

// Cancelar
await Alarm.stop(1234);
```

O `AlarmService` encapsula essa lógica e calcula automaticamente o **próximo disparo** para cada horário configurado.

---

## 📱 Layout Adaptativo

O `MediaQuery` detecta a largura da tela e alterna entre:

| Largura | Layout | Colunas |
|---|---|---|
| < 480px | ListView | — |
| 480–720px | GridView | 2 |
| 720–900px | GridView | 2 |
| 900–1200px | GridView | 3 |
| > 1200px | GridView | 4 |

---

## 🚀 Executar

Veja quais dispositivos/emuladores estão disponíveis:

```bash
flutter devices
```

Depois rode com:

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# macOS / Windows / Linux
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

---

## ⚠️ Limitações do pacote alarm na Web

O pacote `alarm` usa APIs nativas (Android/iOS) para alarmes confiáveis. Na **web**, os alarmes funcionam apenas enquanto o navegador está aberto. Para produção web, considere usar `flutter_local_notifications` com Service Workers.