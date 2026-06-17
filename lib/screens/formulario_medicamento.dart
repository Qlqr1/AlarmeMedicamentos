import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/medicamento.dart';
import '../models/medicamentos_provider.dart';
import '../models/alarm_service.dart';

class FormularioMedicamento extends StatefulWidget {
  final Medicamento? medicamentoParaEditar;

  const FormularioMedicamento({super.key, this.medicamentoParaEditar});

  @override
  State<FormularioMedicamento> createState() => _FormularioMedicamentoState();
}

class _FormularioMedicamentoState extends State<FormularioMedicamento> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _dosagemController;
  late final TextEditingController _observacoesController;

  TipoMedicamento _tipoSelecionado = TipoMedicamento.comprimido;
  final List<DateTime> _horarios = [];
  bool _salvando = false;

  bool get _editando => widget.medicamentoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medicamentoParaEditar;
    _nomeController = TextEditingController(text: med?.nome ?? '');
    _dosagemController = TextEditingController(text: med?.dosagem ?? '');
    _observacoesController = TextEditingController(
      text: med?.observacoes ?? '',
    );
    if (med != null) {
      _tipoSelecionado = med.tipo;
      _horarios.addAll(med.horarios);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dosagemController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _adicionarHorario() async {
    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Selecione o horário do alarme',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );

    if (horario != null && mounted) {
      final agora = DateTime.now();
      final novoHorario = DateTime(
        agora.year,
        agora.month,
        agora.day,
        horario.hour,
        horario.minute,
      );

      // Verificar duplicatas
      final jaExiste = _horarios.any(
        (h) => h.hour == novoHorario.hour && h.minute == novoHorario.minute,
      );

      if (jaExiste) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Esse horário já foi adicionado.')),
          );
        }
        return;
      }

      setState(() {
        _horarios.add(novoHorario);
        _horarios.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      });
    }
  }

  void _removerHorario(int index) {
    setState(() => _horarios.removeAt(index));
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_horarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um horário de alarme.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final provider = context.read<MedicamentosProvider>();
      final uuid = const Uuid();

      // Gerar alarmId baseado no timestamp para evitar colisões
      final alarmId = _editando
          ? widget.medicamentoParaEditar!.alarmId
          : DateTime.now().millisecondsSinceEpoch % 100000;

      final medicamento = Medicamento(
        id: _editando ? widget.medicamentoParaEditar!.id : uuid.v4(),
        nome: _nomeController.text.trim(),
        dosagem: _dosagemController.text.trim(),
        tipo: _tipoSelecionado,
        horarios: _horarios,
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        ativo: true,
        alarmId: alarmId,
      );

      // Cancelar alarmes anteriores se estiver editando
      if (_editando) {
        await AlarmService.cancelarAlarmes(widget.medicamentoParaEditar!);
        await provider.atualizarMedicamento(medicamento);
      } else {
        await provider.adicionarMedicamento(medicamento);
      }

      // Agendar novos alarmes
      await AlarmService.agendarAlarmes(medicamento);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editando
                  ? '${medicamento.nome} atualizado com sucesso!'
                  : '${medicamento.nome} adicionado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Medicamento' : 'Novo Medicamento'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header decorativo
              _buildHeader(theme),

              const SizedBox(height: 24),

              // Nome do medicamento
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome do medicamento *',
                  hintText: 'Ex: Losartana, Vitamina D...',
                  prefixIcon: const Icon(Icons.medication),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do medicamento';
                  }
                  if (value.trim().length < 2) {
                    return 'Nome muito curto';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Dosagem
              TextFormField(
                controller: _dosagemController,
                decoration: InputDecoration(
                  labelText: 'Dosagem *',
                  hintText: 'Ex: 50mg, 1 comprimido, 5ml...',
                  prefixIcon: const Icon(Icons.science),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe a dosagem';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Tipo de medicamento - DropdownButtonFormField
              DropdownButtonFormField<TipoMedicamento>(
                value: _tipoSelecionado,
                decoration: InputDecoration(
                  labelText: 'Tipo do medicamento *',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                items: TipoMedicamento.values.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Row(
                      children: [
                        Text(tipo.icone, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(tipo.nome),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (tipo) {
                  if (tipo != null) setState(() => _tipoSelecionado = tipo);
                },
                validator: (value) => value == null ? 'Selecione o tipo' : null,
              ),

              const SizedBox(height: 16),

              // Observações
              TextFormField(
                controller: _observacoesController,
                decoration: InputDecoration(
                  labelText: 'Observações (opcional)',
                  hintText: 'Ex: Tomar com água, antes das refeições...',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),

              // Seção de horários
              _buildSecaoHorarios(theme),

              const SizedBox(height: 32),

              // Botão salvar - ElevatedButton
              ElevatedButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_editando ? Icons.save : Icons.add_alarm),
                label: Text(
                  _salvando
                      ? 'Salvando...'
                      : _editando
                      ? 'Salvar Alterações'
                      : 'Adicionar Medicamento',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Image.asset para a imagem decorativa do formulário
          Image.asset(
            'assets/images/medicine_banner.png',
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.health_and_safety,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editando ? 'Editar Medicamento' : 'Cadastrar Medicamento',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preencha os dados e configure os horários dos alarmes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoHorarios(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Horários dos Alarmes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _adicionarHorario,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Adicionar'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (_horarios.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.alarm_off,
                  size: 40,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum horário adicionado',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_horarios.length, (index) {
            final horario = _horarios[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.alarm,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text(
                  DateFormat('HH:mm').format(horario),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                subtitle: Text(
                  'Alarme ${index + 1}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _removerHorario(index),
                  tooltip: 'Remover horário',
                ),
              ),
            );
          }),
      ],
    );
  }
}
