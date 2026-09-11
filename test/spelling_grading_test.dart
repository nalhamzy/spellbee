import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/utils/number_words.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/test_screen.dart';

/// The rule this whole file exists to defend: SpellBee is a SPELLING app.
/// Saying the word — or reading the number — is never a correct answer.

String? _numberLetters(String digits) =>
    NumberBee.digitsToWords(digits)?.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );

SpokenAnswer _say(String transcript, String target, {bool number = false}) =>
    SttService.classify(
      transcript,
      target: target,
      spokenNumber: number ? _numberLetters : null,
    );

/// A recognizer that returns a scripted transcript instead of listening, so
/// the grading path can be driven end to end in a widget test.
class _ScriptedStt extends SttService {
  _ScriptedStt(this.script);
  final List<String> script;
  int _index = 0;

  @override
  Future<bool> start({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    final transcript = _index < script.length ? script[_index++] : '';
    Future.microtask(() => onResult(transcript, true));
    return true;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    for (final channel in [
      'flutter_tts',
      'plugin.csdcorp.com/speech_to_text',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'plugins.flutter.io/path_provider',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  group('saying the answer is not spelling it', () {
    test('the word said aloud is never graded', () {
      for (final word in ['cat', 'bridge', 'rainbow', 'giraffe']) {
        final spoken = _say(word, word);
        expect(
          spoken.kind,
          SpokenAnswerKind.wholeWord,
          reason: 'saying "$word" must not count as spelling it',
        );
      }
    });

    test('the number word said aloud is never graded', () {
      final spoken = _say('thirty eight', 'thirtyeight', number: true);
      expect(spoken.kind, SpokenAnswerKind.wholeWord);
      expect(_say('twelve', 'twelve', number: true).kind,
          SpokenAnswerKind.wholeWord);
    });

    test('reading the digits aloud is never graded', () {
      expect(_say('38', 'thirtyeight', number: true).kind,
          SpokenAnswerKind.wholeWord);
      expect(_say('12', 'twelve', number: true).kind,
          SpokenAnswerKind.wholeWord);
      // Digits in a plain word round are simply not letters.
      expect(_say('38', 'bridge').kind, SpokenAnswerKind.unclear);
    });

    test('a whole-word transcript still exposes what was heard', () {
      final spoken = _say('thirty eight', 'thirtyeight', number: true);
      expect(spoken.heard, 'thirty eight');
    });
  });

  group('real spellings are graded', () {
    test('bare letters assemble', () {
      expect(_say('c a t', 'cat').kind, SpokenAnswerKind.letters);
      expect(_say('c a t', 'cat').letters, 'cat');
      final long = _say('t h i r t y e i g h t', 'thirtyeight', number: true);
      expect(long.kind, SpokenAnswerKind.letters);
      expect(long.letters, 'thirtyeight');
    });

    test('letter names assemble', () {
      expect(_say('see ay tee', 'cat').letters, 'cat');
      expect(_say('double you ay vee ee', 'wave').letters, 'wave');
      expect(_say('queue you eye zee', 'quiz').letters, 'quiz');
    });

    test('a wrong spelling is still a spelling, and is graded wrong', () {
      final spoken = _say('b r i j', 'bridge');
      expect(spoken.kind, SpokenAnswerKind.letters);
      expect(spoken.letters, 'brij');
      expect(spoken.letters == 'bridge', isFalse);
    });

    test('homophone targets stay winnable when actually spelled', () {
      // Spelling S-E-A must win even though the letters also spell the word.
      expect(_say('s e a', 'sea').kind, SpokenAnswerKind.letters);
      expect(_say('s e a', 'sea').letters, 'sea');
      expect(_say('es ee ay', 'sea').letters, 'sea');
      expect(_say('bee ee dee', 'bed').letters, 'bed');
      // But merely saying "sea" is not an answer.
      expect(_say('sea', 'sea').kind, SpokenAnswerKind.wholeWord);
    });

    test('silence is empty, not wrong', () {
      expect(_say('', 'cat').kind, SpokenAnswerKind.empty);
      expect(_say('   ', 'cat').kind, SpokenAnswerKind.empty);
    });
  });

  group('the test screen', () {
    Future<ProviderContainer> container(
      List<String> script, {
      bool autoListen = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      await storage.setAutoListen(autoListen);
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          iapServiceProvider.overrideWithValue(IapService()),
          sttServiceProvider.overrideWithValue(_ScriptedStt(script)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Widget host(ProviderContainer c, Widget child) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(theme: AppTheme.light, home: child),
        );

    Future<void> speakAndCheck(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Check my spelling'));
      await tester.tap(find.text('Check my spelling'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// The screen caps how long it waits on the TTS engine (see
    /// _awaitSpeech). Under a mocked engine that wait never resolves on its
    /// own, so let the cap expire or the test ends with a pending timer.
    Future<void> drainSpeechWaits(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 13));
      }
    }

    testWidgets('saying the number does NOT mark the round correct', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = await container(['thirty eight']);
      await tester.pumpWidget(
        host(
          c,
          const TestScreen(
            words: [Word('thirty-eight', 'The number 38.', '', display: '38')],
            title: 'Say the number',
            savesStats: false,
            kind: RoundKind.numbers,
            initialMode: InputMode.mic,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await speakAndCheck(tester);

      expect(find.text('Correct!'), findsNothing,
          reason: 'the child never spelled anything');
      expect(find.text('Not quite'), findsNothing,
          reason: 'saying the number is not a miss either');
      expect(find.textContaining('Now spell it out loud'), findsOneWidget);
      expect(find.text('Use tiles'), findsOneWidget);
      await drainSpeechWaits(tester);
    });

    testWidgets('spelling the number out loud IS marked correct', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = await container(['t h i r t y e i g h t']);
      await tester.pumpWidget(
        host(
          c,
          const TestScreen(
            words: [Word('thirty-eight', 'The number 38.', '', display: '38')],
            title: 'Say the number',
            savesStats: false,
            kind: RoundKind.numbers,
            initialMode: InputMode.mic,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await speakAndCheck(tester);

      expect(find.text('Correct!'), findsOneWidget);
      await drainSpeechWaits(tester);
    });

    testWidgets('saying a plain word does NOT mark it correct', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = await container(['cat']);
      await tester.pumpWidget(
        host(
          c,
          const TestScreen(
            words: [Word('cat', 'A small furry animal.', 'The cat slept.')],
            title: 'Level 1 trial',
            savesStats: false,
            initialMode: InputMode.mic,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await speakAndCheck(tester);

      expect(find.text('Correct!'), findsNothing);
      expect(find.textContaining('Now spell it out loud'), findsOneWidget);
      await drainSpeechWaits(tester);
    });
  });
}
