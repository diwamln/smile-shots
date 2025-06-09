import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'managers/camera_manager.dart';
import 'screens/photo_screen.dart';
import 'screens/filter_screen.dart';
import 'screens/game_screen.dart';
import 'screens/pro_screen.dart';

/// Titik masuk utama aplikasi (Main entry point).
void main() async {
  // Memastikan Flutter siap sebelum menjalankan kode async.
  WidgetsFlutterBinding.ensureInitialized();
  // Mendapatkan daftar kamera yang tersedia di perangkat.
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

/// Widget root dari aplikasi.
/// Bertanggung jawab untuk setup [MaterialApp] dan [ChangeNotifierProvider].
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    // Menyediakan CameraManager ke seluruh pohon widget.
    // Ini adalah inti dari state management terpusat kita.
    return ChangeNotifierProvider(
      create: (context) => CameraManager(cameras: cameras),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmileShot',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const CameraScreen(),
      ),
    );
  }
}

/// Widget utama yang menjadi host bagi semua layar kamera.
/// Mengelola [PageView] dan navigasi menu bawah.
class CameraScreen extends StatefulWidget {
  // const CameraScreen({super.key, required this.cameras}); // Parameter ini tidak lagi dibutuhkan
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // --- State & Controllers ---
  int _selectedIndex = 0;
  late PageController _pageController;

  // --- UI Data ---
  final List<String> _menuItems = ['PHOTO', 'FILTER', 'GAME', 'PRO'];
  final List<Widget> _screens = [
    const PhotoScreen(),
    const FilterScreen(),
    const GameScreen(),
    const ProScreen(),
  ];

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Meminta CameraManager untuk menginisialisasi kamera setelah frame pertama selesai di-render.
    // `listen: false` wajib digunakan di dalam initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CameraManager>(context, listen: false).initializeCamera();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- UI Callbacks ---

  /// Mengubah halaman saat item menu bawah ditekan.
  void _onMenuTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// Mengupdate state saat halaman di-swipe.
  void _onPageChanged(int index) {
    // Memberi tahu CameraManager layar mana yang sekarang aktif.
    Provider.of<CameraManager>(context, listen: false)
        .setActiveScreen(ActiveScreen.values[index]);

    setState(() {
      _selectedIndex = index;
    });
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Konten utama yang bisa di-swipe
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
            ),

            // Menu navigasi di bagian bawah
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_menuItems.length, (index) {
                  final isActive = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () => _onMenuTapped(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.yellow : Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _menuItems[index],
                        style: TextStyle(
                          color: isActive ? Colors.black : Colors.white,
                          fontSize: 16,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}