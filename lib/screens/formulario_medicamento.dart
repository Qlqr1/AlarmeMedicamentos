import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/medicamento.dart';
import '../models/medicamentos_provider.dart';
import '../models/alarm_service.dart';
import '../widgets/urgencia_cores.dart';

class FormularioMedicamento extends StatefulWidget {
  final Medicamento? medicamentoParaEditar;

  const FormularioMedicamento({super.key, this.medicamentoParaEditar});

  @override
  State<FormularioMedicamento> createState() => _FormularioMedicamentoState();
}

class _FormularioMedicamentoState extends State<FormularioMedicamento> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _quantidadeController;
  late final TextEditingController _observacoesController;

  static const _unidades = [
    'mg', 'g', 'mcg', 'ml', 'L',
    'comprimido', 'cápsula', 'gota(s)', 'UI', 'aplicação',
  ];
  String _unidade = 'mg';

  TipoMedicamento _tipoSelecionado = TipoMedicamento.comprimido;
  ModoAgendamento _modoAgendamento = ModoAgendamento.manual;

  // Modo manual
  final List<DateTime> _horarios = [];

  // Modo ciclo
  DateTime? _primeiraDose;
  int _intervaloHoras = 8;

  bool _salvando = false;
  bool get _editando => widget.medicamentoParaEditar != null;

  static const _frequencias = [1, 2, 3, 4, 6, 8, 12, 24];

  @override
  void initState() {
    super.initState();
    final med = widget.medicamentoParaEditar;
    _nomeController = TextEditingController(text: med?.nome ?? '');
    _observacoesController = TextEditingController(text: med?.observacoes ?? '');
    // Parseia "50 mg" → quantidade="50", unidade="mg"
    if (med != null) {
      final partes = (med.dosagem).trim().split(' ');
      final qty = partes.isNotEmpty ? partes[0] : '';
      final unit = partes.length > 1 ? partes[1] : 'mg';
      _quantidadeController = TextEditingController(text: qty);
      _unidade = _unidades.contains(unit) ? unit : 'mg';
      _tipoSelecionado = med.tipo;
      _modoAgendamento = med.modoAgendamento;
      _horarios.addAll(med.horarios);
      _primeiraDose = med.primeiraDose;
      _intervaloHoras = med.intervaloHoras ?? 8;
    } else {
      _quantidadeController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _quantidadeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  String _formatarHora(DateTime h) {
    final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
    if (use24) {
      return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    }
    final period = h.hour < 12 ? 'AM' : 'PM';
    final hora = h.hour % 12 == 0 ? 12 : h.hour % 12;
    return '${hora.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _selecionarHorario() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Horário da dose',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );

    if (picked == null || !mounted) return;

    final agora = DateTime.now();
    final dt = DateTime(agora.year, agora.month, agora.day, picked.hour, picked.minute);

    if (_modoAgendamento == ModoAgendamento.ciclo) {
      setState(() => _primeiraDose = dt);
      return;
    }

    final jaExiste = _horarios.any((h) => h.hour == dt.hour && h.minute == dt.minute);
    if (jaExiste) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esse horário já foi adicionado.')),
        );
      }
      return;
    }

    setState(() {
      _horarios.add(dt);
      _horarios.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_modoAgendamento == ModoAgendamento.manual && _horarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um horário.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_modoAgendamento == ModoAgendamento.ciclo && _primeiraDose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o horário da primeira dose.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final provider = context.read<MedicamentosProvider>();
      final alarmId = _editando
          ? widget.medicamentoParaEditar!.alarmId
          : DateTime.now().millisecondsSinceEpoch % 100000;

      final medicamento = Medicamento(
        id: _editando ? widget.medicamentoParaEditar!.id : const Uuid().v4(),
        nome: _nomeController.text.trim(),
        dosagem: _quantidadeController.text.trim().isEmpty
            ? _unidade
            : '${_quantidadeController.text.trim()} $_unidade',
        tipo: _tipoSelecionado,
        modoAgendamento: _modoAgendamento,
        horarios: _modoAgendamento == ModoAgendamento.manual ? _horarios : [],
        primeiraDose: _modoAgendamento == ModoAgendamento.ciclo ? _primeiraDose : null,
        intervaloHoras: _modoAgendamento == ModoAgendamento.ciclo ? _intervaloHoras : null,
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        ativo: true,
        alarmId: alarmId,
      );

      if (_editando) {
        await AlarmService.cancelarAlarmes(widget.medicamentoParaEditar!);
        await provider.atualizarMedicamento(medicamento);
      } else {
        await provider.adicionarMedicamento(medicamento);
      }

      await AlarmService.agendarAlarmes(medicamento);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${medicamento.nome} ${_editando ? 'atualizado' : 'adicionado'}!'),
            backgroundColor: AppCores.longe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 720;
    final formWidth = isWeb ? 560.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppCores.fundo,
      appBar: AppBar(
        backgroundColor: AppCores.appBar,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_editando ? 'Editar Medicamento' : 'Novo Medicamento'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              'assets/images/logo.png',
              height: 48,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.health_and_safety,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? (screenWidth - formWidth) / 2 : 20,
            vertical: 24,
          ),
          child: SizedBox(
            width: formWidth,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _labelTexto('Nome do Medicamento:'),
                  const SizedBox(height: 6),
                  _campoTexto(
                    controller: _nomeController,
                    hint: 'Ex: Insulina NPH',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),

                  const SizedBox(height: 16),

                  _labelTexto('Dosagem:'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Campo numérico
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantidadeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Ex: 50',
                            hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
                            filled: true,
                            fillColor: const Color(0xFFB2DFDB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Informe a quantidade' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Dropdown de unidade
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB2DFDB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _unidade,
                              isExpanded: true,
                              items: _unidades.map((u) {
                                return DropdownMenuItem(
                                  value: u,
                                  child: Text(u, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _unidade = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _dropdownModo()),
                      const SizedBox(width: 12),
                      Expanded(child: _dropdownTipo()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSecaoHorarios(),

                  const SizedBox(height: 20),

                  _labelTexto('Informações Extras:'),
                  const SizedBox(height: 6),
                  _campoTexto(
                    controller: _observacoesController,
                    hint: 'Ex: Tomar com água, antes das refeições...',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppCores.longe,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _editando ? 'Salvar Alterações' : 'Adicionar',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelTexto(String texto) {
    return Text(
      texto,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF37474F)),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
        filled: true,
        fillColor: const Color(0xFFB2DFDB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdownModo() {
    return DropdownButtonFormField<ModoAgendamento>(
      value: _modoAgendamento,
      decoration: InputDecoration(
        labelText: 'Frequência',
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFB2DFDB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(
          value: ModoAgendamento.manual,
          child: Text('Horários fixos', style: TextStyle(fontSize: 13)),
        ),
        DropdownMenuItem(
          value: ModoAgendamento.ciclo,
          child: Text('Por ciclo', style: TextStyle(fontSize: 13)),
        ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _modoAgendamento = v);
      },
    );
  }

  Widget _dropdownTipo() {
    return DropdownButtonFormField<TipoMedicamento>(
      value: _tipoSelecionado,
      decoration: InputDecoration(
        labelText: 'Tipo de Medicamento',
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFB2DFDB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: TipoMedicamento.values.map((tipo) {
        return DropdownMenuItem(
          value: tipo,
          child: Row(
            children: [
              Text(tipo.icone),
              const SizedBox(width: 6),
              Text(tipo.nome, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _tipoSelecionado = v);
      },
    );
  }

  Widget _buildSecaoHorarios() {
    if (_modoAgendamento == ModoAgendamento.ciclo) return _buildSecaoCiclo();
    return _buildSecaoManual();
  }

  Widget _buildSecaoCiclo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB2DFDB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configurar ciclo de doses',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
          ),
          const SizedBox(height: 14),

          _buildSeletorHoraVisual(),

          const SizedBox(height: 16),

          Row(
            children: [
              const Text('Repetir a cada', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _intervaloHoras,
                underline: const SizedBox(),
                items: _frequencias.map((h) {
                  return DropdownMenuItem(
                    value: h,
                    child: Text('$h hora${h > 1 ? 's' : ''}'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _intervaloHoras = v);
                },
              ),
            ],
          ),

          if (_primeiraDose != null) ...[
            const SizedBox(height: 10),
            _chipPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildSeletorHoraVisual() {
    final hora = _primeiraDose != null ? DateFormat('HH').format(_primeiraDose!) : '--';
    final minuto = _primeiraDose != null ? DateFormat('mm').format(_primeiraDose!) : '--';

    return GestureDetector(
      onTap: _selecionarHorario,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppCores.longe,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _digitoDisplay(hora),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),
            _digitoDisplay(minuto),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.watch_later_outlined, color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _digitoDisplay(String valor) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        valor,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _chipPreview() {
    if (_primeiraDose == null) return const SizedBox.shrink();

    final doses = <String>[];
    DateTime atual = _primeiraDose!;
    for (int i = 0; i < 3; i++) {
      doses.add(_formatarHora(atual));
      atual = atual.add(Duration(hours: _intervaloHoras));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximas doses:',
          style: TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: doses
              .map((d) => Chip(
                    backgroundColor: Colors.white.withValues(alpha: 0.5),
                    label: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSecaoManual() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB2DFDB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Horários dos alarmes',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
              ),
              TextButton.icon(
                onPressed: _selecionarHorario,
                icon: const Icon(Icons.add_alarm, color: AppCores.longe),
                label: const Text('Adicionar', style: TextStyle(color: AppCores.longe)),
              ),
            ],
          ),
          if (_horarios.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nenhum horário adicionado',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _horarios.map((h) {
                return Chip(
                  backgroundColor: AppCores.longe,
                  label: Text(
                    _formatarHora(h),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onDeleted: () => setState(() => _horarios.remove(h)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
