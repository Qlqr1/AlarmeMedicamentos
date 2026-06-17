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

class Medicamento {
  final String id;
  final String nome;
  final String dosagem;
  final TipoMedicamento tipo;
  final List<DateTime> horarios;
  final String? observacoes;
  final String? imagemPath;
  final bool ativo;
  final int alarmId;

  Medicamento({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.tipo,
    required this.horarios,
    this.observacoes,
    this.imagemPath,
    this.ativo = true,
    required this.alarmId,
  });

  Medicamento copyWith({
    String? id,
    String? nome,
    String? dosagem,
    TipoMedicamento? tipo,
    List<DateTime>? horarios,
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
      horarios: horarios ?? this.horarios,
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
      'horarios': horarios.map((h) => h.toIso8601String()).toList(),
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
      horarios: (json['horarios'] as List<dynamic>)
          .map((h) => DateTime.parse(h as String))
          .toList(),
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
