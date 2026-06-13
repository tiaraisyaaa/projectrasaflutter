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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);

  Future<void> _registerWithEmailPassword() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Nama, email, dan password wajib diisi');
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Register gagal: $e');
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Verifikasi Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Link verifikasi sudah dikirim ke email kamu. '
                'Buka email, klik link verifikasi, lalu tekan tombol '
                '"Saya sudah verifikasi".',
              ),
              actions: [
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
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
                                'Email belum terverifikasi. Cek email kamu dulu.',
                              );
                              return;
                            }

                            final idToken = await _firebaseAuthService
                                .getFirebaseIdToken();

                            final inputName = _nameController.text.trim();
                            final finalName = inputName.isNotEmpty
                                ? inputName
                                : _getNameFromEmail(currentUser.email ?? '');

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompleteProfileScreen(
                                  firebaseIdToken: idToken,
                                  initialName: finalName,
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

  String _getNameFromEmail(String email) {
    if (email.contains('@')) {
      return email.split('@').first;
    }

    return email;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon/logo.png',
      width: 165,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Column(
          children: const [
            Icon(Icons.health_and_safety, size: 72, color: primaryBlue),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Real-time Asisten Siaga Aktivitas Lansia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.20),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: primaryBlue, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: darkBlue, width: 1.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: 165,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerWithEmailPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryBlue.withOpacity(0.55),
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: 255,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _registerWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.92),
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Daftar dengan Google',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Sudah punya akun? ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
              decorationColor: primaryBlue,
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [softBlue, verySoftBlue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),

                    const SizedBox(height: 26),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 18),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 18),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
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

                    const SizedBox(height: 30),

                    _buildRegisterButton(),

                    const SizedBox(height: 16),

                    _buildGoogleButton(),

                    const SizedBox(height: 22),

                    _buildLoginLink(),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
