import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:spellbee/core/models/word.dart';

/// A saved custom word list, typically created by a parent for a child.
/// Persisted in SharedPreferences as JSON.
class WordList extends Equatable {
  final String id;
  final String name;
  final int? level; // optional difficulty (1..8)
  final List<Word> words;
  final DateTime createdAt;

  const WordList({
    required this.id,
    required this.name,
    required this.words,
    required this.createdAt,
    this.level,
  });

  int get size => words.length;

  WordList copyWith({
    String? name,
    List<Word>? words,
    int? level,
  }) =>
      WordList(
        id: id,
        name: name ?? this.name,
        words: words ?? this.words,
        createdAt: createdAt,
        level: level ?? this.level,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'createdAt': createdAt.toIso8601String(),
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory WordList.fromJson(Map<String, dynamic> j) => WordList(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Untitled',
        level: j['level'] as int?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        words: ((j['words'] as List?) ?? [])
            .map((e) => Word.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
  factory WordList.decode(String raw) =>
      WordList.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [id, name, level, words, createdAt];
}
