import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<void> initializeGoogleSignIn() async {
    await GoogleSignIn.instance.initialize();
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

    return userCredential;
  }

  Future<String> getFirebaseIdToken() async {
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

    return idToken;
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