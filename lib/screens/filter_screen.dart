import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../managers/camera_manager.dart';
import '../widgets/timer_selector_widget.dart';

/// Layar yang menampilkan preview kamera dengan berbagai pilihan filter.
/// Menggunakan teknik "Widget Capture" untuk menyimpan gambar beserta filternya.
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});
  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> with AutomaticKeepAliveClientMixin<FilterScreen> {
  // --- State & Keys ---

  /// Kunci global untuk menandai area widget yang akan di-"screenshot".
  final GlobalKey _previewContainerKey = GlobalKey();

  /// Index filter yang sedang dipilih oleh pengguna.
  int _selectedFilterIndex = 0;

  @override
  bool get wantKeepAlive => true; // Menjaga state layar agar tidak hilang saat di-swipe

  // --- Data & Logic ---

  /// Daftar filter yang tersedia, mendefinisikan tipe dan propertinya.
  final List<Map<String, dynamic>> _filters = [
    {'name': 'Normal', 'type': 'none', 'color': Colors.grey},
    {'name': 'Burn', 'type': 'blend', 'color': Colors.blue.withOpacity(0.5), 'blendMode': BlendMode.colorBurn},
    {'name': 'Dark', 'type': 'blend', 'color': Colors.red.withOpacity(0.4), 'blendMode': BlendMode.darken},
    {'name': 'Dodge', 'type': 'blend', 'color': Colors.green.withOpacity(0.5), 'blendMode': BlendMode.colorDodge},
    {'name': 'Gray','type': 'matrix','color': Colors.grey.shade400,'matrix': const [0.2126, 0.7152, 0.0722, 0.0, 0.0, 0.2126, 0.7152, 0.0722, 0.0, 0.0, 0.2126, 0.7152, 0.0722, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,]},
    {'name': 'Warm', 'type': 'blend', 'color': Colors.orange.withOpacity(0.3), 'blendMode': BlendMode.softLight},
  ];

  /// Menangani aksi saat tombol shutter ditekan.
  void _handleShutterPress() {
    final cameraManager = Provider.of<CameraManager>(context, listen: false);
    if (cameraManager.isCountingDown) {
      cameraManager.cancelCountdown();
    } else {
      // Memulai proses capture dengan mengirimkan key dari RepaintBoundary
      cameraManager.triggerPhotoCapture(repaintBoundaryKey: _previewContainerKey);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capture triggered!'), duration: Duration(seconds: 1)));
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selectedFilter = _filters[_selectedFilterIndex];

    return Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraManager>(
          builder: (context, cameraManager, child) {
            return Stack(
              children: [
                // --- LAPISAN 1: PREVIEW KAMERA (UNTUK DI-CAPTURE) ---
                if (cameraManager.isCameraInitialized)
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _previewContainerKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Latar belakang preview kamera dengan scaling yang benar
                          ClipRect(
                            child: Builder(
                              builder: (context) {
                                final camera = cameraManager.controller!;
                                final size = MediaQuery.of(context).size;
                                var scale = size.aspectRatio * camera.value.aspectRatio;
                                if (scale < 1) scale = 1 / scale;

                                Widget previewWidget = CameraPreview(camera, key: const ValueKey('camera_preview_filter'));

                                // Terapkan filter matrix jika 'Gray' dipilih
                                if (selectedFilter['type'] == 'matrix') {
                                  previewWidget = ColorFiltered(colorFilter: ColorFilter.matrix(selectedFilter['matrix']), child: previewWidget);
                                }
                                return Transform.scale(scale: scale, child: Center(child: previewWidget));
                              },
                            ),
                          ),
                          // Lapisan overlay untuk filter tipe 'blend'
                          if (selectedFilter['type'] == 'blend')
                            IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(color: selectedFilter['color'], backgroundBlendMode: selectedFilter['blendMode']),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const Positioned.fill(child: Center(child: CircularProgressIndicator(color: Colors.white))),

                // --- LAPISAN 2: UI TIMER (SELALU DI ATAS) ---
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(child: const TimerSelectorWidget()),
                ),

                // --- LAPISAN 3: UI COUNTDOWN (MUNCUL SAAT AKTIF) ---
                if (cameraManager.isCountingDown)
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        '${cameraManager.countdownValue}',
                        style: const TextStyle(color: Colors.white, fontSize: 150, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 20, color: Colors.black87)]),
                      ),
                    ),
                  ),

                // --- LAPISAN 4: UI KONTROL BAWAH ---
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 70,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0, right: 0, top: 0, bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: _handleShutterPress,
                              child: Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.transparent, border: Border.all(color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, width: 4)),
                                child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: Icon(cameraManager.isCountingDown ? Icons.close : Icons.photo_camera, key: ValueKey<bool>(cameraManager.isCountingDown), color: cameraManager.isCountingDown ? Colors.redAccent : Colors.white, size: 35)),
                              ),
                            ),
                          ),
                        ),
                        if (!cameraManager.isCountingDown)
                          Positioned(
                            left: 50, top: 10,
                            child: GestureDetector(
                              onTap: () => cameraManager.switchCamera(),
                              child: Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 25)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- LAPISAN 5: UI LIST FILTER (HANYA TAMPIL JIKA TIDAK COUNTDOWN) ---
                if (!cameraManager.isCountingDown)
                  Positioned(
                    bottom: 200,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filters.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedFilterIndex == index;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilterIndex = index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 65, height: 65,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(color: _filters[index]['color'], border: Border.all(color: isSelected ? Colors.yellow : Colors.white, width: isSelected ? 3.5 : 1.5), borderRadius: BorderRadius.circular(12)),
                                ),
                                const SizedBox(height: 4),
                                Text(_filters[index]['name'], style: TextStyle(color: isSelected ? Colors.yellow : Colors.white, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ));
  }
}