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
  late final TextEditingController _observacoesController;

  TipoMedicamento _tipoSelecionado = TipoMedicamento.comprimido;
  ModoAgendamento _modoAgendamento = ModoAgendamento.manual;

  // Modo manual
  final List<DateTime> _horarios = [];

  // Modo ciclo
  DateTime? _primeiraDose;
  int _intervaloHoras = 8;

  bool _salvando = false;
  bool get _editando => widget.medicamentoParaEditar != null;

  // Frequências disponíveis para o dropdown (modo ciclo)
  static const _frequencias = [1, 2, 3, 4, 6, 8, 12, 24];

  @override
  void initState() {
    super.initState();
    final med = widget.medicamentoParaEditar;
    _nomeController = TextEditingController(text: med?.nome ?? '');
    _observacoesController = TextEditingController(
      text: med?.observacoes ?? '',
    );
    if (med != null) {
      _tipoSelecionado = med.tipo;
      _modoAgendamento = med.modoAgendamento;
      _horarios.addAll(med.horarios);
      _primeiraDose = med.primeiraDose;
      _intervaloHoras = med.intervaloHoras ?? 8;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  // ─── Seleção de hora ──────────────────────────────────────────────────────

  Future<void> _selecionarHorario() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Horário da dose',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppCores.longe),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final agora = DateTime.now();
    final dt = DateTime(
      agora.year,
      agora.month,
      agora.day,
      picked.hour,
      picked.minute,
    );

    if (_modoAgendamento == ModoAgendamento.ciclo) {
      setState(() => _primeiraDose = dt);
      return;
    }

    final jaExiste = _horarios.any(
      (h) => h.hour == dt.hour && h.minute == dt.minute,
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
      _horarios.add(dt);
      _horarios.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    });
  }

  // ─── Salvar ───────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação de horários conforme o modo
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
        dosagem: _tipoSelecionado.nome,
        tipo: _tipoSelecionado,
        modoAgendamento: _modoAgendamento,
        horarios: _modoAgendamento == ModoAgendamento.manual ? _horarios : [],
        primeiraDose: _modoAgendamento == ModoAgendamento.ciclo
            ? _primeiraDose
            : null,
        intervaloHoras: _modoAgendamento == ModoAgendamento.ciclo
            ? _intervaloHoras
            : null,
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
            content: Text(
              '${medicamento.nome} ${_editando ? 'atualizado' : 'adicionado'}!',
            ),
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 720;
    final formWidth = isWeb ? 560.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppCores.fundo,
      appBar: AppBar(
        backgroundColor: AppCores.appBar,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Image.asset no topo do formulário, lado direito — igual ao wireframe
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              'assets/images/medicine_banner.png',
              height: 64,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.health_and_safety,
                color: Colors.black,
                size: 48,
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
                  // ── Nome do Medicamento ──────────────────────────────────
                  _labelTexto('Nome do Medicamento:'),
                  const SizedBox(height: 6),
                  _campoTexto(
                    controller: _nomeController,
                    hint: 'Ex: Insulina NPH',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o nome'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // ── Dropdowns lado a lado ────────────────────────────────
                  Row(
                    children: [
                      // Frequência / Modo de agendamento
                      Expanded(child: _dropdownModo()),
                      const SizedBox(width: 12),
                      // Tipo de medicamento
                      Expanded(child: _dropdownTipo()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Seção de horários (modo manual ou ciclo) ─────────────
                  _buildSecaoHorarios(),

                  const SizedBox(height: 20),

                  // ── Informações Extras ───────────────────────────────────
                  _labelTexto('Informações Extras:'),
                  const SizedBox(height: 6),
                  _campoTexto(
                    controller: _observacoesController,
                    hint: 'Ex: Tomar com água, antes das refeições...',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  // ── ElevatedButton Adicionar ─────────────────────────────
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppCores.longe,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _editando ? 'Salvar Alterações' : 'Adicionar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  // ─── Widgets auxiliares ───────────────────────────────────────────────────

  Widget _labelTexto(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xFF37474F),
      ),
    );
  }

  /// TextFormField com fundo verde-claro do wireframe
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  /// DropdownButtonFormField — modo de agendamento (frequência)
  Widget _dropdownModo() {
    return DropdownButtonFormField<ModoAgendamento>(
      value: _modoAgendamento,
      decoration: InputDecoration(
        labelText: 'Frequência utilizado',
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFB2DFDB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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

  /// DropdownButtonFormField — tipo de medicamento
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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
    if (_modoAgendamento == ModoAgendamento.ciclo) {
      return _buildSecaoCiclo();
    }
    return _buildSecaoManual();
  }

  /// Seção modo ciclo: primeira dose + intervalo
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF37474F),
            ),
          ),
          const SizedBox(height: 14),

          // Seletor visual da primeira dose — display estilo digital + relógio
          _buildSeletorHoraVisual(),

          const SizedBox(height: 16),

          // Intervalo entre doses
          Row(
            children: [
              const Text(
                'Repetir a cada',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
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

  /// Seção modo manual: lista de horários adicionados
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F),
                ),
              ),
              TextButton.icon(
                onPressed: _selecionarHorario,
                icon: const Icon(Icons.add_alarm, color: AppCores.longe),
                label: const Text(
                  'Adicionar',
                  style: TextStyle(color: AppCores.longe),
                ),
              ),
            ],
          ),

          // showTimePicker é acionado pelo botão acima
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
                    DateFormat('HH:mm').format(h),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                  onDeleted: () => setState(() => _horarios.remove(h)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Display digital estilo wireframe (00 : 00 com relógio analógico ao lado)
  Widget _buildSeletorHoraVisual() {
    final hora = _primeiraDose != null
        ? DateFormat('HH').format(_primeiraDose!)
        : '--';
    final minuto = _primeiraDose != null
        ? DateFormat('mm').format(_primeiraDose!)
        : '--';

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
            // Display digital
            _digitoDisplay(hora),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                ':',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _digitoDisplay(minuto),

            const SizedBox(width: 20),

            // Ícone de relógio analógico (referência ao showTimePicker)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.watch_later_outlined,
                color: Colors.white,
                size: 30,
              ),
            ),

            const SizedBox(width: 12),

            // Ícone de imagem (câmera) — CircleAvatar decorativo como no wireframe
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(
                Icons.image_outlined,
                color: Colors.white,
                size: 22,
              ),
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
        color: const Color.fromARGB(255, 255, 254, 254).withValues(alpha: 0.2),
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

  /// Chips mostrando as próximas X doses do ciclo
  Widget _chipPreview() {
    if (_primeiraDose == null) return const SizedBox.shrink();

    final doses = <String>[];
    DateTime atual = _primeiraDose!;
    for (int i = 0; i < 4; i++) {
      doses.add(DateFormat('HH:mm').format(atual));
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
              .map(
                (d) => Chip(
                  backgroundColor: const Color.fromARGB(255, 120, 119, 119).withValues(alpha: 0.5),
                  label: Text(
                    d,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
