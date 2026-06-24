import 'package:flutter/material.dart';
import '../models/medicamento.dart';

/// Paleta extraída do wireframe
class AppCores {
  // Teal/verde — dose longe (> 2h)
  static const longe = Color(0xFF4DB6AC);
  static const longeTexto = Colors.white;

  // Laranja/salmão — dose próxima (30min – 2h)
  static const proximo = Color(0xFFFF8A65);
  static const proximoTexto = Colors.white;

  // Rosa/vermelho — dose iminente ou atrasada (< 30min ou já passou)
  static const iminente = Color(0xFFE57373);
  static const iminenteTexto = Colors.white;

  // Fundo geral do app (teal claro do wireframe)
  static const fundo = Color(0xFFE0F2F1);

  // AppBar
  static const appBar = Color(0xFF26A69A);
  static const appBarTexto = Colors.white;
}

enum NivelUrgencia { longe, proximo, iminente }

class UrgenciaCores {
  /// Calcula o nível de urgência com base na próxima dose do medicamento.
  static NivelUrgencia calcular(Medicamento med) {
    if (!med.ativo) return NivelUrgencia.longe;

    final proximas = med.horariosEfetivos;
    if (proximas.isEmpty) return NivelUrgencia.longe;

    final agora = DateTime.now();

    // Pega o horário mais próximo (o menor delta positivo ou negativo)
    DateTime? maisProxima;
    Duration menorDelta = const Duration(days: 999);

    for (final h in proximas) {
      // Recria o horário como hoje, amanhã se já passou
      DateTime candidato = DateTime(
        agora.year,
        agora.month,
        agora.day,
        h.hour,
        h.minute,
      );
      if (candidato.isBefore(agora)) {
        candidato = candidato.add(const Duration(days: 1));
      }
      final delta = candidato.difference(agora).abs();
      if (delta < menorDelta) {
        menorDelta = delta;
        maisProxima = candidato;
      }
    }

    if (maisProxima == null) return NivelUrgencia.longe;

    final minutos = maisProxima.difference(agora).inMinutes;

    if (minutos < 0) return NivelUrgencia.iminente; // atrasada
    if (minutos <= 30) return NivelUrgencia.iminente; // < 30min
    if (minutos <= 120) return NivelUrgencia.proximo; // 30min – 2h
    return NivelUrgencia.longe; // > 2h
  }

  static Color corFundo(NivelUrgencia nivel) {
    switch (nivel) {
      case NivelUrgencia.longe:
        return AppCores.longe;
      case NivelUrgencia.proximo:
        return AppCores.proximo;
      case NivelUrgencia.iminente:
        return AppCores.iminente;
    }
  }

  static Color corTexto(NivelUrgencia nivel) {
    return Colors.white;
  }
}
