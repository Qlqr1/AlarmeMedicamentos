import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicamento.dart';
import '../models/medicamentos_provider.dart';
import '../models/alarm_service.dart';
import '../widgets/medicamento_card.dart';
import '../widgets/urgencia_cores.dart';
import 'formulario_medicamento.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 720;

    int gridColunas = 2;
    if (screenWidth > 1200)
      gridColunas = 4;
    else if (screenWidth > 900)
      gridColunas = 3;

    return Scaffold(
      backgroundColor: AppCores.fundo,
      appBar: _buildAppBar(context),
      body: Consumer<MedicamentosProvider>(
        builder: (context, provider, _) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicamentos = provider.medicamentos;

          if (medicamentos.isEmpty) {
            return _buildEstadoVazio(context);
          }

          if (isWeb) {
            return GridView.builder(
              padding: EdgeInsets.all(screenWidth > 900 ? 24 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColunas,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemCount: medicamentos.length,
              itemBuilder: (context, index) {
                final med = medicamentos[index];
                return MedicamentoCardGrid(
                  medicamento: med,
                  onRemover: () => _remover(context, med, provider),
                  onToggleAtivo: () => _toggleAtivo(context, med, provider),
                  onEditar: () => _abrirFormulario(context, med),
                );
              },
            );
          }

          // Mobile: ListView
          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 100),
            itemCount: medicamentos.length,
            itemBuilder: (context, index) {
              final med = medicamentos[index];
              return MedicamentoCardMobile(
                medicamento: med,
                onRemover: () => _remover(context, med, provider),
                onToggleAtivo: () => _toggleAtivo(context, med, provider),
                onEditar: () => _abrirFormulario(context, med),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(context, null),
        backgroundColor: AppCores.longe,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AppBar(
      backgroundColor: AppCores.appBar,
      elevation: 0,
      toolbarHeight: 80,
      title: const Text(
        'Meus Medicamentos',
        style: TextStyle(
          color: AppCores.appBarTexto,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      // Image.asset no lado direito do AppBar — imagem decorativa do wireframe
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Image.asset(
            'assets/images/medicine_banner.png',
            height: 64,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.health_and_safety,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoVazio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_state.png',
            width: 160,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.medical_services_outlined,
              size: 80,
              color: AppCores.longe,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum medicamento cadastrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF546E7A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque em + para adicionar o primeiro',
            style: TextStyle(color: Color(0xFF78909C)),
          ),
        ],
      ),
    );
  }

  Future<void> _remover(
    BuildContext context,
    Medicamento med,
    MedicamentosProvider provider,
  ) async {
    await AlarmService.cancelarAlarmes(med);
    await provider.removerMedicamento(med.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${med.nome} removido.')));
    }
  }

  Future<void> _toggleAtivo(
    BuildContext context,
    Medicamento med,
    MedicamentosProvider provider,
  ) async {
    if (med.ativo) {
      await AlarmService.cancelarAlarmes(med);
    } else {
      await AlarmService.agendarAlarmes(med.copyWith(ativo: true));
    }
    await provider.toggleAtivo(med.id);
  }

  void _abrirFormulario(BuildContext context, Medicamento? med) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormularioMedicamento(medicamentoParaEditar: med),
      ),
    );
  }
}
