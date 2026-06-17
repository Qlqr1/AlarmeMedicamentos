import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicamento.dart';

class MedicamentoCard extends StatelessWidget {
  final Medicamento medicamento;
  final VoidCallback onRemover;
  final VoidCallback onToggleAtivo;
  final VoidCallback onEditar;

  const MedicamentoCard({
    super.key,
    required this.medicamento,
    required this.onRemover,
    required this.onToggleAtivo,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horarioFormatado = medicamento.horarios
        .map((h) => DateFormat('HH:mm').format(h))
        .join(' • ');

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Faixa de cor no topo indicando ativo/inativo
          Container(
            height: 4,
            color: medicamento.ativo
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: _buildAvatar(theme),
            title: Text(
              medicamento.nome,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                decoration: medicamento.ativo
                    ? null
                    : TextDecoration.lineThrough,
                color: medicamento.ativo ? null : theme.colorScheme.outline,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.medication,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${medicamento.dosagem} • ${medicamento.tipo.nome}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 14,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      horarioFormatado.isEmpty
                          ? 'Sem horário'
                          : horarioFormatado,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (medicamento.observacoes != null &&
                    medicamento.observacoes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          medicamento.observacoes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: _buildAcoes(context),
            onTap: onEditar,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    // CircleAvatar: exibe imagem se disponível, ou emoji do tipo
    if (medicamento.imagemPath != null && medicamento.imagemPath!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: AssetImage(medicamento.imagemPath!),
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: medicamento.ativo
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Text(medicamento.tipo.icone, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _buildAcoes(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão toggle ativo/inativo
        IconButton(
          icon: Icon(
            medicamento.ativo
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: medicamento.ativo
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          tooltip: medicamento.ativo ? 'Pausar alarme' : 'Ativar alarme',
          onPressed: onToggleAtivo,
        ),
        // Botão lixeira
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          tooltip: 'Remover medicamento',
          onPressed: () => _confirmarRemocao(context),
        ),
      ],
    );
  }

  void _confirmarRemocao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text(
          'Deseja remover "${medicamento.nome}"? '
          'Todos os alarmes associados serão cancelados.',
        ),
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
