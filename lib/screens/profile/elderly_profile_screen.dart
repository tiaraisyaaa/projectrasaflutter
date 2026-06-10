import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../auth/login_screen.dart';
import '../connection/send_connection_request_screen.dart';
import '../../services/connection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElderlyProfileScreen extends StatefulWidget {
  const ElderlyProfileScreen({super.key});

  @override
  State<ElderlyProfileScreen> createState() => _ElderlyProfileScreenState();
}

class _ElderlyProfileScreenState extends State<ElderlyProfileScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ConnectionService _connectionService = ConnectionService();

  String? _name;
  String? _email;
  String? _role;
  bool _isLoadingFamilies = true;
List<dynamic> _families = [];
Map<String, String>? _pendingFamilyRequest;
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadConnectedFamilies();
  }

  Future<void> _loadProfile() async {
    final name = await _storageService.getName();
    final email = await _storageService.getEmail();
    final role = await _storageService.getRole();
    // final ConnectionService _connectionService = ConnectionService();

    if (!mounted) return;

    setState(() {
      _name = name;
      _email = email;
      _role = role;
    });
  }

// Future<void> _loadConnectedFamilies() async {
//   if (!mounted) return;

//   setState(() {
//     _isLoadingFamilies = true;
//   });

//   try {
//     final result = await _connectionService.getConnectedFamilies();

//     debugPrint('RESULT CONNECTED FAMILIES: $result');

//     if (!mounted) return;

//     if (result['success'] == true) {
//       final rawData = result['data'];

//       List<dynamic> families = [];

//       if (rawData is List) {
//         families = rawData;
//       }

//       setState(() {
//         _families = families;
//         _isLoadingFamilies = false;
//       });

//       debugPrint('FAMILIES DATA: $_families');
//       debugPrint('FAMILIES LENGTH: ${_families.length}');
//     } else {
//       setState(() {
//         _families = [];
//         _isLoadingFamilies = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(result['message'] ?? 'Gagal load data keluarga'),
//         ),
//       );
//     }
//   } catch (e) {
//     debugPrint('ERROR LOAD CONNECTED FAMILIES: $e');

//     if (!mounted) return;

//     setState(() {
//       _families = [];
//       _isLoadingFamilies = false;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Gagal mengambil data keluarga: $e'),
//       ),
//     );
//   }
// }


Future<void> _loadConnectedFamilies() async {
  if (!mounted) return;

  setState(() {
    _isLoadingFamilies = true;
  });

  try {
    final result = await _connectionService.getConnectedFamilies();
    final pendingRequest = await _storageService.getPendingFamilyRequest();

    if (!mounted) return;

    List<dynamic> families = [];

    if (result['success'] == true && result['data'] is List) {
      families = result['data'];
    }

    if (families.isNotEmpty) {
      await _storageService.clearPendingFamilyRequest();
    }

    setState(() {
      _families = families;
      _pendingFamilyRequest = families.isEmpty ? pendingRequest : null;
      _isLoadingFamilies = false;
    });
  } catch (e) {
    debugPrint('ERROR LOAD CONNECTION DATA: $e');

    if (!mounted) return;

    setState(() {
      _families = [];
      _pendingFamilyRequest = null;
      _isLoadingFamilies = false;
    });
  }
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

  String _getFamilyName(dynamic family) {
  return family['family']?['name']?.toString() ??
      family['family_name']?.toString() ??
      family['familyName']?.toString() ??
      family['name']?.toString() ??
      'Nama tidak tersedia';
}

String _getFamilyEmail(dynamic family) {
  return family['family']?['email']?.toString() ??
      family['family_email']?.toString() ??
      family['familyEmail']?.toString() ??
      family['email']?.toString() ??
      'Email tidak tersedia';
}

String? _getFamilyPhoto(dynamic family) {
  return family['family']?['photo_url']?.toString() ??
      family['family_photo_url']?.toString() ??
      family['familyPhotoUrl']?.toString() ??
      family['photo_url']?.toString();
}

Widget _buildPendingRequestCard() {
  final name = _pendingFamilyRequest?['name'] ?? 'Nama keluarga tidak tersedia';
  final email = _pendingFamilyRequest?['email'] ?? 'Email keluarga tidak tersedia';

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.orange.shade100,
          child: const Icon(
            Icons.hourglass_top,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sedang mengirim permintaan terhubung',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'pending',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
            // : SingleChildScrollView( 
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
                    
                    const SizedBox(height: 24),

if (!_isLoadingFamilies &&
    _families.isEmpty &&
    _pendingFamilyRequest == null) ...[
  Center(
    child: ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SendConnectionRequestScreen(),
          ),
        );
      },
      icon: const Icon(Icons.group_add),
      label: const Text(
        'Hubungkan Keluarga',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 6,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  ),
  const SizedBox(height: 24),
],

if (!_isLoadingFamilies &&
    _families.isEmpty &&
    _pendingFamilyRequest != null) ...[
  _buildPendingRequestCard(),
  const SizedBox(height: 24),
],

if (!_isLoadingFamilies && _families.isNotEmpty) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                const SizedBox(height: 14),

        const Text(
          'Keluarga Terhubung',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 14),

        ..._families.map((family) {
          final name = _getFamilyName(family);
          final email = _getFamilyEmail(family);
          final photoUrl = _getFamilyPhoto(family);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.teal.shade100,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.teal)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  ),
  const SizedBox(height: 24),
],


const SizedBox(height: 24),
                            // _buildConnectedFamilies(),
                            // const SizedBox(height: 24),
                            //                     const Spacer(),
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
                              

  Widget _buildConnectedFamilies() {
  if (_isLoadingFamilies) {
    return const Center(child: CircularProgressIndicator(color: Colors.teal));
  }

  if (_families.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: const [
          Icon(Icons.group_off_outlined, size: 70, color: Colors.teal),
          SizedBox(height: 16),
          Text(
            'Belum ada keluarga terhubung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Keluarga yang sudah menerima permintaan akan tampil di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  return Column(
    children: _families.map((family) {
      final name = family['family']?['name'] ?? 'Nama tidak tersedia';
      final email = family['family']?['email'] ?? 'Email tidak tersedia';

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0,6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      );
    }).toList(),
  );
}
}