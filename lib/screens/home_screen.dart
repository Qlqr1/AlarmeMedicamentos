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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Grid apenas em landscape ou telas grandes (web/tablet)
    int gridColunas = 0;
    if (screenWidth >= 1400) {
      gridColunas = 4;
    } else if (screenWidth >= 1000) {
      gridColunas = 3;
    } else if (isLandscape) {
      gridColunas = 3;
    }

    final isGrid = gridColunas > 0;

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

          if (isGrid) {
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColunas,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
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

          // Mobile portrait: ListView
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Image.asset(
            'assets/images/logo.png',
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
            'assets/images/logo.png',
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
