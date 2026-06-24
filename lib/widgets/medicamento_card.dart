import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicamento.dart';
import 'urgencia_cores.dart';

/// Card para ListView.builder (mobile) — faixa colorida à esquerda com
/// CircleAvatar, nome + próxima dose à direita, lixeira no canto.
class MedicamentoCardMobile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final urgencia = UrgenciaCores.calcular(medicamento);
    final corFundo = UrgenciaCores.corFundo(urgencia);
    final proxima = _proximaDoseLabel();

    return GestureDetector(
      onTap: onEditar,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: corFundo.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              medicamento.tipo.icone,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          title: Text(
            medicamento.nome,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                'Próxima dose:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
              Text(
                proxima,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Remover',
            onPressed: () => _confirmarRemocao(context),
          ),
        ),
      ),
    );
  }

  String _proximaDoseLabel() {
    final efetivos = medicamento.horariosEfetivos;
    if (efetivos.isEmpty) return '--:--';
    final agora = DateTime.now();
    DateTime? maisProxima;
    Duration menorDelta = const Duration(days: 999);
    for (final h in efetivos) {
      DateTime c = DateTime(
        agora.year,
        agora.month,
        agora.day,
        h.hour,
        h.minute,
      );
      if (c.isBefore(agora)) c = c.add(const Duration(days: 1));
      final d = c.difference(agora).abs();
      if (d < menorDelta) {
        menorDelta = d;
        maisProxima = c;
      }
    }
    return maisProxima != null
        ? DateFormat('HH:mm').format(maisProxima)
        : '--:--';
  }

  void _confirmarRemocao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text('Deseja remover "${medicamento.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemover();
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

/// Card para GridView.builder (web/tablet) — card colorido inteiro,
/// nome grande, "Próxima Dose:" + horário em destaque, lixeira no rodapé.
class MedicamentoCardGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final urgencia = UrgenciaCores.calcular(medicamento);
    final corFundo = UrgenciaCores.corFundo(urgencia);
    final proxima = _proximaDoseLabel();

    return GestureDetector(
      onTap: onEditar,
      child: Container(
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: corFundo.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone do tipo + lixeira no topo
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    medicamento.tipo.icone,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remover',
                  onPressed: () => _confirmarRemocao(context),
                ),
              ],
            ),

            const Spacer(),

            // Nome do medicamento
            Text(
              medicamento.nome,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Label "Próxima Dose:"
            Text(
              'Próxima Dose:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),

            // Horário em destaque + ícone de lixeira alinhado
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  proxima,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.delete_outline,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _proximaDoseLabel() {
    final efetivos = medicamento.horariosEfetivos;
    if (efetivos.isEmpty) return '--:--';
    final agora = DateTime.now();
    DateTime? maisProxima;
    Duration menorDelta = const Duration(days: 999);
    for (final h in efetivos) {
      DateTime c = DateTime(
        agora.year,
        agora.month,
        agora.day,
        h.hour,
        h.minute,
      );
      if (c.isBefore(agora)) c = c.add(const Duration(days: 1));
      final d = c.difference(agora).abs();
      if (d < menorDelta) {
        menorDelta = d;
        maisProxima = c;
      }
    }
    return maisProxima != null
        ? DateFormat('HH:mm').format(maisProxima)
        : '--:--';
  }

  void _confirmarRemocao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text('Deseja remover "${medicamento.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemover();
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
