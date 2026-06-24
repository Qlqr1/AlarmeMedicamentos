import 'dart:convert';

enum TipoMedicamento {
  comprimido,
  capsula,
  liquido,
  injecao,
  pomada,
  gotas,
  outro,
}

extension TipoMedicamentoExt on TipoMedicamento {
  String get nome {
    switch (this) {
      case TipoMedicamento.comprimido:
        return 'Comprimido';
      case TipoMedicamento.capsula:
        return 'Cápsula';
      case TipoMedicamento.liquido:
        return 'Líquido';
      case TipoMedicamento.injecao:
        return 'Injeção';
      case TipoMedicamento.pomada:
        return 'Pomada';
      case TipoMedicamento.gotas:
        return 'Gotas';
      case TipoMedicamento.outro:
        return 'Outro';
    }
  }

  String get icone {
    switch (this) {
      case TipoMedicamento.comprimido:
        return '💊';
      case TipoMedicamento.capsula:
        return '💊';
      case TipoMedicamento.liquido:
        return '🧴';
      case TipoMedicamento.injecao:
        return '💉';
      case TipoMedicamento.pomada:
        return '🧪';
      case TipoMedicamento.gotas:
        return '💧';
      case TipoMedicamento.outro:
        return '🏥';
    }
  }
}

/// Como os horários de dose são definidos para este medicamento.
enum ModoAgendamento {
  /// Ciclo automático: primeira dose + intervalo em horas.
  /// O app calcula a próxima dose sozinho (rolling), sem precisar
  /// de uma lista fixa de horários por dia.
  ciclo,

  /// Lista de horários fixos escolhidos manualmente (modo antigo).
  manual,
}

class Medicamento {
  final String id;
  final String nome;
  final String dosagem;
  final TipoMedicamento tipo;

  final ModoAgendamento modoAgendamento;

  /// Usado quando [modoAgendamento] == manual.
  final List<DateTime> horarios;

  /// Usado quando [modoAgendamento] == ciclo.
  /// Horário (apenas hora/minuto) da primeira dose já tomada/agendada.
  final DateTime? primeiraDose;

  /// Usado quando [modoAgendamento] == ciclo.
  /// Intervalo, em horas, entre uma dose e a próxima.
  final int? intervaloHoras;

  /// Armazena a próxima dose já calculada, para não recalcular
  /// a cada leitura e para manter o "rolling" consistente mesmo
  /// se o app ficar fechado por vários ciclos.
  final DateTime? proximaDoseCalculada;

  final String? observacoes;
  final String? imagemPath;
  final bool ativo;
  final int alarmId;

  Medicamento({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.tipo,
    this.modoAgendamento = ModoAgendamento.manual,
    this.horarios = const [],
    this.primeiraDose,
    this.intervaloHoras,
    this.proximaDoseCalculada,
    this.observacoes,
    this.imagemPath,
    this.ativo = true,
    required this.alarmId,
  }) : assert(
         modoAgendamento == ModoAgendamento.manual
             ? horarios.isNotEmpty
             : (primeiraDose != null && intervaloHoras != null),
         'Modo manual requer horarios; modo ciclo requer primeiraDose e intervaloHoras.',
       );

  /// Retorna a lista de horários "ativos" independente do modo.
  /// No modo ciclo, retorna uma lista com 1 item: a próxima dose.
  /// Isso permite que telas que só sabem lidar com "horários"
  /// continuem funcionando sem precisar saber o modo.
  List<DateTime> get horariosEfetivos {
    if (modoAgendamento == ModoAgendamento.manual) return horarios;
    final proxima = proximaDoseCalculada ?? primeiraDose;
    return proxima != null ? [proxima] : [];
  }

  /// Calcula a próxima dose a partir de uma referência (a dose anterior).
  /// Usado pelo AlarmService para "substituir" o alarme que acabou de
  /// disparar pelo próximo do ciclo, sem resetar à meia-noite.
  DateTime calcularProximaDose({DateTime? aPartirDe}) {
    if (modoAgendamento != ModoAgendamento.ciclo || intervaloHoras == null) {
      throw StateError('calcularProximaDose só é válido no modo ciclo.');
    }
    final base = aPartirDe ?? proximaDoseCalculada ?? primeiraDose!;
    return base.add(Duration(hours: intervaloHoras!));
  }

  Medicamento copyWith({
    String? id,
    String? nome,
    String? dosagem,
    TipoMedicamento? tipo,
    ModoAgendamento? modoAgendamento,
    List<DateTime>? horarios,
    DateTime? primeiraDose,
    int? intervaloHoras,
    DateTime? proximaDoseCalculada,
    bool limparProximaDoseCalculada = false,
    String? observacoes,
    String? imagemPath,
    bool? ativo,
    int? alarmId,
  }) {
    return Medicamento(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dosagem: dosagem ?? this.dosagem,
      tipo: tipo ?? this.tipo,
      modoAgendamento: modoAgendamento ?? this.modoAgendamento,
      horarios: horarios ?? this.horarios,
      primeiraDose: primeiraDose ?? this.primeiraDose,
      intervaloHoras: intervaloHoras ?? this.intervaloHoras,
      proximaDoseCalculada: limparProximaDoseCalculada
          ? null
          : (proximaDoseCalculada ?? this.proximaDoseCalculada),
      observacoes: observacoes ?? this.observacoes,
      imagemPath: imagemPath ?? this.imagemPath,
      ativo: ativo ?? this.ativo,
      alarmId: alarmId ?? this.alarmId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'dosagem': dosagem,
      'tipo': tipo.index,
      'modoAgendamento': modoAgendamento.index,
      'horarios': horarios.map((h) => h.toIso8601String()).toList(),
      'primeiraDose': primeiraDose?.toIso8601String(),
      'intervaloHoras': intervaloHoras,
      'proximaDoseCalculada': proximaDoseCalculada?.toIso8601String(),
      'observacoes': observacoes,
      'imagemPath': imagemPath,
      'ativo': ativo,
      'alarmId': alarmId,
    };
  }

  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'] as String,
      nome: json['nome'] as String,
      dosagem: json['dosagem'] as String,
      tipo: TipoMedicamento.values[json['tipo'] as int],
      // Compatibilidade com dados salvos antes da feature de ciclo:
      // se não existir o campo, assume modo manual.
      modoAgendamento: json['modoAgendamento'] != null
          ? ModoAgendamento.values[json['modoAgendamento'] as int]
          : ModoAgendamento.manual,
      horarios: (json['horarios'] as List<dynamic>? ?? [])
          .map((h) => DateTime.parse(h as String))
          .toList(),
      primeiraDose: json['primeiraDose'] != null
          ? DateTime.parse(json['primeiraDose'] as String)
          : null,
      intervaloHoras: json['intervaloHoras'] as int?,
      proximaDoseCalculada: json['proximaDoseCalculada'] != null
          ? DateTime.parse(json['proximaDoseCalculada'] as String)
          : null,
      observacoes: json['observacoes'] as String?,
      imagemPath: json['imagemPath'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      alarmId: json['alarmId'] as int,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Medicamento.fromJsonString(String jsonString) =>
      Medicamento.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
