import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/services/bundled_tts_service.dart';
import 'package:spellbee/core/services/openai_tts_service.dart';
import 'package:spellbee/core/services/speech_audio_player.dart';
import 'package:spellbee/core/services/tts_service.dart';

class RecordingPlayer extends SpeechAudioPlayer {
  final paths = <String>[];
  final rates = <double>[];
  @override
  Future<bool> play(
    Source source, {
    double speed = 1,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    paths.add(
      source is AssetSource ? source.path : (source as DeviceFileSource).path,
    );
    rates.add(speed);
    return true;
  }

  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class RecordingOnline extends OpenAiTtsService {
  final spoken = <String>[];
  Completer<bool>? pending;
  @override
  Future<bool> speak(String text, {String? voice, double speed = 1}) async {
    spoken.add(text);
    return pending == null ? true : pending!.future;
  }

  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

BundledTtsService bundle(
  RecordingPlayer player, {
  Future<List<String>> Function()? assets,
}) => BundledTtsService(
  player: player,
  assetLoader: assets ?? () async => ['assets/audio/words/cat.mp3'],
  manifestLoader: () async => jsonEncode({
    'texts': {
      'cat': 'audio/words/new-cat.mp3',
      'A calm clue.': 'audio/words/clue.mp3',
    },
    'phrases': {'great': 'audio/words/great.mp3'},
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final deviceSpeech = <String>[];
  setUp(() {
    deviceSpeech.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          if (call.method == 'speak') {
            deviceSpeech.add(
              call.arguments is String
                  ? call.arguments as String
                  : call.arguments['text'] as String,
            );
          }
          if (call.method == 'getVoices' || call.method == 'getEngines') {
            return [];
          }
          return 1;
        });
  });
  test('modern Flutter bundled asset manifest finds included words', () async {
    final service = BundledTtsService();
    addTearDown(service.dispose);
    expect(await service.hasWord('cat'), true);
  });
  test(
    'free and premium core words use the same included natural voice',
    () async {
      final player = RecordingPlayer(), online = RecordingOnline();
      final service = TtsService(bundled: bundle(player), online: online)
        ..setQuality(VoiceQuality.studio);
      addTearDown(service.dispose);
      await service.speakWord('cat');
      await service.speakWord('cat', premium: true);
      expect(player.paths, [
        'audio/words/new-cat.mp3',
        'audio/words/new-cat.mp3',
      ]);
      expect(online.spoken, isEmpty);
      expect(deviceSpeech, isEmpty);
    },
  );
  test('slow replay is slower even when saved speed is Calm', () async {
    final player = RecordingPlayer();
    final service = TtsService(
      bundled: bundle(player),
      online: RecordingOnline(),
    );
    addTearDown(service.dispose);
    await service.speakWord('cat');
    await service.speakWord('cat', skipBundled: true);
    expect(player.rates, [.88, .75]);
    expect(deviceSpeech, isEmpty);
  });
  test(
    'bundled context and phrases use selected rate without cloud requests',
    () async {
      final player = RecordingPlayer(), online = RecordingOnline();
      final service = TtsService(bundled: bundle(player), online: online)
        ..setQuality(VoiceQuality.studio);
      addTearDown(service.dispose);
      await service.setSpeed(VoiceSpeed.fast);
      await service.speakText('A calm clue.', premium: true);
      await service.playPhrase('great');
      expect(player.rates, [1.15, 1.15]);
      expect(online.spoken, isEmpty);
    },
  );
  test('unbundled online voice remains gated by premium', () async {
    final online = RecordingOnline();
    final service = TtsService(
      bundled: bundle(RecordingPlayer()),
      online: online,
    )..setQuality(VoiceQuality.studio);
    addTearDown(service.dispose);
    await service.speakWord('custom');
    expect(deviceSpeech, ['custom']);
    expect(online.spoken, isEmpty);
    await service.speakWord('custom', premium: true);
    expect(online.spoken, ['custom']);
  });
  test('stop while manifest loads prevents late bundled playback', () async {
    final assets = Completer<List<String>>(), player = RecordingPlayer();
    final service = bundle(player, assets: () => assets.future);
    final playing = service.playWord('cat');
    await service.stop();
    assets.complete(['assets/audio/words/cat.mp3']);
    await playing;
    expect(player.paths, isEmpty);
  });
  test(
    'late failed cloud request cannot fall through to device after stop',
    () async {
      final online = RecordingOnline()..pending = Completer<bool>();
      final service = TtsService(
        bundled: bundle(RecordingPlayer()),
        online: online,
      )..setQuality(VoiceQuality.studio);
      addTearDown(service.dispose);
      final playing = service.speakWord('custom', premium: true);
      await flush();
      await service.stop();
      online.pending!.complete(false);
      await playing;
      expect(deviceSpeech, isEmpty);
    },
  );
  test(
    'stopping a real gateway fetch prevents its late response from playing',
    () async {
      final response = Completer<http.Response>(),
          requested = Completer<void>();
      final directory = await Directory.systemTemp.createTemp(
        'spellbee-voice-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final player = RecordingPlayer();
      final service = OpenAiTtsService(
        player: player,
        cacheDirectory: () async => directory,
        client: MockClient((_) {
          requested.complete();
          return response.future;
        }),
      );
      addTearDown(service.dispose);
      final playing = service.speak('custom');
      await requested.future.timeout(const Duration(seconds: 5));
      await service.stop();
      response.complete(
        http.Response.bytes(
          List.filled(2000, 0),
          200,
          headers: {'content-type': 'audio/mpeg'},
        ),
      );
      expect(await playing.timeout(const Duration(seconds: 5)), true);
      expect(player.paths, isEmpty);
    },
  );
  test(
    'every authored word and contextual prompt has exact recorded coverage',
    () {
      final scripts =
          (jsonDecode(File('tools/audio/scripts.json').readAsStringSync())
                  as List)
              .cast<Map<String, dynamic>>();
      final byWord = <String, Set<String>>{};
      for (final item in scripts) {
        if (item['word'] != null) {
          (byWord[item['word']] ??= {}).add(item['text']);
        }
      }
      int seed(String word) {
        var h = 0;
        for (final c in word.codeUnits) {
          h = (h * 31 + c) & 0x7fffffff;
        }
        return h;
      }

      for (final word in kAllWords) {
        final h = seed(word.text);
        expect(
          byWord[word.text],
          containsAll([
            word.text,
            TtsService.buildDefinitionPrompt(
              word.text,
              word.definition,
              variant: h % TtsService.definitionPromptVariantCount,
            ),
            TtsService.buildExamplePrompt(
              word.text,
              word.example,
              variant: h % TtsService.examplePromptVariantCount,
            ),
            TtsService.buildSpellOutPrompt(
              word.text,
              word.text.toUpperCase().split('').join(', '),
              variant: h % TtsService.spellOutPromptVariantCount,
            ),
          ]),
        );
      }
    },
  );
}
