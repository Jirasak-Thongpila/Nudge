// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

/// Platform audio recorder using browser HTML5 MediaRecorder API on Web
class PlatformAudioRecorder {
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  Completer<String?>? _completer;

  bool get isSupported =>
      html.window.navigator.mediaDevices != null;

  Future<bool> start() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) return false;

      final stream = await mediaDevices.getUserMedia({'audio': true});

      _chunks.clear();
      _mediaRecorder = html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && (blobEvent.data?.size ?? 0) > 0) {
          _chunks.add(blobEvent.data!);
        }
      });
      _mediaRecorder!.start();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> stop() async {
    final recorder = _mediaRecorder;
    if (recorder == null) return null;

    final completer = Completer<String?>();
    _completer = completer;

    recorder.addEventListener('stop', (_) async {
      try {
        final fullBlob = html.Blob(_chunks, 'audio/webm');
        final reader = html.FileReader();
        reader.readAsDataUrl(fullBlob);
        reader.onLoadEnd.listen((_) {
          final result = reader.result as String?;
          if (result != null && result.contains(',')) {
            final base64Part = result.split(',').last;
            completer.complete(base64Part);
          } else {
            completer.complete(null);
          }
        });
      } catch (e) {
        completer.complete(null);
      }
    });

    try {
      recorder.stop();
      recorder.stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {
      completer.complete(null);
    }

    return _completer?.future;
  }
}
