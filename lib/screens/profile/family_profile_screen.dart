import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/connection_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_camera_screen.dart';

class FamilyProfilScreen extends StatefulWidget {
  const FamilyProfilScreen({super.key});

  @override
  State<FamilyProfilScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfilScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ConnectionService _connectionService = ConnectionService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _name;
  String? _email;
  String? _role;
  String? _profilePhotoPath;

  bool _isLoadingConnections = true;
  List<dynamic> _incomingRequests = [];
  List<dynamic> _connectedElderlies = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFamilyConnectionData();
  }

  Future<void> _loadProfile() async {
    final name = await _storageService.getName();
    final email = await _storageService.getEmail();
    final role = await _storageService.getRole();
    final photoPath = await _storageService.getProfilePhotoPath();

    if (!mounted) return;

    setState(() {
      _name = name;
      _email = email;
      _role = role;
      _profilePhotoPath = photoPath;
    });
  }

  Future<void> _openCameraForProfilePhoto() async {
    final photoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCameraScreen()),
    );

    if (photoPath == null || photoPath.isEmpty) return;

    await _storageService.saveProfilePhotoPath(photoPath);

    if (!mounted) return;

    setState(() {
      _profilePhotoPath = photoPath;
    });

    _showMessage('Foto profile berhasil ditambahkan');
  }

  Future<void> _pickProfilePhotoFromGallery() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
    );

    if (pickedImage == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'profile_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImagePath = path.join(appDir.path, fileName);

    final savedImage = await File(pickedImage.path).copy(savedImagePath);

    await _storageService.saveProfilePhotoPath(savedImage.path);

    if (!mounted) return;

    setState(() {
      _profilePhotoPath = savedImage.path;
    });

    _showMessage('Foto profile berhasil dipilih dari galeri');
  }

  Future<void> _showProfilePhotoOptions() async {
    final hasPhoto = _getProfileImage() != null;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                const Text(
                  'Foto Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.camera_alt, color: Colors.teal),
                  ),
                  title: const Text('Ambil Foto'),
                  subtitle: const Text('Gunakan kamera langsung'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _openCameraForProfilePhoto();
                  },
                ),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  title: const Text('Pilih dari Galeri'),
                  subtitle: const Text('Ambil foto dari penyimpanan HP'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _pickProfilePhotoFromGallery();
                  },
                ),

                if (hasPhoto)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    title: const Text(
                      'Hapus Foto',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _removeProfilePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeProfilePhoto() async {
    await _storageService.removeProfilePhotoPath();

    if (!mounted) return;

    setState(() {
      _profilePhotoPath = null;
    });

    _showMessage('Foto profile berhasil dihapus');
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  ImageProvider? _getProfileImage() {
    if (_profilePhotoPath == null || _profilePhotoPath!.isEmpty) {
      return null;
    }

    final file = File(_profilePhotoPath!);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  Future<void> _loadFamilyConnectionData() async {
    setState(() {
      _isLoadingConnections = true;
    });

    final incomingResult = await _connectionService.getIncomingConnections();
    final connectedResult = await _connectionService.getConnectedElderlies();

    if (!mounted) return;

    setState(() {
      _isLoadingConnections = false;

      if (incomingResult['success'] == true) {
        _incomingRequests = incomingResult['data'] ?? [];
      } else {
        _incomingRequests = [];
      }

      if (connectedResult['success'] == true) {
        _connectedElderlies = connectedResult['data'] ?? [];
      } else {
        _connectedElderlies = [];
      }
    });

    debugPrint('INCOMING REQUESTS: $_incomingRequests');
    debugPrint('CONNECTED ELDERLIES: $_connectedElderlies');
  }

  String _getConnectionId(dynamic item) {
    return item['connection_id']?.toString() ??
        item['connectionId']?.toString() ??
        item['id']?.toString() ??
        '';
  }

  String _getElderlyName(dynamic item) {
    if (item['elderly'] != null) {
      return item['elderly']['name']?.toString() ?? 'Nama tidak tersedia';
    }

    return item['elderly_name']?.toString() ??
        item['elderlyName']?.toString() ??
        item['name']?.toString() ??
        'Nama tidak tersedia';
  }

  String _getElderlyEmail(dynamic item) {
    if (item['elderly'] != null) {
      return item['elderly']['email']?.toString() ?? 'Email tidak tersedia';
    }

    return item['elderly_email']?.toString() ??
        item['elderlyEmail']?.toString() ??
        item['email']?.toString() ??
        'Email tidak tersedia';
  }

  Future<void> _respondIncomingRequest({
    required String connectionId,
    required String status,
  }) async {
    if (connectionId.isEmpty) {
      _showMessage('ID koneksi tidak ditemukan');
      return;
    }

    final result = await _connectionService.updateConnectionStatus(
      connectionId: connectionId,
      status: status,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showMessage(
        status == 'accepted'
            ? 'Permintaan berhasil diterima'
            : 'Permintaan berhasil ditolak',
      );

      await _loadFamilyConnectionData();
    } else {
      _showMessage(result['message'] ?? 'Gagal memproses permintaan');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin logout dari akun ini?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    final initial = (_name != null && _name!.isNotEmpty)
        ? _name!.substring(0, 1).toUpperCase()
        : '?';

    final profileImage = _getProfileImage();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.teal.shade100,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 42,
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                InkWell(
                  onTap: _showProfilePhotoOptions,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _showProfilePhotoOptions,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(profileImage == null ? 'Tambah Foto' : 'Ubah Foto'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            _name ?? '-',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            _email ?? '-',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 16),

          _buildInfoRow(Icons.badge_outlined, 'Role', _role ?? '-'),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
      child: const Column(
        children: [
          Icon(Icons.group_off_outlined, size: 60, color: Colors.teal),
          SizedBox(height: 12),
          Text(
            'Belum ada lansia terhubung & belum ada permintaan terhubung',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Data lansia akan muncul setelah ada permintaan yang diterima.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(dynamic request) {
    final connectionId = _getConnectionId(request);
    final name = _getElderlyName(request);
    final email = _getElderlyEmail(request);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
          const Row(
            children: [
              Icon(Icons.inbox, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Permintaan Terhubung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _respondIncomingRequest(
                      connectionId: connectionId,
                      status: 'rejected',
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _respondIncomingRequest(
                      connectionId: connectionId,
                      status: 'accepted',
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Terima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedElderlyCard(dynamic elderly) {
    final name = _getElderlyName(elderly);
    final email = _getElderlyEmail(elderly);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.teal.shade100,
            child: const Icon(Icons.elderly, color: Colors.teal, size: 30),
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
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    if (_isLoadingConnections) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    if (_incomingRequests.isEmpty && _connectedElderlies.isEmpty) {
      return _buildEmptyConnectionCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_incomingRequests.isNotEmpty) ...[
          const Text(
            'Permintaan Masuk',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._incomingRequests.map(_buildIncomingRequestCard),
          const SizedBox(height: 18),
        ],
        if (_connectedElderlies.isNotEmpty) ...[
          const Text(
            'Lansia Terhubung',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._connectedElderlies.map(_buildConnectedElderlyCard),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _name == null
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : RefreshIndicator(
                onRefresh: _loadFamilyConnectionData,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildProfileInfo(),
                    const SizedBox(height: 28),
                    _buildConnectionSection(),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
