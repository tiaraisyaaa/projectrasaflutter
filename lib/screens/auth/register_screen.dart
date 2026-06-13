import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firebase_auth_service.dart';
import 'complete_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);
  static const Color cardBlue = Color(0xFFEAF7FF);
  static const Color darkText = Color(0xFF20232A);
  static const Color mutedText = Color(0xFF6F7F86);

  Future<void> _registerWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Format email tidak valid');
      return;
    }

    if (password.length < 6) {
      _showMessage('Password minimal 6 karakter');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseAuthService.registerWithEmailPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await _showEmailVerificationDialog();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Register gagal: $e');
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk atau gunakan email lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah. Coba lagi.';
      default:
        return e.message ?? 'Register gagal. Coba lagi.';
    }
  }

  Future<void> _showEmailVerificationDialog() async {
    bool isChecking = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: const Row(
                children: [
                  Icon(
                    Icons.mark_email_read_rounded,
                    color: primaryBlue,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verifikasi Email',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: darkText,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Link verifikasi sudah dikirim ke email kamu. '
                'Buka email, klik link verifikasi, lalu tekan tombol '
                '"Saya sudah verifikasi". Jika tidak ada di inbox, cek folder spam.',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: mutedText,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Nanti'),
                ),
                ElevatedButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          setDialogState(() {
                            isChecking = true;
                          });

                          try {
                            await FirebaseAuth.instance.currentUser?.reload();

                            final currentUser =
                                FirebaseAuth.instance.currentUser;

                            if (currentUser == null) {
                              throw Exception('User Firebase tidak ditemukan');
                            }

                            if (!currentUser.emailVerified) {
                              setDialogState(() {
                                isChecking = false;
                              });

                              if (!mounted) return;

                              _showMessage(
                                'Email belum terverifikasi. Cek inbox atau spam dulu.',
                              );
                              return;
                            }

                            final idToken = await _firebaseAuthService
                                .getFirebaseIdToken();

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompleteProfileScreen(
                                  firebaseIdToken: idToken,
                                  initialName: '',
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isChecking = false;
                            });

                            if (!mounted) return;

                            _showMessage('Gagal cek verifikasi: $e');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Saya sudah verifikasi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _firebaseAuthService.signInWithGoogle();

      final idToken = await _firebaseAuthService.getFirebaseIdToken();

      final user = userCredential.user;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompleteProfileScreen(
            firebaseIdToken: idToken,
            initialName: user?.displayName ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Register Google gagal: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon/logo.png',
      width: 158,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Column(
          children: [
            Icon(Icons.health_and_safety, size: 72, color: primaryBlue),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Real-time Asisten Siaga Aktivitas Lansia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderText() {
    return const Column(
      children: [
        Text(
          'Buat Akun Baru',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: darkText,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Masukkan email dan password untuk\nmembuat akun RASA.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontSize: 15,
            color: darkText,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: verySoftBlue,
            prefixIcon: Icon(
              icon,
              color: primaryBlue,
              size: 21,
            ),
            suffixIcon: suffixIcon,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: primaryBlue.withOpacity(0.14),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: primaryBlue,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.4,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerWithEmailPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryBlue.withOpacity(0.55),
          elevation: 0,
          shadowColor: primaryBlue.withOpacity(0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Daftar',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _buildDividerText() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.16),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau',
            style: TextStyle(
              color: mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.16),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: primaryBlue.withOpacity(0.14)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _registerWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: darkText,
          disabledForegroundColor: mutedText,
          side: BorderSide(
            color: primaryBlue.withOpacity(0.18),
            width: 1,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGoogleIcon(),
            const SizedBox(width: 12),
            const Text(
              'Daftar dengan Google',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        const Text(
          'Sudah punya akun? ',
          style: TextStyle(
            fontSize: 14,
            color: darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          child: const Text(
            'Masuk',
            style: TextStyle(
              fontSize: 14,
              color: primaryBlue,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
              decorationColor: primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeaderText(),

          const SizedBox(height: 24),

          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            hintText: 'Masukkan email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            hintText: 'Minimal 6 karakter',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) {
                _registerWithEmailPassword();
              }
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: primaryBlue,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          _buildRegisterButton(),

          const SizedBox(height: 20),

          _buildDividerText(),

          const SizedBox(height: 18),

          _buildGoogleButton(),

          const SizedBox(height: 22),

          _buildLoginLink(),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -60,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.32),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: -80,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: softBlue.withOpacity(0.50),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [softBlue, verySoftBlue],
              ),
            ),
          ),
          _buildBackgroundDecor(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),

                      const SizedBox(height: 22),

                      _buildRegisterCard(),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}