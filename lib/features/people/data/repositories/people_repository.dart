import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/person_model.dart';

class PeopleRepository {
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, AppConstants.peopleFileName));
  }

  Future<List<Person>> getAll() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return [];
      return Person.listFromJson(contents);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Person> people) async {
    final file = await _getFile();
    await file.writeAsString(Person.listToJson(people));
  }

  Future<void> upsert(Person person) async {
    final people = await getAll();
    final idx = people.indexWhere((p) => p.id == person.id);
    if (idx >= 0) {
      people[idx] = person;
    } else {
      people.add(person);
    }
    await save(people);
  }

  Future<void> delete(String id) async {
    final people = await getAll();
    final person = people.firstWhere((p) => p.id == id, orElse: () => throw Exception('Not found'));
    // Clean up associated files
    if (person.faceImagePath != null) {
      final f = File(person.faceImagePath!);
      if (await f.exists()) await f.delete();
    }
    if (person.songPath != null) {
      final f = File(person.songPath!);
      if (await f.exists()) await f.delete();
    }
    people.removeWhere((p) => p.id == id);
    await save(people);
  }

  Future<Person?> getById(String id) async {
    final people = await getAll();
    try {
      return people.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
