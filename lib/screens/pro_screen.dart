import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/camera_manager.dart';
import '../widgets/timer_selector_widget.dart';

/// Layar yang menyediakan kontrol manual (Pro) atas kamera.
/// Pengguna dapat mengatur Exposure (EV) dan Zoom melalui slider.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> with AutomaticKeepAliveClientMixin<ProScreen> {
  @override
  bool get wantKeepAlive => true; // Menjaga state layar agar tidak hilang saat di-swipe.

  // --- UI Callbacks ---

  /// Menangani aksi saat tombol shutter ditekan.
  void _handleShutterPress() {
    final cameraManager = Provider.of<CameraManager>(context, listen: false);

    if (cameraManager.isCountingDown) {
      cameraManager.cancelCountdown();
    } else {
      // Panggil fungsi capture dari manager. Manager akan menangani sisanya.
      cameraManager.triggerPhotoCapture();

      // Beri feedback singkat kepada pengguna.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capturing with pro settings...'), duration: Duration(seconds: 1)),
      );
    }
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

              // --- LAPISAN 2: UI TIMER & COUNTDOWN ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: const TimerSelectorWidget()),
              ),
              if (cameraManager.isCountingDown)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${cameraManager.countdownValue}',
                      style: const TextStyle(color: Colors.white, fontSize: 150, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 20, color: Colors.black87)]),
                    ),
                  ),
                ),

              // --- LAPISAN 3: KONTROL PRO (SLIDERS) ---
              // Hanya tampil jika kamera siap dan tidak sedang countdown.
              if (cameraManager.isCameraInitialized && !cameraManager.isCountingDown)
                Positioned(
                  left: 16,
                  bottom: 100,
                  top: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Slider Exposure (EV)
                        const RotatedBox(quarterTurns: -1, child: Text('EV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        RotatedBox(
                          quarterTurns: -1,
                          child: SizedBox(
                            height: 50,
                            width: MediaQuery.of(context).size.height * 0.25,
                            child: Slider(
                              value: cameraManager.currentExposure,
                              min: cameraManager.minExposure,
                              max: cameraManager.maxExposure,
                              label: cameraManager.currentExposure.toStringAsFixed(1),
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white38,
                              onChanged: (value) {
                                cameraManager.setExposure(value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Slider Zoom
                        const RotatedBox(quarterTurns: -1, child: Text('ZOOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        RotatedBox(
                          quarterTurns: -1,
                          child: SizedBox(
                            height: 50,
                            width: MediaQuery.of(context).size.height * 0.25,
                            child: Slider(
                              value: cameraManager.currentZoom,
                              min: cameraManager.minZoom,
                              max: cameraManager.maxZoom > 8 ? 8 : cameraManager.maxZoom, // Batasi max zoom di UI
                              label: '${cameraManager.currentZoom.toStringAsFixed(1)}x',
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white38,
                              onChanged: (value) {
                                cameraManager.setZoom(value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // --- LAPISAN 4: KONTROL KANAN (TOMBOL-TOMBOL) ---
              Positioned(
                bottom: 100,
                right: 16,
                left: 16,
                child: SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Tombol Shutter / Cancel
                      Align(
                        alignment: Alignment.bottomRight,
                        child: GestureDetector(
                          onTap: _handleShutterPress,
                          child: Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, width: 4),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: Icon(cameraManager.isCountingDown ? Icons.close : Icons.photo_camera, key: ValueKey<bool>(cameraManager.isCountingDown), color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, size: 35),
                            ),
                          ),
                        ),
                      ),
                      // Tombol Ganti Kamera & Fokus
                      if (!cameraManager.isCountingDown)
                        Positioned(
                          right: 12,
                          bottom: 86,
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.switch_camera_outlined, color: Colors.white, size: 32),
                                onPressed: () => cameraManager.switchCamera(),
                              ),
                              const SizedBox(height: 16),
                              IconButton(
                                icon: Icon(
                                  cameraManager.isAutoFocus ? Icons.center_focus_strong : Icons.center_focus_weak_outlined,
                                  color: cameraManager.isAutoFocus ? Colors.yellow : Colors.white,
                                  size: 32,
                                ),
                                onPressed: cameraManager.toggleAutoFocus,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}