import 'package:alarm/alarm.dart';
import '../models/medicamento.dart';

class AlarmService {
  static Future<void> inicializar() async {
    await Alarm.init();
  }

  /// Agenda todos os horários de um medicamento para hoje e amanhã
  static Future<void> agendarAlarmes(Medicamento medicamento) async {
    if (!medicamento.ativo) return;

    for (int i = 0; i < medicamento.horarios.length; i++) {
      final horario = medicamento.horarios[i];
      final alarmId = medicamento.alarmId + i;

      DateTime proximoDisparo = _proximoDisparo(horario);

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: proximoDisparo,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volume: 0.8,
        fadeDuration: 3.0,
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: '💊 ${medicamento.nome}',
          body: '${medicamento.dosagem} — Hora de tomar seu medicamento!',
          stopButton: 'Dispensar',
          icon: 'notification_icon',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
    }
  }

  /// Cancela todos os alarmes de um medicamento
  static Future<void> cancelarAlarmes(Medicamento medicamento) async {
    for (int i = 0; i < medicamento.horarios.length; i++) {
      final alarmId = medicamento.alarmId + i;
      await Alarm.stop(alarmId);
    }
  }

  /// Calcula o próximo disparo a partir de um horário
  static DateTime _proximoDisparo(DateTime horario) {
    final agora = DateTime.now();
    DateTime candidato = DateTime(
      agora.year,
      agora.month,
      agora.day,
      horario.hour,
      horario.minute,
      0,
    );

    if (candidato.isBefore(agora)) {
      candidato = candidato.add(const Duration(days: 1));
    }

    return candidato;
  }

  /// Para o alarme que está tocando agora
  static Future<void> dispensarAlarme(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  /// Verifica se um alarme está ativo
  static Future<bool> alarmEstaAtivo(int alarmId) async {
    return Alarm.getAlarm(alarmId) != null;
  }
}
