import 'package:equatable/equatable.dart';

/// A single spelling-bee word. [text] is what the student must spell; the
/// other fields are what TTS reads aloud to give context — the way a real
/// bee pronouncer offers "definition" and "use in a sentence" on request.
class Word extends Equatable {
  final String text;
  final String definition;
  final String example;

  const Word(this.text, this.definition, this.example);

  /// Simple difficulty heuristic used when generating words via AI:
  /// falls roughly in line with Scripps tiers.
  int get length => text.length;

  @override
  List<Object?> get props => [text, definition, example];

  Map<String, dynamic> toJson() => {
        'text': text,
        'definition': definition,
        'example': example,
      };

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        j['text'] as String,
        j['definition'] as String? ?? '',
        j['example'] as String? ?? '',
      );
}
