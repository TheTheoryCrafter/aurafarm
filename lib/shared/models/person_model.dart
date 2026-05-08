import 'dart:convert';

class Person {
  final String id;
  final String name;
  final String? faceImagePath;
  final List<List<double>> faceEmbeddings;
  final String? songPath;
  final int snippetStartMs;
  final int snippetEndMs;
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.name,
    this.faceImagePath,
    this.faceEmbeddings = const [],
    this.songPath,
    this.snippetStartMs = 0,
    this.snippetEndMs = 10000,
    required this.createdAt,
  });

  Person copyWith({
    String? id,
    String? name,
    String? faceImagePath,
    List<List<double>>? faceEmbeddings,
    String? songPath,
    int? snippetStartMs,
    int? snippetEndMs,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      faceImagePath: faceImagePath ?? this.faceImagePath,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      songPath: songPath ?? this.songPath,
      snippetStartMs: snippetStartMs ?? this.snippetStartMs,
      snippetEndMs: snippetEndMs ?? this.snippetEndMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'faceImagePath': faceImagePath,
    'faceEmbeddings': faceEmbeddings,
    'songPath': songPath,
    'snippetStartMs': snippetStartMs,
    'snippetEndMs': snippetEndMs,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    // Backward-compat: old format stored a single flat embedding
    List<List<double>> embeddings;
    if (json['faceEmbeddings'] != null) {
      embeddings = (json['faceEmbeddings'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } else if (json['faceEmbedding'] != null) {
      final single = (json['faceEmbedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      embeddings = single.isEmpty ? [] : [single];
    } else {
      embeddings = [];
    }
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      faceImagePath: json['faceImagePath'] as String?,
      faceEmbeddings: embeddings,
      songPath: json['songPath'] as String?,
      snippetStartMs: json['snippetStartMs'] as int? ?? 0,
      snippetEndMs: json['snippetEndMs'] as int? ?? 10000,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<Person> listFromJson(String source) =>
      (jsonDecode(source) as List<dynamic>)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();

  static String listToJson(List<Person> people) =>
      jsonEncode(people.map((p) => p.toJson()).toList());

  bool get hasFace => faceEmbeddings.isNotEmpty;
  bool get hasSong => songPath != null;
  bool get isComplete => hasFace && hasSong;

  Duration get snippetStart => Duration(milliseconds: snippetStartMs);
  Duration get snippetEnd => Duration(milliseconds: snippetEndMs);
  Duration get snippetDuration => snippetEnd - snippetStart;
}
