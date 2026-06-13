import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'services/storage_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/elderly_dashboard_screen.dart';
import 'screens/dashboard/family_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await dotenv.load(fileName: ".env");

  runApp(const RasaApp());
}

class RasaApp extends StatelessWidget {
  const RasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RASA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2F73AD),
        scaffoldBackgroundColor: const Color(0xFFF7FCFF),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final StorageService _storageService = StorageService();

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(seconds: 2));

    await _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final bool isLoggedIn = await _storageService.isLoggedIn();
    final String? role = await _storageService.getRole();

    if (!mounted) return;

    if (!isLoggedIn || role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (role == 'lansia') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ElderlyDashboardScreen()),
      );
    } else if (role == 'keluarga') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FamilyDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon/logo.png',
      width: 320,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.health_and_safety, size: 110, color: primaryBlue),
            SizedBox(height: 14),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Real-time Asisten Siaga Aktivitas Lansia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(child: Center(child: _buildLogo())),
      ),
    );
  }
}
