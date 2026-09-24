import 'package:flutter/foundation.dart';
import 'package:flutter_line_liff/flutter_line_liff.dart';

class LiffUserProfile {
  final String userId;
  final String displayName;
  final String? pictureUrl;
  final String? statusMessage;

  LiffUserProfile({
    required this.userId,
    required this.displayName,
    this.pictureUrl,
    this.statusMessage,
  });
}

const String defaultLiffId = String.fromEnvironment(
  'LINE_LIFF_ID',
  defaultValue: '2011693149-NldwbAUx',
);

class LiffService {
  static final LiffService instance = LiffService._internal();
  LiffService._internal();

  bool _isInitialized = false;
  bool _isLiffSupported = false;
  LiffUserProfile? _profile;

  bool get isInitialized => _isInitialized;
  bool get isLiffSupported => _isLiffSupported;
  LiffUserProfile? get profile => _profile;
  String? get lineUserId => _profile?.userId;

  /// Initializes LINE LIFF SDK on Web platform.
  /// If running on native platforms (Windows/Android/iOS), it safely bypasses.
  Future<bool> init({String? liffId}) async {
    if (!kIsWeb) {
      _isLiffSupported = false;
      _isInitialized = true;
      return false;
    }

    final targetLiffId = liffId ?? defaultLiffId;

    try {
      final liff = FlutterLineLiff.instance;
      await liff.init(
        config: Config(liffId: targetLiffId),
        successCallback: () {
          _isLiffSupported = true;
          _isInitialized = true;
        },
        errorCallback: (error) {
          debugPrint('LIFF Init error: $error');
          _isLiffSupported = false;
          _isInitialized = true;
        },
      );

      if (liff.isLoggedIn) {
        await _fetchProfile();
      }

      return _isLiffSupported;
    } catch (e) {
      debugPrint('LIFF initialization exception: $e');
      _isLiffSupported = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Fetches LINE user profile from LIFF SDK.
  Future<LiffUserProfile?> _fetchProfile() async {
    if (!kIsWeb || !_isLiffSupported) return null;

    try {
      final liff = FlutterLineLiff.instance;
      final profile = await liff.profile;
      _profile = LiffUserProfile(
        userId: profile.userId,
        displayName: profile.displayName,
        pictureUrl: profile.pictureUrl,
        statusMessage: profile.statusMessage,
      );
      return _profile;
    } catch (e) {
      debugPrint('Error fetching LIFF profile: $e');
      return null;
    }
  }

  /// Triggers LINE login if not already logged in inside LIFF browser.
  void login() {
    if (kIsWeb && _isLiffSupported) {
      final liff = FlutterLineLiff.instance;
      if (!liff.isLoggedIn) {
        liff.login();
      }
    }
  }

  /// Logs out of LINE LIFF session if on Web platform.
  void logout() {
    if (kIsWeb && _isLiffSupported) {
      try {
        final liff = FlutterLineLiff.instance;
        if (liff.isLoggedIn) {
          liff.logout();
        }
      } catch (e) {
        debugPrint('Error logging out of LIFF: $e');
      }
    }
    _profile = null;
  }

  /// Closes the LIFF browser window inside LINE.
  void closeWindow() {
    if (kIsWeb && _isLiffSupported) {
      FlutterLineLiff.instance.closeWindow();
    }
  }
}
