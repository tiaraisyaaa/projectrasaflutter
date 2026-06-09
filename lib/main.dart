import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/storage_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/elderly_dashboard_screen.dart';
import 'screens/dashboard/family_dashboard_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        colorSchemeSeed: Colors.teal,
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final bool isLoggedIn = await _storageService.isLoggedIn();
    final String? role = await _storageService.getRole();

    if (!mounted) return;

    if (!isLoggedIn || role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
      return;
    }

    if (role == 'lansia') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ElderlyDashboardScreen(),
        ),
      );
    } else if (role == 'keluarga') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const FamilyDashboardScreen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F8F8),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.teal,
        ),
      ),
    );
  }
}