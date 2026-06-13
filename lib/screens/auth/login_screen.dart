import 'package:flutter/material.dart';

import '../../services/firebase_auth_service.dart';
import '../../services/auth_api_service.dart';
import '../dashboard/elderly_dashboard_screen.dart';
import '../dashboard/family_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final AuthApiService _authApiService = AuthApiService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);

  Future<void> _loginWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseAuthService.loginWithEmailPassword(
        email: email,
        password: password,
      );

      final idToken = await _firebaseAuthService.getFirebaseIdToken();

      final result = await _authApiService.loginFirebaseUser(idToken: idToken);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _goToDashboard(result['user']);
      } else {
        _showMessage(result['message']?.toString() ?? 'Login gagal');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Login gagal: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseAuthService.signInWithGoogle();

      final idToken = await _firebaseAuthService.getFirebaseIdToken();

      final result = await _authApiService.loginFirebaseUser(idToken: idToken);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _goToDashboard(result['user']);
      } else {
        _showMessage(result['message']?.toString() ?? 'Login Google gagal');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Login Google gagal: $e');
    }
  }

  void _goToDashboard(dynamic user) {
    final role = user['role'];

    if (role == 'lansia') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ElderlyDashboardScreen()),
        (route) => false,
      );
    } else if (role == 'keluarga') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FamilyDashboardScreen()),
        (route) => false,
      );
    } else {
      _showMessage('Role tidak dikenali');
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
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
      width: 185,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Column(
          children: const [
            Icon(Icons.health_and_safety, size: 86, color: primaryBlue),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 44,
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

  Widget _buildEmailField() {
    return Container(
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
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
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
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_isLoading) {
            _loginWithEmailPassword();
          }
        },
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
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
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: primaryBlue, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: darkBlue, width: 1.6),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: 165,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _loginWithEmailPassword,
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
                'Masuk',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: 245,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _loginWithGoogle,
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
              'Masuk dengan Google',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Belum punya akun? ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: _isLoading ? null : _goToRegister,
          child: const Text(
            'Daftar disini',
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
              padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),

                    _buildLogo(),

                    const SizedBox(height: 54),

                    _buildLabel('Email'),

                    const SizedBox(height: 8),

                    _buildEmailField(),

                    const SizedBox(height: 24),

                    _buildLabel('Password'),

                    const SizedBox(height: 8),

                    _buildPasswordField(),

                    const SizedBox(height: 34),

                    _buildLoginButton(),

                    const SizedBox(height: 16),

                    _buildGoogleButton(),

                    const SizedBox(height: 24),

                    _buildRegisterLink(),

                    const SizedBox(height: 20),
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
