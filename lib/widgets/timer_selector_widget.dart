import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/camera_manager.dart';

/// Sebuah widget yang dapat digunakan ulang untuk menampilkan pilihan timer (OFF, 3s, 5s, 10s).
/// Widget ini secara otomatis menyembunyikan diri saat countdown sedang berlangsung.
class TimerSelectorWidget extends StatelessWidget {
  const TimerSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Menggunakan Consumer agar widget ini hanya di-build ulang saat state timer berubah.
    return Consumer<CameraManager>(
      builder: (context, cameraManager, child) {
        // Sembunyikan seluruh UI jika countdown sedang aktif.
        if (cameraManager.isCountingDown) {
          return const SizedBox.shrink(); // Widget kosong yang tidak memakan ruang
        }

        // Gunakan Wrap untuk memastikan tombol tidak overflow di layar sempit.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0, // Jarak horizontal antar tombol
            children: [
              _buildTimerButton(context, cameraManager, CaptureTimer.off, 'OFF'),
              _buildTimerButton(context, cameraManager, CaptureTimer.three, '3s'),
              _buildTimerButton(context, cameraManager, CaptureTimer.five, '5s'),
              _buildTimerButton(context, cameraManager, CaptureTimer.ten, '10s'),
            ],
          ),
        );
      },
    );
  }

  /// Fungsi helper untuk membangun setiap tombol timer.
  Widget _buildTimerButton(BuildContext context, CameraManager manager, CaptureTimer timerValue, String text) {
    final bool isSelected = manager.currentTimer == timerValue;

    return GestureDetector(
      onTap: () => manager.setTimer(timerValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.yellow : Colors.white54,
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}