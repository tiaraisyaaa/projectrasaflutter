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
    final UserCredential userCredential =
        await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await userCredential.user?.sendEmailVerification();

    return userCredential;
  }

  Future<UserCredential> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
        await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await userCredential.user?.reload();

    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw Exception('User tidak ditemukan');
    }

    if (!currentUser.emailVerified) {
      throw Exception(
        'Email belum diverifikasi. Silakan cek email dan klik link verifikasi.',
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

    final String? idToken = await user.getIdToken(true);

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