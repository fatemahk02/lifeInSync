import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // FIX: Pass clientId for web platform
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: kIsWeb
        ? '912962287480-2tpgef2ofifj3b8t8o3j3v0i6hqkj6vu.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyError(e.code));
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyError(e.code));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use popup flow
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        return await _auth.signInWithPopup(provider);
      } else {
        // Mobile: use google_sign_in package
        final googleSignIn = _googleSignIn;
        await googleSignIn.signOut();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception(
            'Google auth tokens are null. Check SHA-1 in Firebase.',
          );
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyError(e.code));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(String, int?) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifyOTPAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyError(e.code));
    }
  }

  // FIX: Proper sign out for both web and mobile
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      // Still sign out from Firebase even if Google sign out fails
      await _auth.signOut();
    }
  }

  String _friendlyError(String code) {
    const map = {
      'user-not-found': 'No account found with this email.',
      'wrong-password': 'Incorrect password.',
      'invalid-email': 'Invalid email address.',
      'email-already-in-use': 'An account with this email already exists.',
      'weak-password': 'Password must be at least 6 characters.',
      'too-many-requests': 'Too many attempts. Please try again later.',
      'network-request-failed': 'Network error. Check your connection.',
      'invalid-verification-code': 'Invalid OTP. Please try again.',
      'session-expired': 'OTP expired. Request a new code.',
      'invalid-phone-number': 'Invalid phone number. Use +91XXXXXXXXXX',
      'popup-closed-by-user': 'Sign-in popup was closed.',
      'cancelled-popup-request': 'Another popup is already open.',
    };
    return map[code] ?? 'Authentication failed. Please try again.';
  }
}
