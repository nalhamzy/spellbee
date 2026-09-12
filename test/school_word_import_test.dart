import 'package:flutter_test/flutter_test.dart';
import 'package:spellbee/core/utils/school_word_import.dart';

void main() {
  test(
    'imports mixed separators and ignores blanks and worksheet numbering',
    () {
      final parsed = SchoolWordImport.parse(
        '1. bridge\r\n\r\n2) school, bee,\n• garden\n- honey\n* hive',
      );
      expect(parsed.words, [
        'bridge',
        'school',
        'bee',
        'garden',
        'honey',
        'hive',
      ]);
      expect(parsed.duplicates, 0);
      expect(parsed.invalidEntries, 0);
    },
  );

  test(
    'deduplicates case-insensitively against both saved and pasted words',
    () {
      final parsed = SchoolWordImport.parse(
        'Bridge,BRIDGE, Bee, bee, garden',
        existingWords: ['bridge'],
      );
      expect(parsed.words, ['Bee', 'garden']);
      expect(parsed.duplicates, 3);
    },
  );

  test(
    'preserves deliberate spaces, hyphens, apostrophes and spelling variants',
    () {
      final parsed = SchoolWordImport.parse(
        "ice cream, well-being, mother-in-law, can't, colour, color, two  spaces",
      );
      expect(parsed.words, [
        'ice cream',
        'well-being',
        'mother-in-law',
        "can't",
        'colour',
        'color',
        'two  spaces',
      ]);
    },
  );

  test('skips entries that would have no letters for grading', () {
    final parsed = SchoolWordImport.parse(' , \n123, ---, 1. , bee');
    expect(parsed.words, ['bee']);
    expect(parsed.invalidEntries, 3);
  });
}
