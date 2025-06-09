import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/camera_manager.dart';
import '../widgets/timer_selector_widget.dart';

/// Layar utama untuk mengambil foto.
/// Menampilkan preview kamera, kontrol dasar (flash, ganti kamera),
/// fitur smile-to-shoot, dan akses ke galeri.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> with AutomaticKeepAliveClientMixin<PhotoScreen> {
  // State dan logika untuk layar ini sudah dipindahkan ke CameraManager
  // untuk mendukung arsitektur yang terpusat dan reaktif.

  @override
  bool get wantKeepAlive => true; // Menjaga state layar agar tidak hilang saat di-swipe.

  // --- UI Callbacks & Helpers ---

  /// Menangani aksi saat tombol shutter ditekan (mengambil foto atau membatalkan timer).
  void _handleShutterPress() {
    Provider.of<CameraManager>(context, listen: false).triggerPhotoCapture();
  }

  /// Menampilkan pesan singkat (SnackBar) kepada pengguna.
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// Menampilkan galeri foto dalam sebuah modal bottom sheet.
  void _showGallery(BuildContext context, CameraManager cameraManager) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // Consumer digunakan agar galeri ikut refresh jika ada foto yang dihapus.
        return Consumer<CameraManager>(
          builder: (context, manager, child) {
            return DraggableScrollableSheet(
              expand: false, initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
              builder: (_, scrollController) => Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(
                  children: [
                    // Header Galeri
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Gallery (${manager.savedPhotos.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                    // Konten Grid Foto
                    Expanded(
                      child: manager.savedPhotos.isEmpty
                          ? const Center(child: Text('No photos saved yet'))
                          : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: manager.savedPhotos.length,
                        itemBuilder: (context, index) {
                          final photoPath = manager.savedPhotos[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _showFullImage(photoPath);
                                },
                                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photoPath), fit: BoxFit.cover)),
                              ),
                              Positioned(
                                top: 4, right: 4,
                                child: Container(
                                  width: 30, height: 30,
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                                    onPressed: () => _confirmDeletePhoto(context, manager, photoPath),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Menampilkan dialog konfirmasi sebelum menghapus foto.
  void _confirmDeletePhoto(BuildContext modalContext, CameraManager manager, String path) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              manager.deletePhoto(path);
              Navigator.pop(dialogContext); // Tutup dialog konfirmasi
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Menampilkan gambar dalam ukuran penuh.
  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.file(File(imagePath), fit: BoxFit.contain),
            Positioned(
              top: 20,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<CameraManager>(
      builder: (context, cameraManager, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // --- LAPISAN 1: PREVIEW KAMERA ---
              if (cameraManager.isCameraInitialized)
                Positioned.fill(
                  child: ClipRect(
                    child: Builder(
                      builder: (context) {
                        final camera = cameraManager.controller!;
                        final size = MediaQuery.of(context).size;
                        var scale = size.aspectRatio * camera.value.aspectRatio;
                        if (scale < 1) scale = 1 / scale;
                        return Transform.scale(
                          scale: scale,
                          child: Center(child: CameraPreview(camera)),
                        );
                      },
                    ),
                  ),
                )
              else
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),

              // --- LAPISAN 2: INDIKATOR SMILE & WAJAH ---
              if (cameraManager.isSmileDetectionOn && !cameraManager.isCountingDown)
                Positioned(
                  bottom: 180,
                  left: 16,
                  right: 16,
                  child: Opacity(
                    opacity: 0.85,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30, width: 1)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(cameraManager.detectedFaceCount > 0 ? Icons.face_retouching_natural : Icons.face_outlined, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text('${cameraManager.detectedFaceCount}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              Text(cameraManager.isSmiling ? 'Smile Detected! 😊' : 'Smile to Capture', style: TextStyle(color: cameraManager.isSmiling ? Colors.greenAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Icon(cameraManager.isSmiling ? Icons.sentiment_very_satisfied : Icons.sentiment_neutral, color: cameraManager.isSmiling ? Colors.greenAccent : Colors.white, size: 24),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // --- LAPISAN 3: KONTROL ATAS & TIMER ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    children: [
                      const TimerSelectorWidget(),
                      if (!cameraManager.isCountingDown)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(icon: Icon(cameraManager.isFlashOn ? Icons.flash_on : Icons.flash_off, color: cameraManager.isFlashOn ? Colors.yellow : Colors.white), onPressed: cameraManager.toggleFlash),
                              IconButton(icon: Icon(cameraManager.isSmileDetectionOn ? Icons.sentiment_very_satisfied : Icons.sentiment_neutral, color: cameraManager.isSmileDetectionOn ? Colors.yellow : Colors.white), onPressed: cameraManager.toggleSmileDetection),
                              IconButton(icon: const Icon(Icons.switch_camera, color: Colors.white), onPressed: cameraManager.switchCamera),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- LAPISAN 4: COUNTDOWN ---
              if (cameraManager.isCountingDown)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${cameraManager.countdownValue}',
                      style: const TextStyle(color: Colors.white, fontSize: 150, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 20, color: Colors.black87)]),
                    ),
                  ),
                ),

              // --- LAPISAN 5: KONTROL BAWAH ---
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _handleShutterPress,
                          child: Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.transparent, border: Border.all(color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, width: 4)),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: Icon(cameraManager.isCountingDown ? Icons.close : Icons.photo_camera, key: ValueKey<bool>(cameraManager.isCountingDown), color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, size: 35),
                            ),
                          ),
                        ),
                      ),
                      if (!cameraManager.isCountingDown)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.15),
                            child: GestureDetector(
                              onTap: () => _showGallery(context, cameraManager),
                              child: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1)),
                                child: cameraManager.lastPhotoPath != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(cameraManager.lastPhotoPath!), fit: BoxFit.cover)) : const Icon(Icons.photo_library_outlined, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}