import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alarm_impl/web_notifier.dart';
import 'medicamento.dart';
import 'medicamentos_provider.dart';

class AlarmService {
  static GlobalKey<NavigatorState>? navigatorKey;

  // Só usados na Web, onde o pacote `alarm` não tem implementação: um
  // Timer por alarme dispara o som (via audioplayers) e uma notificação
  // real do navegador quando a aba está aberta.
  static final Map<int, Timer> _webTimers = {};
  static final AudioPlayer _webPlayer = AudioPlayer();

  static Future<void> inicializar() async {
    if (kIsWeb) {
      await WebNotifier.requestPermission();
      return;
    }
    await Alarm.init();
  }

  static Future<void> agendarAlarmes(Medicamento medicamento) async {
    if (!medicamento.ativo) return;

    if (kIsWeb) {
      await _agendarAlarmesWeb(medicamento);
      return;
    }

    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      await _agendarProximaDoseDoCiclo(medicamento);
      return;
    }

    for (int i = 0; i < medicamento.horarios.length; i++) {
      final horario = medicamento.horarios[i];
      final alarmId = medicamento.alarmId + i;
      final proximoDisparo = _proximoDisparoDiario(horario);
      await _criarAlarme(
        id: alarmId,
        dateTime: proximoDisparo,
        medicamento: medicamento,
      );
    }
  }

  static Future<void> _agendarProximaDoseDoCiclo(
    Medicamento medicamento,
  ) async {
    final proxima =
        medicamento.proximaDoseCalculada ?? medicamento.primeiraDose!;

    DateTime alvo = proxima;
    final agora = DateTime.now();
    while (alvo.isBefore(agora)) {
      alvo = alvo.add(Duration(hours: medicamento.intervaloHoras!));
    }

    await _criarAlarme(
      id: medicamento.alarmId,
      dateTime: alvo,
      medicamento: medicamento,
    );
  }

  static Future<void> _criarAlarme({
    required int id,
    required DateTime dateTime,
    required Medicamento medicamento,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 0.0,
      notificationSettings: const NotificationSettings(
        title: 'Alarme de Medicamento',
        body: 'Hora de tomar seu medicamento!',
        stopButton: 'Dispensar',
        icon: 'ic_launcher',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
    // ignore: avoid_print
    print('[AlarmService] Alarme $id agendado para $dateTime');
  }

  static Future<Medicamento> reagendarProximoCiclo(
    Medicamento medicamento,
  ) async {
    if (medicamento.modoAgendamento != ModoAgendamento.ciclo) {
      return medicamento;
    }

    if (kIsWeb) {
      _webTimers.remove(medicamento.alarmId)?.cancel();
    } else {
      await Alarm.stop(medicamento.alarmId);
    }

    final doseAnterior =
        medicamento.proximaDoseCalculada ?? medicamento.primeiraDose!;
    final proximaDose = medicamento.calcularProximaDose(
      aPartirDe: doseAnterior,
    );

    final atualizado = medicamento.copyWith(proximaDoseCalculada: proximaDose);

    if (kIsWeb) {
      _agendarTimerWeb(
        id: atualizado.alarmId,
        dateTime: proximaDose,
        medicamento: atualizado,
      );
    } else {
      await _criarAlarme(
        id: atualizado.alarmId,
        dateTime: proximaDose,
        medicamento: atualizado,
      );
    }

    return atualizado;
  }

  static Future<void> cancelarAlarmes(Medicamento medicamento) async {
    if (kIsWeb) {
      if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
        _webTimers.remove(medicamento.alarmId)?.cancel();
      } else {
        for (int i = 0; i < medicamento.horarios.length; i++) {
          _webTimers.remove(medicamento.alarmId + i)?.cancel();
        }
      }
      return;
    }
    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      await Alarm.stop(medicamento.alarmId);
      return;
    }
    for (int i = 0; i < medicamento.horarios.length; i++) {
      await Alarm.stop(medicamento.alarmId + i);
    }
  }

  static DateTime _proximoDisparoDiario(DateTime horario) {
    final agora = DateTime.now();
    DateTime candidato = DateTime(
      agora.year, agora.month, agora.day, horario.hour, horario.minute, 0,
    );
    if (candidato.isBefore(agora)) {
      candidato = candidato.add(const Duration(days: 1));
    }
    return candidato;
  }

  static Future<void> dispensarAlarme(int alarmId) async {
    if (kIsWeb) {
      _webTimers.remove(alarmId)?.cancel();
      await _webPlayer.stop();
      return;
    }
    await Alarm.stop(alarmId);
  }

  static Future<bool> alarmEstaAtivo(int alarmId) async {
    if (kIsWeb) return _webTimers.containsKey(alarmId);
    return Alarm.getAlarm(alarmId) is AlarmSettings;
  }

  // --- Implementação Web: Timer + audioplayers + Notification API ---

  static Future<void> _agendarAlarmesWeb(Medicamento medicamento) async {
    await WebNotifier.requestPermission();

    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      final proxima =
          medicamento.proximaDoseCalculada ?? medicamento.primeiraDose!;
      DateTime alvo = proxima;
      final agora = DateTime.now();
      while (alvo.isBefore(agora)) {
        alvo = alvo.add(Duration(hours: medicamento.intervaloHoras!));
      }
      _agendarTimerWeb(
        id: medicamento.alarmId,
        dateTime: alvo,
        medicamento: medicamento,
      );
      return;
    }

    for (int i = 0; i < medicamento.horarios.length; i++) {
      final alarmId = medicamento.alarmId + i;
      final proximoDisparo = _proximoDisparoDiario(medicamento.horarios[i]);
      _agendarTimerWeb(
        id: alarmId,
        dateTime: proximoDisparo,
        medicamento: medicamento,
      );
    }
  }

  static void _agendarTimerWeb({
    required int id,
    required DateTime dateTime,
    required Medicamento medicamento,
  }) {
    _webTimers.remove(id)?.cancel();
    final espera = dateTime.difference(DateTime.now());
    _webTimers[id] = Timer(espera.isNegative ? Duration.zero : espera, () {
      _dispararAlarmeWeb(id: id, medicamento: medicamento);
    });
    // ignore: avoid_print
    print('[AlarmService] (web) Alarme $id agendado para $dateTime');
  }

  static Future<void> _dispararAlarmeWeb({
    required int id,
    required Medicamento medicamento,
  }) async {
    _webTimers.remove(id);

    try {
      await _webPlayer.play(AssetSource('alarm.mp3'));
    } catch (_) {}

    WebNotifier.mostrar(
      '💊 ${medicamento.nome}',
      '${medicamento.dosagem} — Hora de tomar seu medicamento!',
    );

    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;

    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      ctx.read<MedicamentosProvider>().confirmarDoseDoCiclo(medicamento.id);
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 2),
        backgroundColor: const Color(0xFF5BBDB5),
        content: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '💊 ${medicamento.nome} — ${medicamento.dosagem}\nHora de tomar seu medicamento!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Dispensar',
          textColor: Colors.white,
          onPressed: () => _webPlayer.stop(),
        ),
      ),
    );
  }
}
