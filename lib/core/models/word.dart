import 'package:equatable/equatable.dart';

/// A single spelling-bee word. [text] is what the student must spell; the
/// other fields are what TTS reads aloud to give context — the way a real
/// bee pronouncer offers "definition" and "use in a sentence" on request.
///
/// [prompt] and [display] exist for the Number Bee: a math item speaks
/// "What is seven plus five?" ([prompt]) and shows "7 + 5 = ?" ([display])
/// while the thing to spell stays [text] = "twelve". Plain words leave both
/// null and behave exactly as before.
class Word extends Equatable {
  final String text;
  final String definition;
  final String example;
  final String? prompt;
  final String? display;

  const Word(
    this.text,
    this.definition,
    this.example, {
    this.prompt,
    this.display,
  });

  /// Simple difficulty heuristic used when generating words via AI:
  /// falls roughly in line with Scripps tiers.
  int get length => text.length;

  /// Letters only, lowercase — what grading compares against, so a target
  /// like "thirty-eight" is spelled without the hyphen.
  String get letters => text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  @override
  List<Object?> get props => [text, definition, example, prompt, display];

  Map<String, dynamic> toJson() => {
    'text': text,
    'definition': definition,
    'example': example,
    if (prompt != null) 'prompt': prompt,
    if (display != null) 'display': display,
  };

  factory Word.fromJson(Map<String, dynamic> j) => Word(
    j['text'] as String,
    j['definition'] as String? ?? '',
    j['example'] as String? ?? '',
    prompt: j['prompt'] as String?,
    display: j['display'] as String?,
  );
}
