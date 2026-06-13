import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/connection_service.dart';
import '../auth/login_screen.dart';
import '../connection/send_connection_request_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_camera_screen.dart';

class ElderlyProfileScreen extends StatefulWidget {
  const ElderlyProfileScreen({super.key});

  @override
  State<ElderlyProfileScreen> createState() => _ElderlyProfileScreenState();
}

class _ElderlyProfileScreenState extends State<ElderlyProfileScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ConnectionService _connectionService = ConnectionService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _name;
  String? _email;
  String? _role;
  String? _profilePhotoPath;

  bool _isLoadingFamilies = true;
  List<dynamic> _families = [];
  Map<String, String>? _pendingFamilyRequest;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color softHeader = Color(0xFFBFE7E8);
  static const Color pageBackground = Color(0xFFF1FAFF);
  static const Color darkText = Color(0xFF3F3F3F);

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

  Future<void> _openSendConnectionRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SendConnectionRequestScreen()),
    );

    await _loadConnectedFamilies();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return '-';

    if (role.toLowerCase() == 'lansia') {
      return 'Lansia';
    }

    if (role.toLowerCase() == 'keluarga') {
      return 'Keluarga';
    }

    return role;
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

  Widget _buildAvatar({double radius = 72, bool showCameraButton = true}) {
    final profileImage = _getProfileImage();
    final initial = (_name != null && _name!.isNotEmpty)
        ? _name!.substring(0, 1).toUpperCase()
        : '?';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: _showProfilePhotoOptions,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade600,
            backgroundImage: profileImage,
            child: profileImage == null
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: radius * 0.62,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        ),
        if (showCameraButton)
          GestureDetector(
            onTap: _showProfilePhotoOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 34, 24, 44),
      decoration: const BoxDecoration(
        color: softHeader,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(95),
          bottomRight: Radius.circular(95),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              _buildAvatar(radius: 72),
              const SizedBox(width: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.05,
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatRole(_role),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              children: [
                _buildSmallHeaderButton(
                  icon: Icons.edit_outlined,
                  onTap: _openEditProfile,
                ),
                const SizedBox(width: 8),
                _buildSmallHeaderButton(icon: Icons.logout, onTap: _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: primaryBlue),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildBiodataRow(label: 'Nama', value: _name ?? '-'),
          const SizedBox(height: 22),
          _buildBiodataRow(label: 'Email', value: _email ?? '-'),
          const SizedBox(height: 22),
          _buildBiodataRow(label: 'Alamat', value: 'Belum tersedia'),
        ],
      ),
    );
  }

  Widget _buildBiodataRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              height: 1.2,
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Text(
          ':',
          style: TextStyle(
            fontSize: 20,
            height: 1.2,
            color: darkText,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              height: 1.2,
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestCard() {
    final name =
        _pendingFamilyRequest?['name'] ?? 'Nama keluarga tidak tersedia';
    final email =
        _pendingFamilyRequest?['email'] ?? 'Email keluarga tidak tersedia';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.orange.shade100,
            child: const Icon(
              Icons.hourglass_top,
              color: Colors.orange,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permintaan sedang diproses',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    color: darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(999),
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

  Widget _buildConnectedFamilyItem(dynamic family) {
    final name = _getFamilyName(family);
    final email = _getFamilyEmail(family);
    final photoUrl = _getFamilyPhoto(family);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.grey.shade600,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 54)
                : null,
          ),
          const SizedBox(height: 16),
          _buildBiodataRow(label: 'Nama', value: name),
          const SizedBox(height: 18),
          _buildBiodataRow(label: 'Email', value: email),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    if (_isLoadingFamilies) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    }

    if (_families.isEmpty && _pendingFamilyRequest != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keluarga yang terhubung',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),
          _buildPendingRequestCard(),
        ],
      );
    }

    if (_families.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belum ada keluarga yang terhubung',
            style: TextStyle(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openSendConnectionRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: primaryBlue.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text(
                'Hubungkan Keluarga',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keluarga yang terhubung',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 18),
        ..._families.map(_buildConnectedFamilyItem),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 40,
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.home_rounded, color: Colors.grey),
            ),
            IconButton(
              iconSize: 40,
              onPressed: () {},
              icon: const Icon(Icons.person_rounded, color: Color(0xFF0789BD)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      bottomNavigationBar: _buildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: _name == null
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadProfile();
                  await _loadConnectedFamilies();
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 46, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 80),
                          _buildConnectionSection(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
