import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:provider/provider.dart';
import 'models/medicamento.dart';
import 'models/medicamentos_provider.dart';
import 'models/alarm_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o serviço de alarmes
  await AlarmService.inicializar();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MedicamentosProvider(),
      child: const AlarmesMedicamentosApp(),
    ),
  );
}

class AlarmesMedicamentosApp extends StatefulWidget {
  const AlarmesMedicamentosApp({super.key});

  @override
  State<AlarmesMedicamentosApp> createState() => _AlarmesMedicamentosAppState();
}

class _AlarmesMedicamentosAppState extends State<AlarmesMedicamentosApp> {
  StreamSubscription<AlarmSettings>? _ringSubscription;

  @override
  void initState() {
    super.initState();
    // Escuta os disparos de alarme durante toda a vida do app. Quando um
    // medicamento em modo "ciclo" dispara, calculamos e agendamos a
    // próxima dose automaticamente, substituindo a anterior — é aqui
    // que o "rolling" descrito pelo usuário acontece de fato.
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

    // Só medicamentos em modo ciclo precisam de reagendamento automático;
    // o modo manual já tem todos os horários fixos definidos.
    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      provider.confirmarDoseDoCiclo(medicamento.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarme de Medicamentos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
