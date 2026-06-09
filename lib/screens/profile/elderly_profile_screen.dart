import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../auth/login_screen.dart';

class ElderlyProfileScreen extends StatefulWidget {
  const ElderlyProfileScreen({super.key});

  @override
  State<ElderlyProfileScreen> createState() => _ElderlyProfileScreenState();
}

class _ElderlyProfileScreenState extends State<ElderlyProfileScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  String? _name;
  String? _email;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _storageService.getName();
    final email = await _storageService.getEmail();
    final role = await _storageService.getRole();

    if (!mounted) return;

    setState(() {
      _name = name;
      _email = email;
      _role = role;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin logout dari akun ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _authService.logout();
    await _storageService.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Lansia'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _name == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal.shade100,
                      child: Text(
                        _name!.isNotEmpty ? _name![0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Nama:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_name ?? '-'),
                    const SizedBox(height: 12),
                    Text('Email:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_email ?? '-'),
                    const SizedBox(height: 12),
                    Text('Role:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_role ?? '-'),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}