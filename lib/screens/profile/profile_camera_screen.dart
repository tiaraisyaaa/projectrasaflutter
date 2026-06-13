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

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Kamera tidak tersedia di perangkat ini';
        });
        return;
      }

      await _initializeSelectedCamera();
    } on CameraException catch (e) {
      setState(() {
        if (e.code == 'CameraAccessDenied') {
          _errorMessage =
              'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi.';
        } else {
          _errorMessage = 'Gagal membuka kamera: ${e.description ?? e.code}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal membuka kamera: $e';
      });
    }
  }

  Future<void> _initializeSelectedCamera() async {
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller = controller;
    _initializeCameraFuture = controller.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ambil Foto Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Ganti Kamera',
            ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorState()
          : controller == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : FutureBuilder<void>(
              future: _initializeCameraFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      Positioned.fill(child: CameraPreview(controller)),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 32,
                        child: Center(
                          child: GestureDetector(
                            onTap: _isTakingPicture ? null : _takeProfilePhoto,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _isTakingPicture
                                        ? Colors.grey
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isTakingPicture
                                      ? const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.black,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Kamera gagal dimuat: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _errorMessage ?? 'Terjadi kesalahan kamera',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
