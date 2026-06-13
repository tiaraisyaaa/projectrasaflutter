import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({super.key});

  @override
  State<ProfileCameraScreen> createState() => _ProfileCameraScreenState();
}

class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeCameraFuture;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isTakingPicture = false;
  String? _errorMessage;

  static const Color primaryBlue = Color(0xFF2F73AD);

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'Kamera tidak tersedia di perangkat ini';
        });
        return;
      }

      final frontCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (frontCameraIndex != -1) {
        _selectedCameraIndex = frontCameraIndex;
      }

      await _initializeSelectedCamera();
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'CameraAccessDenied') {
          _errorMessage =
              'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi.';
        } else {
          _errorMessage = 'Gagal membuka kamera: ${e.description ?? e.code}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Gagal membuka kamera: $e';
      });
    }
  }

  Future<void> _initializeSelectedCamera() async {
    final oldController = _controller;
    _controller = null;

    if (mounted) {
      setState(() {});
    }

    await oldController?.dispose();

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;
    _initializeCameraFuture = controller.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isTakingPicture) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _initializeSelectedCamera();
  }

  Future<void> _takeProfilePhoto() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    try {
      setState(() {
        _isTakingPicture = true;
      });

      await _initializeCameraFuture;

      final XFile photo = await controller.takePicture();

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImagePath = path.join(appDir.path, fileName);

      final savedImage = await File(photo.path).copy(savedImagePath);

      if (!mounted) return;

      Navigator.pop(context, savedImage.path);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal mengambil foto: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview(CameraController controller) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _buildCircleButton(
                icon: Icons.close_rounded,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              const Text(
                'Ambil Foto Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _buildCircleButton(
                icon: Icons.cameraswitch_rounded,
                onTap: _cameras.length > 1 ? _switchCamera : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            icon,
            color: onTap == null ? Colors.white38 : Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildFaceGuide() {
    return Center(
      child: Container(
        width: 260,
        height: 330,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(140),
          border: Border.all(color: Colors.white.withOpacity(0.85), width: 3),
        ),
      ),
    );
  }

  Widget _buildInstructionText() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 130,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Posisikan wajah di tengah, lalu tekan tombol kamera.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: SafeArea(
        top: false,
        child: Center(
          child: GestureDetector(
            onTap: _isTakingPicture ? null : _takeProfilePhoto,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isTakingPicture ? Colors.grey : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _isTakingPicture
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBody(CameraController controller) {
    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            children: [
              _buildCameraPreview(controller),
              Container(color: Colors.black.withOpacity(0.08)),
              _buildFaceGuide(),
              _buildTopBar(),
              _buildInstructionText(),
              _buildCaptureButton(),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            message: 'Kamera gagal dimuat: ${snapshot.error}',
          );
        }

        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );
  }

  Widget _buildErrorState({String? message}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 76,
              ),
              const SizedBox(height: 18),
              Text(
                message ?? _errorMessage ?? 'Terjadi kesalahan kamera',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });

                  _setupCamera();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Kembali',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _errorMessage != null
          ? _buildErrorState()
          : controller == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildCameraBody(controller),
    );
  }
}
