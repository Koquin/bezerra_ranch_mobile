import '../models/nascimento.dart';
import '../services/animal_service.dart';

class AnimalController {
  final AnimalService _animalService;

  AnimalController({AnimalService? animalService})
      : _animalService = animalService ?? AnimalService();

  Future<List<Nascimento>> list({String? q}) {
    return _animalService.list(q: q);
  }

  Future<Nascimento?> getById(int id) {
    return _animalService.getById(id);
  }

  Future<List<Nascimento>> listVivos({String? q}) {
    return _animalService.listVivos(q: q);
  }
}
