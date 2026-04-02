import '../models/nascimento.dart';
import '../services/animal_service.dart';

class AnimalController {
  final AnimalService _animalService;

  AnimalController({AnimalService? animalService})
      : _animalService = animalService ?? AnimalService();

  Future<List<Nascimento>> list({String? q}) {
    print('Entrou no list do AnimalController, q=$q');
    return _animalService.list(q: q);
  }
}
