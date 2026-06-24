import 'package:alarm/alarm.dart';
import '../models/medicamento.dart';

class AlarmService {
  static Future<void> inicializar() async {
    await Alarm.init();
  }

  /// Agenda o(s) alarme(s) de um medicamento, de acordo com o modo:
  /// - manual: um alarme fixo por horário da lista.
  /// - ciclo: um único alarme para a PRÓXIMA dose. Quando ele disparar,
  ///   [reagendarProximoCiclo] deve ser chamado para calcular e agendar
  ///   a dose seguinte, substituindo a anterior.
  static Future<void> agendarAlarmes(Medicamento medicamento) async {
    if (!medicamento.ativo) return;

    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      await _agendarProximaDoseDoCiclo(medicamento);
      return;
    }

    // Modo manual: um alarme por horário, todos com IDs derivados
    // de alarmId + índice, como antes.
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

  /// Agenda apenas a próxima dose do ciclo (sempre no [medicamento.alarmId],
  /// já que no modo ciclo só existe UM alarme "vivo" por vez).
  static Future<void> _agendarProximaDoseDoCiclo(
    Medicamento medicamento,
  ) async {
    final proxima =
        medicamento.proximaDoseCalculada ?? medicamento.primeiraDose!;

    // Se a dose calculada já passou (app ficou fechado por um tempo),
    // avança o ciclo quantas vezes forem necessárias até achar uma
    // data futura, em vez de disparar várias notificações atrasadas.
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

  /// Chamar quando o alarme de um medicamento em modo ciclo dispara
  /// (ou quando a pessoa toca "Tomei"/"Dispensar" na notificação).
  ///
  /// Calcula a próxima dose a partir da que acabou de disparar e
  /// AGENDA NO LUGAR DELA — não acumula alarmes, sempre existe só
  /// um próximo, exatamente como descrito: "salva a última dosagem
  /// e vai adicionando o tempo para criar a próxima, substituindo
  /// a anterior".
  ///
  /// Retorna o medicamento atualizado com a nova [proximaDoseCalculada]
  /// — quem chamar deve persistir esse retorno no provider.
  static Future<Medicamento> reagendarProximoCiclo(
    Medicamento medicamento,
  ) async {
    if (medicamento.modoAgendamento != ModoAgendamento.ciclo) {
      return medicamento;
    }

    // Para o alarme atual antes de criar o próximo (mesmo ID será
    // reutilizado, mas isso garante que não fique nada "pendurado"
    // em plataformas que não sobrescrevem automaticamente).
    await Alarm.stop(medicamento.alarmId);

    final doseAnterior =
        medicamento.proximaDoseCalculada ?? medicamento.primeiraDose!;
    final proximaDose = medicamento.calcularProximaDose(
      aPartirDe: doseAnterior,
    );

    final atualizado = medicamento.copyWith(proximaDoseCalculada: proximaDose);

    await _criarAlarme(
      id: atualizado.alarmId,
      dateTime: proximaDose,
      medicamento: atualizado,
    );

    return atualizado;
  }

  /// Cancela todos os alarmes de um medicamento (manual ou ciclo).
  static Future<void> cancelarAlarmes(Medicamento medicamento) async {
    if (medicamento.modoAgendamento == ModoAgendamento.ciclo) {
      await Alarm.stop(medicamento.alarmId);
      return;
    }
    for (int i = 0; i < medicamento.horarios.length; i++) {
      final alarmId = medicamento.alarmId + i;
      await Alarm.stop(alarmId);
    }
  }

  /// Calcula o próximo disparo diário a partir de um horário (modo manual).
  static DateTime _proximoDisparoDiario(DateTime horario) {
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

  /// Para o alarme que está tocando agora.
  static Future<void> dispensarAlarme(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  /// Verifica se um alarme está ativo.
  static Future<bool> alarmEstaAtivo(int alarmId) async {
    return Alarm.getAlarm(alarmId) != null;
  }
}
