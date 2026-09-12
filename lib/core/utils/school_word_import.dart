/// A reviewed import never replaces existing words or their teaching context.
class SchoolWordImport {
  final List<String> words;
  final int duplicates;
  final int invalidEntries;

  const SchoolWordImport(this.words, this.duplicates, this.invalidEntries);

  factory SchoolWordImport.parse(
    String source, {
    Iterable<String> existingWords = const [],
  }) {
    final seen = existingWords.map((word) => word.trim().toLowerCase()).toSet();
    final words = <String>[];
    var duplicates = 0;
    var invalidEntries = 0;
    for (final entry in source.split(RegExp(r'[,\r\n]+'))) {
      final word = entry
          .trim()
          .replaceFirst(RegExp(r'^(?:\d+[.)]\s+|[•*\-]\s+)'), '')
          .trim();
      if (word.isEmpty) continue;
      // Grading needs at least one English letter; don't import empty targets.
      if (!RegExp(r'[a-zA-Z]').hasMatch(word)) {
        invalidEntries++;
        continue;
      }
      if (!seen.add(word.toLowerCase())) {
        duplicates++;
        continue;
      }
      words.add(word);
    }
    return SchoolWordImport(
      List.unmodifiable(words),
      duplicates,
      invalidEntries,
    );
  }
}
