import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/people_repository.dart';
import '../../../shared/models/person_model.dart';

final peopleRepositoryProvider = Provider<PeopleRepository>((_) => PeopleRepository());

final peopleProvider = AsyncNotifierProvider<PeopleNotifier, List<Person>>(PeopleNotifier.new);

class PeopleNotifier extends AsyncNotifier<List<Person>> {
  PeopleRepository get _repo => ref.read(peopleRepositoryProvider);

  @override
  Future<List<Person>> build() => _repo.getAll();

  Future<void> upsert(Person person) async {
    await _repo.upsert(person);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
