import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Neural TTS via AWS Polly.
///
/// Pass credentials at build time:
///   flutter run \
///     --dart-define=AWS_POLLY_KEY_ID=AKIA... \
///     --dart-define=AWS_POLLY_SECRET=...
///
/// The service uses AWS Signature Version 4 to sign each request, caches the
/// resulting MP3 in the app's temp directory, and plays it via audioplayers.
/// Every public method degrades gracefully — callers should fall back to
/// another TTS provider when [speak] returns false.
class AwsPollyTtsService {
  static const _accessKeyId = String.fromEnvironment('AWS_POLLY_KEY_ID');
  static const _secretKey = String.fromEnvironment('AWS_POLLY_SECRET');
  static const _region = 'us-east-1';
  static const _service = 'polly';
  static const _endpoint =
      'https://polly.us-east-1.amazonaws.com/v1/speech';

  static bool get hasKey =>
      _accessKeyId.isNotEmpty && _secretKey.isNotEmpty;

  static const String defaultVoice = 'Kevin';

  final _player = AudioPlayer();
  Directory? _cacheDir;

  Future<Directory> _dir() async {
    _cacheDir ??= await getTemporaryDirectory();
    return _cacheDir!;
  }

  String _keyFor(String text, String voice) {
    final safe = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final short = safe.substring(0, safe.length.clamp(0, 40));
    return 'sb_polly_${voice}_${short}_${text.hashCode}.mp3';
  }

  /// Pronounce [text] using Polly's neural [voice].
  /// Returns true on success; false means the caller should fall back.
  Future<bool> speak(String text, {String? voice}) async {
    if (!hasKey) return false;
    try {
      final v = voice ?? defaultVoice;
      final dir = await _dir();
      final file = File('${dir.path}/${_keyFor(text, v)}');
      if (!file.existsSync()) {
        final bytes = await _fetchPolly(text, v);
        if (bytes == null) return false;
        await file.writeAsBytes(bytes, flush: true);
      }
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<int>?> _fetchPolly(String text, String voice) async {
    final bodyMap = {
      'Text': text,
      'OutputFormat': 'mp3',
      'VoiceId': voice,
      'Engine': 'neural',
    };
    final bodyStr = jsonEncode(bodyMap);
    final bodyBytes = utf8.encode(bodyStr);

    final now = DateTime.now().toUtc();
    final dateStamp = _dateStamp(now);
    final amzDate = _amzDate(now);
    final payloadHash = _hexSha256(bodyBytes);

    final headers = {
      'Content-Type': 'application/json',
      'Host': 'polly.$_region.amazonaws.com',
      'X-Amz-Date': amzDate,
      'X-Amz-Content-Sha256': payloadHash,
    };

    final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest = [
      'POST',
      '/v1/speech',
      '',
      'content-type:${headers['Content-Type']}\n'
          'host:${headers['Host']}\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n',
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope =
        '$dateStamp/$_region/$_service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hexSha256(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _deriveSigningKey(dateStamp);
    final signature = _hexHmac(signingKey, stringToSign);

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    final resp = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            ...headers,
            'Authorization': authorization,
          },
          body: bodyBytes,
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }

  // ── Sig V4 helpers ────────────────────────────────────────────────────

  String _dateStamp(DateTime utc) =>
      '${utc.year}${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}';

  String _amzDate(DateTime utc) =>
      '${_dateStamp(utc)}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';

  String _hexSha256(List<int> data) {
    return sha256.convert(data).toString();
  }

  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  String _hexHmac(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).toString();
  }

  List<int> _deriveSigningKey(String dateStamp) {
    final kDate = _hmacSha256(
        utf8.encode('AWS4$_secretKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, _region);
    final kService = _hmacSha256(kRegion, _service);
    return _hmacSha256(kService, 'aws4_request');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
