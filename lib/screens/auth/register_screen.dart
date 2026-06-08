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

  Future<void> _registerWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi');
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
              title: const Text('Verifikasi Email'),
              content: const Text(
                'Link verifikasi sudah dikirim ke email kamu. '
                'Buka email, klik link verifikasi, lalu tekan tombol "Saya sudah verifikasi".',
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

                            final idToken =
                                await _firebaseAuthService.getFirebaseIdToken();

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompleteProfileScreen(
                                  firebaseIdToken: idToken,
                                  initialName: _getNameFromEmail(
                                    currentUser.email ?? '',
                                  ),
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
                  child: isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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

      Navigator.push(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Daftar Akun'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(
                    Icons.health_and_safety,
                    size: 64,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Daftar RASA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Buat akun menggunakan email atau Google',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'contoh@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : _registerWithEmailPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Memproses...' : 'Daftar dengan Email',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _registerWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text(
                      'Daftar dengan Google',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text('Sudah punya akun? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}