import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicamento.dart';

class MedicamentosProvider extends ChangeNotifier {
  static const String _storageKey = 'medicamentos';

  List<Medicamento> _medicamentos = [];
  bool _carregando = false;

  List<Medicamento> get medicamentos => List.unmodifiable(_medicamentos);
  bool get carregando => _carregando;

  MedicamentosProvider() {
    _carregarMedicamentos();
  }

  Future<void> _carregarMedicamentos() async {
    _carregando = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_storageKey) ?? [];
      _medicamentos = lista
          .map((json) => Medicamento.fromJsonString(json))
          .toList();
    } catch (e) {
      _medicamentos = [];
    }

    _carregando = false;
    notifyListeners();
  }

  Future<void> _salvarMedicamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _medicamentos.map((m) => m.toJsonString()).toList();
    await prefs.setStringList(_storageKey, lista);
  }

  Future<void> adicionarMedicamento(Medicamento medicamento) async {
    _medicamentos.add(medicamento);
    await _salvarMedicamentos();
    notifyListeners();
  }

  Future<void> removerMedicamento(String id) async {
    _medicamentos.removeWhere((m) => m.id == id);
    await _salvarMedicamentos();
    notifyListeners();
  }

  Future<void> atualizarMedicamento(Medicamento medicamento) async {
    final index = _medicamentos.indexWhere((m) => m.id == medicamento.id);
    if (index != -1) {
      _medicamentos[index] = medicamento;
      await _salvarMedicamentos();
      notifyListeners();
    }
  }

  Future<void> toggleAtivo(String id) async {
    final index = _medicamentos.indexWhere((m) => m.id == id);
    if (index != -1) {
      _medicamentos[index] = _medicamentos[index].copyWith(
        ativo: !_medicamentos[index].ativo,
      );
      await _salvarMedicamentos();
      notifyListeners();
    }
  }
}
