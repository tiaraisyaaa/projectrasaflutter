import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/connection_service.dart';
import '../../services/profile_service.dart';
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
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _name;
  String? _email;
  String? _phone;
  String? _role;
  String? _profilePhotoPath;
  String? _profilePhotoUrl;

  bool _isLoadingFamilies = true;
  bool _isUploadingPhoto = false;

  List<dynamic> _families = [];
  Map<String, String>? _pendingFamilyRequest;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softHeader = Color(0xFFBFE7E8);
  static const Color pageBackground = Color(0xFFF1FAFF);
  static const Color cardBackground = Colors.white;
  static const Color softCardBlue = Color(0xFFEAF7FF);
  static const Color darkText = Color(0xFF263238);
  static const Color mutedText = Color(0xFF607D8B);
  static const Color successGreen = Color(0xFF2E7D62);
  static const Color warningOrange = Color(0xFFE58B20);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadConnectedFamilies();
  }

  bool _isValidPhotoUrl(String? value) {
    if (value == null) return false;

    final photoUrl = value.trim();

    if (photoUrl.isEmpty) return false;
    if (photoUrl.toLowerCase() == 'null') return false;
    if (photoUrl == '-') return false;

    return true;
  }

  Future<void> _loadProfile() async {
    final profileResult = await _profileService.getProfile();

    final localName = await _storageService.getName();
    final localEmail = await _storageService.getEmail();
    final localRole = await _storageService.getRole();
    final photoPath = await _storageService.getProfilePhotoPath();
    final photoUrl = await _storageService.getProfilePhotoUrl();

    String? name = localName;
    String? email = localEmail;
    String? phone;
    String? role = localRole;

    if (profileResult['success'] == true) {
      final user = profileResult['user'];

      if (user is Map<String, dynamic>) {
        name = user['name']?.toString() ?? localName;
        email = user['email']?.toString() ?? localEmail;
        phone = user['phone']?.toString() ??
            user['phone_number']?.toString() ??
            user['phoneNumber']?.toString();
        role = user['role']?.toString() ?? localRole;
      }
    }

    if (!mounted) return;

    setState(() {
      _name = name;
      _email = email;
      _phone = phone;
      _role = role;
      _profilePhotoPath = photoPath;
      _profilePhotoUrl = _isValidPhotoUrl(photoUrl) ? photoUrl : null;
    });
  }

  Future<void> _uploadProfilePhotoToBackend(String photoPath) async {
    final photoFile = File(photoPath);

    if (!photoFile.existsSync()) {
      _showMessage('File foto tidak ditemukan');
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    final result = await _profileService.uploadProfilePhoto(
      photoFile: photoFile,
    );

    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
    });

    if (result['success'] == true) {
      final photoUrl = result['photo_url']?.toString();

      await _storageService.saveProfilePhotoPath(photoPath);

      if (_isValidPhotoUrl(photoUrl)) {
        await _storageService.saveProfilePhotoUrl(photoUrl!.trim());
      } else {
        await _storageService.removeProfilePhotoUrl();
      }

      imageCache.clear();
      imageCache.clearLiveImages();

      if (!mounted) return;

      setState(() {
        _profilePhotoPath = photoPath;
        _profilePhotoUrl = _isValidPhotoUrl(photoUrl) ? photoUrl!.trim() : null;
      });

      _showMessage('Foto profile berhasil diperbarui');
    } else {
      _showMessage(
        result['message']?.toString() ?? 'Gagal upload foto profile',
      );
    }
  }

  Future<void> _openCameraForProfilePhoto() async {
    final photoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCameraScreen()),
    );

    if (photoPath == null || photoPath.isEmpty) return;

    await _uploadProfilePhotoToBackend(photoPath);
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

    await _uploadProfilePhotoToBackend(savedImage.path);
  }

  Future<void> _showProfilePhotoOptions() async {
    final hasPhoto = _getProfileImage() != null;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Text(
                  'Foto Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih cara untuk mengganti foto akun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPhotoOptionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Ambil Foto',
                  subtitle: 'Gunakan kamera langsung',
                  color: primaryBlue,
                  onTap: _isUploadingPhoto
                      ? null
                      : () {
                          Navigator.pop(bottomSheetContext);
                          _openCameraForProfilePhoto();
                        },
                ),
                const SizedBox(height: 12),
                _buildPhotoOptionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Pilih dari Galeri',
                  subtitle: 'Ambil foto dari penyimpanan HP',
                  color: successGreen,
                  onTap: _isUploadingPhoto
                      ? null
                      : () {
                          Navigator.pop(bottomSheetContext);
                          _pickProfilePhotoFromGallery();
                        },
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 12),
                  _buildPhotoOptionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Hapus Foto',
                    subtitle: 'Kembalikan ke avatar huruf',
                    color: Colors.red,
                    onTap: _isUploadingPhoto
                        ? null
                        : () {
                            Navigator.pop(bottomSheetContext);
                            _removeProfilePhoto();
                          },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeProfilePhoto() async {
    setState(() {
      _isUploadingPhoto = true;
    });

    final result = await _profileService.deleteProfilePhoto();

    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
    });

    if (result['success'] == true) {
      await _storageService.removeProfilePhotoPath();
      await _storageService.removeProfilePhotoUrl();

      imageCache.clear();
      imageCache.clearLiveImages();

      if (!mounted) return;

      setState(() {
        _profilePhotoPath = null;
        _profilePhotoUrl = null;
      });

      _showMessage('Foto profile berhasil dihapus dari dihapus');
    } else {
      _showMessage(
        result['message']?.toString() ?? 'Gagal menghapus foto profile',
      );
    }
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
    if (_isValidPhotoUrl(_profilePhotoUrl)) {
      return NetworkImage(_profilePhotoUrl!.trim());
    }

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

    imageCache.clear();
    imageCache.clearLiveImages();

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
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Apakah Anda yakin ingin logout dari akun ini?',
            style: TextStyle(fontSize: 16),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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
    final rawPhotoUrl =
        family['family']?['photo_url']?.toString() ??
        family['family']?['photoUrl']?.toString() ??
        family['family_photo_url']?.toString() ??
        family['familyPhotoUrl']?.toString() ??
        family['photo_url']?.toString() ??
        family['photoUrl']?.toString();

    if (!_isValidPhotoUrl(rawPhotoUrl)) {
      return null;
    }

    return rawPhotoUrl!.trim();
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
          onTap: _isUploadingPhoto ? null : _showProfilePhotoOptions,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              key: ValueKey(
                _profilePhotoUrl ?? _profilePhotoPath ?? 'no-photo',
              ),
              radius: radius,
              backgroundColor: primaryBlue,
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: radius * 0.58,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (_isUploadingPhoto)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.8,
                ),
              ),
            ),
          ),
        if (showCameraButton && !_isUploadingPhoto)
          GestureDetector(
            onTap: _showProfilePhotoOptions,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      decoration: const BoxDecoration(
        color: softHeader,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.elderly_rounded,
                        color: primaryBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Profile Lansia',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          color: darkText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildSmallHeaderButton(
                icon: Icons.logout_rounded,
                tooltip: 'Logout',
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _buildAvatar(radius: 76),
          const SizedBox(height: 18),
          Text(
            _name ?? '-',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 31,
              height: 1.08,
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _formatRole(_role),
              style: const TextStyle(
                fontSize: 17,
                color: primaryBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 24, color: primaryBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Diri',
            style: TextStyle(
              fontSize: 24,
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _buildBiodataRow(
            icon: Icons.person_outline_rounded,
            label: 'Nama',
            value: _name ?? '-',
          ),
          const SizedBox(height: 14),
          _buildBiodataRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _email ?? '-',
          ),
          const SizedBox(height: 14),
          _buildBiodataRow(
            icon: Icons.phone_outlined,
            label: 'Nomor HP',
            value: _phone ?? '-',
          ),
          const SizedBox(height: 14),
          _buildBiodataRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: _formatRole(_role),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_rounded, size: 24),
              label: const Text(
                'Edit Profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: primaryBlue.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildBiodataRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softCardBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryBlue.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    color: darkText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryBlue, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                ),
              ),
            ],
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
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: warningOrange.withOpacity(0.14),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: warningOrange,
              size: 36,
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
                    fontSize: 19,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    color: darkText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: warningOrange.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Menunggu diterima',
                    style: TextStyle(
                      color: warningOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            key: ValueKey('family-$email-${photoUrl ?? 'no-photo'}'),
            radius: 36,
            backgroundColor: darkBlue,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 42,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: mutedText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Terhubung',
                    style: TextStyle(
                      color: successGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

  Widget _buildConnectionSection() {
    if (_isLoadingFamilies) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            CircularProgressIndicator(color: primaryBlue),
            SizedBox(height: 16),
            Text(
              'Memuat data keluarga...',
              style: TextStyle(color: mutedText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (_families.isEmpty && _pendingFamilyRequest != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: 'Keluarga Terhubung',
            subtitle: 'Status permintaan hubungan keluarga Anda',
            icon: Icons.family_restroom_rounded,
          ),
          const SizedBox(height: 18),
          _buildPendingRequestCard(),
        ],
      );
    }

    if (_families.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: primaryBlue,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada keluarga terhubung',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hubungkan akun keluarga agar mereka dapat memantau kondisi dan notifikasi Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openSendConnectionRequest,
                icon: const Icon(Icons.group_add_rounded, size: 25),
                label: const Text(
                  'Hubungkan Keluarga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: primaryBlue.withOpacity(0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Keluarga Terhubung',
          subtitle: 'Keluarga yang dapat memantau kondisi Anda',
          icon: Icons.family_restroom_rounded,
        ),
        const SizedBox(height: 18),
        ..._families.map(_buildConnectedFamilyItem),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryBlue.withOpacity(0.18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primaryBlue, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Akun lansia hanya dapat terhubung dengan satu keluarga.',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: 72,
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
        child: Row(
          children: [
            Expanded(
              child: _buildBottomNavItem(
                icon: Icons.home_rounded,
                label: 'Beranda',
                isActive: false,
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            Expanded(
              child: _buildBottomNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                isActive: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? primaryBlue : Colors.grey.shade500;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    imageCache.clear();
    imageCache.clearLiveImages();

    await _loadProfile();
    await _loadConnectedFamilies();
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
                color: primaryBlue,
                onRefresh: _refreshAll,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 24),
                          _buildConnectionSection(),
                          const SizedBox(height: 48),
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