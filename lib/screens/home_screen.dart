import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicamento.dart';
import '../models/medicamentos_provider.dart';
import '../models/alarm_service.dart';
import '../widgets/medicamento_card.dart';
import 'formulario_medicamento.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    // MediaQuery para adaptar layout entre mobile e web/tablet
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 720;
    final isTablet = screenWidth > 480 && screenWidth <= 720;

    // Número de colunas para o GridView na web/tablet
    int gridColunas = 2;
    if (screenWidth > 1200)
      gridColunas = 4;
    else if (screenWidth > 900)
      gridColunas = 3;

    return Scaffold(
      // AppBar com barra de pesquisa integrada
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        title: const _AppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Sobre o app',
            onPressed: () => _mostrarSobre(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildBarraBusca(context),
        ),
      ),

      // Body adaptativo: ListView no mobile, GridView na web/tablet
      body: Consumer<MedicamentosProvider>(
        builder: (context, provider, _) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicamentos = _filtrarMedicamentos(provider.medicamentos);

          if (medicamentos.isEmpty) {
            return _buildEstadoVazio(context, provider.medicamentos.isEmpty);
          }

          if (isWeb || isTablet) {
            // GridView.builder para web e tablet
            return GridView.builder(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColunas,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: medicamentos.length,
              itemBuilder: (context, index) {
                final med = medicamentos[index];
                return _buildCardGrid(context, med, provider);
              },
            );
          }

          // ListView.builder para mobile
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: medicamentos.length,
            itemBuilder: (context, index) {
              final med = medicamentos[index];
              return MedicamentoCard(
                medicamento: med,
                onRemover: () => _removerMedicamento(context, med, provider),
                onToggleAtivo: () => _toggleAtivo(context, med, provider),
                onEditar: () => _abrirFormulario(context, med),
              );
            },
          );
        },
      ),

      // FloatingActionButton para abrir formulário de novo medicamento
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, null),
        icon: const Icon(Icons.add),
        label: Text(isWeb ? 'Novo Medicamento' : 'Novo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  /// Card adaptado para GridView (layout mais compacto)
  Widget _buildCardGrid(
    BuildContext context,
    Medicamento med,
    MedicamentosProvider provider,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirFormulario(context, med),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // CircleAvatar no card da grid
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: med.ativo
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      med.tipo.icone,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const Spacer(),
                  // Icon simples de status
                  Icon(
                    med.ativo
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: med.ativo
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    size: 20,
                  ),
                  // IconButton lixeira
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _removerMedicamento(context, med, provider),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                med.nome,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                med.dosagem,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 12,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${med.horarios.length} alarme${med.horarios.length != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraBusca(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onChanged: (value) => setState(() => _busca = value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar medicamento...',
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: 0.8),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildEstadoVazio(BuildContext context, bool semMedicamentos) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image.asset para o estado vazio (com fallback via errorBuilder)
          Image.asset(
            'assets/images/empty_state.png',
            width: screenWidth * 0.4,
            errorBuilder: (context, error, stackTrace) => Icon(
              semMedicamentos
                  ? Icons.medical_services_outlined
                  : Icons.search_off,
              size: 80,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            semMedicamentos
                ? 'Nenhum medicamento cadastrado'
                : 'Nenhum resultado encontrado',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            semMedicamentos
                ? 'Toque em "Novo" para adicionar\nseu primeiro medicamento'
                : 'Tente uma busca diferente',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (semMedicamentos) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Medicamento'),
            ),
          ],
        ],
      ),
    );
  }

  List<Medicamento> _filtrarMedicamentos(List<Medicamento> todos) {
    if (_busca.trim().isEmpty) return todos;
    final query = _busca.toLowerCase().trim();
    return todos
        .where(
          (m) =>
              m.nome.toLowerCase().contains(query) ||
              m.tipo.nome.toLowerCase().contains(query) ||
              m.dosagem.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _removerMedicamento(
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

  void _mostrarSobre(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Alarme de Medicamentos',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.medical_services, size: 48),
      children: const [
        Text(
          'Gerencie seus medicamentos e nunca esqueça '
          'de tomar uma dose. Configure alarmes personalizados '
          'para cada remédio.',
        ),
      ],
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image.asset no AppBar com fallback
        Image.asset(
          'assets/images/app_logo.png',
          height: 32,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.health_and_safety,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Meus Medicamentos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
