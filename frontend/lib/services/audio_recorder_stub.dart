/// Platform audio recorder stub for non-web environments
class PlatformAudioRecorder {
  bool get isSupported => false;

  Future<bool> start() async {
    return false;
  }

  Future<String?> stop() async {
    return null;
  }
}
