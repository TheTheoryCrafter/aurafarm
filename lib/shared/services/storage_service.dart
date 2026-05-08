import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class StorageService {
  static final instance = StorageService._();
  StorageService._();

  static const _uuid = Uuid();

  Future<String> get _facesDir async {
    final dir = await getApplicationDocumentsDirectory();
    final faces = Directory(p.join(dir.path, 'faces'));
    if (!await faces.exists()) await faces.create(recursive: true);
    return faces.path;
  }

  Future<String> get _songsDir async {
    final dir = await getApplicationDocumentsDirectory();
    final songs = Directory(p.join(dir.path, 'songs'));
    if (!await songs.exists()) await songs.create(recursive: true);
    return songs.path;
  }

  Future<String> saveFaceImage(Uint8List jpegBytes) async {
    final dir = await _facesDir;
    final path = p.join(dir, '${_uuid.v4()}.jpg');
    await File(path).writeAsBytes(jpegBytes);
    return path;
  }

  Future<String> saveSongFile(File sourceFile) async {
    final dir = await _songsDir;
    final ext = p.extension(sourceFile.path);
    final dest = p.join(dir, '${_uuid.v4()}$ext');
    await sourceFile.copy(dest);
    return dest;
  }

  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
