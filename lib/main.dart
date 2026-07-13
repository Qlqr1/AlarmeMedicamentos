import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // Para detectar se está rodando no Chrome
import 'dart:io' show Platform; // Para detectar sistemas operacionais desktop/mobile
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:alarm/alarm.dart';
import 'package:provider/provider.dart';
import 'package:local_notifier/local_notifier.dart';
import 'models/medicamento.dart';
import 'models/medicamentos_provider.dart';
import 'models/alarm_service.dart';
import 'screens/home_screen.dart';

// Importação condicional para evitar erros de compilação em plataformas móveis
import 'dart:html' as html if (dart.library.io) 'package:meta/meta.dart'; 

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permissões exclusivas para dispositivos móveis físicos
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  // Inicialização do plugin de notificações nativas para o Windows Desktop
  if (!kIsWeb && Platform.isWindows) {
    await localNotifier.setup(
      appName: 'DSDM Alarmes Medicamentos',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  // Solicitação de permissão para notificações push nativas no Google Chrome / Web
  if (kIsWeb) {
    try {
      if (html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de notificação na Web: $e');
    }
  }

  AlarmService.navigatorKey = navigatorKey;
  await AlarmService.inicializar();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MedicamentosProvider(),
      child: AlarmesMedicamentosApp(navigatorKey: navigatorKey),
    ),
  );
}

class AlarmesMedicamentosApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const AlarmesMedicamentosApp({super.key, required this.navigatorKey});

  @override
  State<AlarmesMedicamentosApp> createState() => _AlarmesMedicamentosAppState();
}

class _AlarmesMedicamentosAppState extends State<AlarmesMedicamentosApp> {
  StreamSubscription<AlarmSettings>? _ringSubscription;

  @override
  void initState() {
    super.initState();
    _ringSubscription = Alarm.ringStream.stream.listen(_aoDispararAlarme);
  }

  @override
  void dispose() {
    _ringSubscription?.cancel();
    super.dispose();
  }

  void _aoDispararAlarme(AlarmSettings alarmSettings) {
    final provider = context.read<MedicamentosProvider>();
    final medicamento = provider.buscarPorAlarmId(alarmSettings.id);

    if (medicamento == null) return;

    // --- EXECUÇÃO DOS ALERTAS POR PLATAFORMA ---
    
    if (kIsWeb) {
      // Dispara o balão de alerta nativo do navegador Chrome
      if (html.Notification.permission == 'granted') {
        html.Notification(
          "Hora do Medicamento! ⏰",
          body: "Está na hora de tomar: ${medicamento.nome}",
        );
      }
    } else if (Platform.isWindows) {
      // Dispara o banner de notificação do Windows 10/11
      final LocalNotification notification = LocalNotification(
        title: "Hora do Medicamento! ⏰",
        body: "Está na hora de tomar: ${medicamento.nome}",
        silent: false, // Emite o som padrão de notificação do Windows
      );
      notification.show();
    }

    // Só medicamentos em modo ciclo precisam de reagendamento automático
    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      provider.confirmarDoseDoCiclo(medicamento.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'Alarme de Medicamentos',
      debugShowCheckedModeBanner: false,
      
      // --- SEU TEMA CLARO CUSTOMIZADO ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
          primary: const Color(0xFF5BBDB5),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFB2E8E4),
          onPrimaryContainer: const Color(0xFF00413C),
          secondary: const Color(0xFFF08A7A),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFFD5CF),
          onSecondaryContainer: const Color(0xFF5C1A10),
          tertiary: const Color(0xFF3DAD9F),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFA8DDD9),
          onTertiaryContainer: const Color(0xFF00332E),
          error: const Color(0xFFE53935),
          onError: Colors.white,
          errorContainer: const Color(0xFFFFDAD6),
          onErrorContainer: const Color(0xFF93000A),
          surface: const Color(0xFFF5FDFC),
          onSurface: const Color(0xFF1A1C1C),
          outline: const Color(0xFF6F9996),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEEFAF9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5BBDB5), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      
      // --- SEU TEMA ESCURO CUSTOMIZADO ---
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF7ED8D0),
          onPrimary: Color(0xFF00332E),
          primaryContainer: Color(0xFF3DAD9F),
          onPrimaryContainer: Color(0xFFB2E8E4),
          secondary: Color(0xFFFFB3A7),
          onSecondary: Color(0xFF5C1A10),
          secondaryContainer: Color(0xFFBF5A4A),
          onSecondaryContainer: Color(0xFFFFD5CF),
          tertiary: Color(0xFF7ED8D0),
          onTertiary: Color(0xFF00332E),
          tertiaryContainer: Color(0xFF1F7A72),
          onTertiaryContainer: Color(0xFFA8DDD9),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000A),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF0E1514),
          onSurface: Color(0xFFDCE4E3),
          outline: Color(0xFF4D7A77),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
