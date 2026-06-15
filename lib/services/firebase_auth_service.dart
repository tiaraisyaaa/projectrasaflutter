import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<void> initializeGoogleSignIn() async {
    await GoogleSignIn.instance.initialize();
  }

  Future<void> _copyFirebaseIdTokenToClipboard({
    required String label,
    required String idToken,
  }) async {
    if (idToken.isEmpty) {
      print('$label: Firebase ID Token kosong');
      return;
    }

    final bodyJson = jsonEncode({
      'idToken': idToken,
    });

    // Yang dicopy ke clipboard adalah TOKEN MENTAH,
    // supaya mudah ditempel ke field idToken di Postman/Swagger.
    await Clipboard.setData(
      ClipboardData(text: idToken),
    );

    print('========== $label ==========');
    print('FIREBASE ID TOKEN LANGSUNG:');
    print(idToken);
    print('===START_FIREBASE_ID_TOKEN===');
    print(idToken);
    print('===END_FIREBASE_ID_TOKEN===');
    print('FORMAT BODY JSON JIKA DIPAKAI DI POSTMAN/SWAGGER:');
    print(bodyJson);
    print('FIREBASE ID TOKEN MENTAH SUDAH DICOPY KE CLIPBOARD');
  }

  Future<String> _getAndCopyCurrentFirebaseIdToken({
    required String label,
  }) async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw Exception('User Firebase belum login');
    }

    await user.reload();

    final User? refreshedUser = _firebaseAuth.currentUser;

    if (refreshedUser == null) {
      throw Exception('User Firebase belum login');
    }

    final String? idToken = await refreshedUser.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Firebase ID Token tidak ditemukan');
    }

    await _copyFirebaseIdTokenToClipboard(
      label: label,
      idToken: idToken,
    );

    return idToken;
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim();
    final String cleanPassword = password.trim();

    final UserCredential userCredential =
        await _firebaseAuth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: cleanPassword,
    );

    await userCredential.user?.sendEmailVerification();

    // Token dicopy di sini, sebelum user masuk halaman Lengkapi Profil.
    await _getAndCopyCurrentFirebaseIdToken(
      label: 'FIREBASE ID TOKEN REGISTER EMAIL',
    );

    return userCredential;
  }

  Future<UserCredential> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim();
    final String cleanPassword = password.trim();

    final UserCredential userCredential =
        await _firebaseAuth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: cleanPassword,
    );

    await userCredential.user?.reload();

    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User tidak ditemukan.',
      );
    }

    if (!currentUser.emailVerified) {
      await _firebaseAuth.signOut();

      throw FirebaseAuthException(
        code: 'email-not-verified',
        message:
            'Email belum diverifikasi. Silakan cek inbox atau spam, lalu klik link verifikasi.',
      );
    }

    await _getAndCopyCurrentFirebaseIdToken(
      label: 'FIREBASE ID TOKEN LOGIN EMAIL',
    );

    return userCredential;
  }

  Future<UserCredential> signInWithGoogle() async {
    await initializeGoogleSignIn();

    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _firebaseAuth.signInWithCredential(credential);

    // Token dicopy di sini, sebelum user masuk halaman Lengkapi Profil
    // atau sebelum proses login Google lanjut ke backend.
    await _getAndCopyCurrentFirebaseIdToken(
      label: 'FIREBASE ID TOKEN GOOGLE',
    );

    return userCredential;
  }

  Future<String> getFirebaseIdToken() async {
    return _getAndCopyCurrentFirebaseIdToken(
      label: 'FIREBASE ID TOKEN MANUAL',
    );
  }

  Future<void> sendEmailVerification() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw Exception('User Firebase belum login');
    }

    await user.sendEmailVerification();
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Diabaikan kalau user tidak login lewat Google.
    }
  }
}