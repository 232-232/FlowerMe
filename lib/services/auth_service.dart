// lib/services/auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Thin singleton around FirebaseAuth. The UI layer never imports firebase_auth
// directly — it only talks to this service.
//
// ⚠️  Firebase Phone Auth is a MOBILE-ONLY feature.
//     On Flutter Web the native platform channels do not exist, so every call
//     to verifyPhoneNumber / signInWithCredential throws a PlatformException.
//     All public methods below are guarded with kIsWeb so the app stays
//     crash-free when run in a browser (dev or prod).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

typedef PhoneCodeSentCallback           = void Function(String verificationId);
typedef PhoneAutoVerifiedCallback       = void Function(PhoneAuthCredential);
typedef PhoneFailedCallback             = void Function(FirebaseAuthException);
typedef PhoneCodeAutoRetrievalCallback  = void Function(String verificationId);

class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  AuthService._();
  static final AuthService instance = AuthService._();

  // Lazily access FirebaseAuth so that on web we don't trigger channel
  // registration at class-load time (which would throw PlatformException).
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Internal state, cleared on each new verifyPhone call
  String? _verificationId;
  int?    _forceResendToken;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns null on web (phone auth not supported).
  User? get currentUser => kIsWeb ? null : _auth.currentUser;

  /// Kick off phone verification.
  ///
  /// Throws a [FirebaseAuthException] with code `web-not-supported` when called
  /// on Flutter Web so the login page can show a friendly banner.
  Future<void> verifyPhone({
    required String phone,
    required PhoneCodeSentCallback onCodeSent,
    required PhoneAutoVerifiedCallback onAutoVerified,
    required PhoneFailedCallback onFailed,
    PhoneCodeAutoRetrievalCallback? onCodeAutoRetrieval,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      onFailed(FirebaseAuthException(
        code: 'web-not-supported',
        message:
            'Phone OTP login works on our Android app.\n'
            'Please open Daily Club on your phone.',
      ));
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: timeout,
      forceResendingToken: _forceResendToken,

      verificationCompleted: (PhoneAuthCredential credential) {
        onAutoVerified(credential);
      },

      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _forceResendToken = resendToken;
        onCodeSent(verificationId);
      },

      verificationFailed: (FirebaseAuthException e) {
        onFailed(e);
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        onCodeAutoRetrieval?.call(verificationId);
      },
    );
  }

  /// Sign in with a 6-digit SMS code. Throws on web.
  Future<UserCredential> verifyOtp(String smsCode) async {
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'web-not-supported',
        message: 'Phone OTP is not supported on web.',
      );
    }
    if (_verificationId == null) {
      throw FirebaseAuthException(
        code: 'no-verification-id',
        message: 'No verification in progress. Please request OTP first.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign in directly with an auto-verified credential. Throws on web.
  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) async {
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'web-not-supported',
        message: 'Phone OTP is not supported on web.',
      );
    }
    return _auth.signInWithCredential(credential);
  }

  /// Sign the current user out. Safe to call on web (no-op).
  Future<void> signOut() async {
    if (kIsWeb) return;
    await _auth.signOut();
  }

  /// Reset internal state (called when user goes back to phone step).
  void reset() {
    _verificationId = null;
  }
}
