import 'dart:async';
import 'package:flutter/material.dart';
import '../models/medicamento.dart';
import 'urgencia_cores.dart';

String _fmt(BuildContext context, DateTime h) {
  final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
  if (use24) {
    return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  }
  final period = h.hour < 12 ? 'AM' : 'PM';
  final hora = h.hour % 12 == 0 ? 12 : h.hour % 12;
  return '${hora.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')} $period';
}

String _fmtSem(DateTime h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

List<DateTime> _proximos(Medicamento med, {int n = 3}) {
  final agora = DateTime.now();

  if (med.modoAgendamento == ModoAgendamento.ciclo) {
    final base = med.proximaDoseCalculada ?? med.primeiraDose;
    if (base == null || med.intervaloHoras == null) return [];
    var c = base;
    while (!c.isAfter(agora)) {
      c = c.add(Duration(hours: med.intervaloHoras!));
    }
    return List.generate(n, (i) => c.add(Duration(hours: med.intervaloHoras! * i)));
  }

  if (med.horarios.isEmpty) return [];
  final lista = <DateTime>[];
  for (final h in med.horarios) {
    var c = DateTime(agora.year, agora.month, agora.day, h.hour, h.minute);
    if (!c.isAfter(agora)) c = c.add(const Duration(days: 1));
    lista.add(c);
  }
  lista.sort();
  int dia = 1;
  while (lista.length < n) {
    for (final h in med.horarios) {
      lista.add(DateTime(agora.year, agora.month, agora.day + dia, h.hour, h.minute));
      if (lista.length >= n) break;
    }
    dia++;
  }
  lista.sort();
  return lista.take(n).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
/// Card para ListView (mobile)
// ─────────────────────────────────────────────────────────────────────────────
class MedicamentoCardMobile extends StatefulWidget {
  final Medicamento medicamento;
  final VoidCallback onRemover;
  final VoidCallback onToggleAtivo;
  final VoidCallback onEditar;

  const MedicamentoCardMobile({
    super.key,
    required this.medicamento,
    required this.onRemover,
    required this.onToggleAtivo,
    required this.onEditar,
  });

  @override
  State<MedicamentoCardMobile> createState() => _MedicamentoCardMobileState();
}

class _MedicamentoCardMobileState extends State<MedicamentoCardMobile> {
  Timer? _timer;
  Medicamento get med => widget.medicamento;

  @override
  void initState() {
    super.initState();
    _agendarVirada();
  }

  void _agendarVirada() {
    final seg = 60 - DateTime.now().second;
    _timer = Timer(Duration(seconds: seg), () {
      if (mounted) setState(() {});
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgencia = UrgenciaCores.calcular(med);
    final cor = UrgenciaCores.corFundo(urgencia);
    final doses = _proximos(med);

    return GestureDetector(
      onTap: widget.onEditar,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Linha 1: avatar + nome + botões ──────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(med.tipo.icone, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                med.nome,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (med.modoAgendamento == ModoAgendamento.ciclo)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.repeat, color: Colors.white70, size: 15),
                              ),
                          ],
                        ),
                        Text(
                          '${med.dosagem} · ${med.tipo.nome}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botões no canto — apenas ícones pequenos
                  _iconBtn(
                    icon: med.ativo ? Icons.notifications_active : Icons.notifications_off,
                    onTap: widget.onToggleAtivo,
                  ),
                  _iconBtn(
                    icon: Icons.delete_outline,
                    onTap: () => _confirmar(context),
                  ),
                ],
              ),

              // ── Linha 2: chips de horário ─────────────────────────────────
              if (doses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Próximas doses:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (int i = 0; i < doses.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      _chip(context, doses[i], destaque: i == 0),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _chip(BuildContext context, DateTime h, {required bool destaque}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: destaque
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: destaque ? Border.all(color: Colors.white54) : null,
      ),
      child: Text(
        _fmt(context, h),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _confirmar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text('Deseja remover "${med.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRemover();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Card para GridView (web/tablet)
// ─────────────────────────────────────────────────────────────────────────────
class MedicamentoCardGrid extends StatefulWidget {
  final Medicamento medicamento;
  final VoidCallback onRemover;
  final VoidCallback onToggleAtivo;
  final VoidCallback onEditar;

  const MedicamentoCardGrid({
    super.key,
    required this.medicamento,
    required this.onRemover,
    required this.onToggleAtivo,
    required this.onEditar,
  });

  @override
  State<MedicamentoCardGrid> createState() => _MedicamentoCardGridState();
}

class _MedicamentoCardGridState extends State<MedicamentoCardGrid> {
  Timer? _timer;
  Medicamento get med => widget.medicamento;

  @override
  void initState() {
    super.initState();
    _agendarVirada();
  }

  void _agendarVirada() {
    final seg = 60 - DateTime.now().second;
    _timer = Timer(Duration(seconds: seg), () {
      if (mounted) setState(() {});
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgencia = UrgenciaCores.calcular(med);
    final cor = UrgenciaCores.corFundo(urgencia);
    final doses = _proximos(med);
    final proxima = doses.isNotEmpty ? _fmtSem(doses.first) : '--:--';

    return GestureDetector(
      onTap: widget.onEditar,
      child: Container(
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cor.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo: ícone + ações
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(med.tipo.icone, style: const TextStyle(fontSize: 14)),
                ),
                const Spacer(),
                if (med.modoAgendamento == ModoAgendamento.ciclo)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.repeat, color: Colors.white70, size: 14),
                  ),
                GestureDetector(
                  onTap: () => _confirmar(context),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                ),
              ],
            ),
            const Spacer(),
            // Nome
            Text(
              med.nome,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Próxima dose
            Text(
              'Próxima',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
            ),
            Text(
              proxima,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text('Deseja remover "${med.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRemover();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
