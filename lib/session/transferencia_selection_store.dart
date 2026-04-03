class TransferenciaSelectionStore {
  TransferenciaSelectionStore._();
  static final TransferenciaSelectionStore instance =
      TransferenciaSelectionStore._();

  final Set<int> _selectedAnimalIds = <int>{};

  Set<int> get selectedAnimalIds => Set<int>.from(_selectedAnimalIds);

  bool isSelected(int animalId) => _selectedAnimalIds.contains(animalId);

  void toggle(int animalId) {
    if (_selectedAnimalIds.contains(animalId)) {
      _selectedAnimalIds.remove(animalId);
    } else {
      _selectedAnimalIds.add(animalId);
    }
  }

  void clear() => _selectedAnimalIds.clear();

  void replaceAll(Iterable<int> ids) {
    _selectedAnimalIds
      ..clear()
      ..addAll(ids);
  }
}
