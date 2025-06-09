import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mendefinisikan layar yang sedang aktif untuk logika kondisional.
enum ActiveScreen { photo, filter, game, pro }

/// Mendefinisikan durasi timer yang tersedia.
enum CaptureTimer { off, three, five, ten }

/// Kelas utama yang berfungsi sebagai otak dari semua logika kamera.
/// Menggunakan [ChangeNotifier] untuk memberitahu UI tentang perubahan state.
class CameraManager extends ChangeNotifier {
  final List<CameraDescription> _cameras;

  // --- State Variables ---

  // Kamera & UI
  CameraController? _controller;
  int _currentCameraIndex = 0;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  ActiveScreen _activeScreen = ActiveScreen.photo;

  // Fitur Smile Detection
  bool _isSmileDetectionOn = false;
  bool _isSmiling = false;
  int _detectedFaceCount = 0;

  // Fitur Timer
  CaptureTimer _currentTimer = CaptureTimer.off;
  int? _countdownValue;
  Timer? _countdownTimer;

  // Fitur Pro Mode
  double _minExposure = 0.0, _maxExposure = 0.0, _currentExposure = 0.0;
  double _minZoom = 1.0, _maxZoom = 1.0, _currentZoom = 1.0;
  bool _isAutoFocus = true;

  // Fitur Game
  bool _isGameFaceDetected = false;
  VoidCallback? _onBlinkCallback;

  // Fitur Expression Game (DITAMBAHKAN)
  bool _isExpressionGameActive = false;
  String? _currentExpression;
  Timer? _expressionDetectionTimer;

  // Galeri
  List<String> _savedPhotos = [];
  String? _lastPhotoPath;

  // Detektor Wajah
  FaceDetector? _faceDetector;
  FaceDetector? _gameFaceDetector;
  FaceDetector? _expressionFaceDetector; // DITAMBAHKAN

  // --- Constructor & Initialization ---

  CameraManager({required List<CameraDescription> cameras})
    : _cameras = cameras {
    _initializeApp();
  }

  /// Menjalankan semua setup awal yang diperlukan saat manager dibuat.
  Future<void> _initializeApp() async {
    await Permission.camera.request();
    await Permission.storage.request();
    _setupFaceDetector();
    _setupGameFaceDetector();
    _setupExpressionFaceDetector(); // DITAMBAHKAN
    await loadSavedPhotos();
  }

  // --- Public Getters ---

  CameraController? get controller => _controller;
  bool get isCameraInitialized => _controller?.value.isInitialized ?? false;
  bool get isProcessing => _isProcessing;
  bool get isFlashOn => _isFlashOn;
  ActiveScreen get activeScreen => _activeScreen;
  bool get isSmileDetectionOn => _isSmileDetectionOn;
  bool get isSmiling => _isSmiling;
  int get detectedFaceCount => _detectedFaceCount;
  CaptureTimer get currentTimer => _currentTimer;
  int? get countdownValue => _countdownValue;
  bool get isCountingDown => _countdownTimer?.isActive ?? false;
  double get minExposure => _minExposure;
  double get maxExposure => _maxExposure;
  double get currentExposure => _currentExposure;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;
  bool get isAutoFocus => _isAutoFocus;
  bool get isGameFaceDetected => _isGameFaceDetected;
  List<String> get savedPhotos => _savedPhotos;
  String? get lastPhotoPath => _lastPhotoPath;

  // Expression Game Getters (DITAMBAHKAN)
  bool get isExpressionGameActive => _isExpressionGameActive;
  String? get currentExpression => _currentExpression;

  // --- Core Camera Logic ---

  /// Menginisialisasi atau membuat ulang [CameraController].
  Future<void> initializeCamera() async {
    if (_controller != null) await _controller!.dispose();

    final camera = _cameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      await _fetchCameraCapabilities();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
    notifyListeners();
  }

  /// Mengambil data kapabilitas kamera (min/max zoom, exposure) untuk Pro Mode.
  Future<void> _fetchCameraCapabilities() async {
    if (!isCameraInitialized) return;
    _minExposure = await _controller!.getMinExposureOffset();
    _maxExposure = await _controller!.getMaxExposureOffset();
    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _currentExposure = 0.0;
    _currentZoom = 1.0;
    _isAutoFocus = true;
  }

  /// Mengganti kamera antara depan dan belakang.
  Future<void> switchCamera({int? cameraIndex}) async {
    if (_cameras.length < 2) return;

    // Reset state yang relevan dengan kamera
    _isSmiling = false;
    _currentExposure = 0.0;
    _currentZoom = 1.0;
    _isAutoFocus = true;

    _currentCameraIndex =
        cameraIndex ?? (_currentCameraIndex + 1) % _cameras.length;

    // Re-inisialisasi kamera dengan deskripsi baru
    await initializeCamera();
  }

  // --- Feature Logic & UI Interaction ---

  /// Mengatur layar aktif saat ini untuk logika kondisional.
  void setActiveScreen(ActiveScreen screen) {
    if (_activeScreen == screen) return;
    _activeScreen = screen;
    // Hentikan proses yang tidak relevan saat pindah layar
    if (_activeScreen != ActiveScreen.photo && _isSmileDetectionOn) {
      stopImageStream();
    }
    // Hentikan expression game jika pindah dari game screen
    if (_activeScreen != ActiveScreen.game && _isExpressionGameActive) {
      stopExpressionGame();
    }
    notifyListeners();
  }

  /// Menyalakan atau mematikan flash.
  void toggleFlash() {
    if (!isCameraInitialized) return;
    _isFlashOn = !_isFlashOn;
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    notifyListeners();
  }

  /// Mengaktifkan atau menonaktifkan fitur smile-to-shoot.
  void toggleSmileDetection() {
    if (!isCameraInitialized) return;
    _isSmileDetectionOn = !_isSmileDetectionOn;
    if (_isSmileDetectionOn) {
      startImageStream(_processImageForSmile);
    } else {
      stopImageStream();
      _isSmiling = false;
    }
    notifyListeners();
  }

  /// Mengatur durasi timer yang dipilih oleh pengguna.
  void setTimer(CaptureTimer timer) {
    _currentTimer = timer;
    notifyListeners();
  }

  /// Memulai proses pengambilan gambar (dengan atau tanpa timer).
  /// Menerima [repaintBoundaryKey] opsional untuk "widget capture" di FilterScreen.
  void triggerPhotoCapture({GlobalKey? repaintBoundaryKey}) {
    if (isCountingDown) {
      cancelCountdown();
      return;
    }
    int duration;
    switch (_currentTimer) {
      case CaptureTimer.three:
        duration = 3;
        break;
      case CaptureTimer.five:
        duration = 5;
        break;
      case CaptureTimer.ten:
        duration = 10;
        break;
      case CaptureTimer.off:
      default:
        _executePictureCapture(repaintBoundaryKey: repaintBoundaryKey);
        return;
    }

    _setCountdown(duration);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue! > 1) {
        _setCountdown(_countdownValue! - 1);
      } else {
        timer.cancel();
        _executePictureCapture(repaintBoundaryKey: repaintBoundaryKey);
        cancelCountdown();
      }
    });
  }

  /// Membatalkan countdown yang sedang berjalan.
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownValue = null;
    notifyListeners();
  }

  // --- Pro Mode Methods ---
  Future<void> setExposure(double offset) async {
    if (!isCameraInitialized) return;
    try {
      await _controller!.setExposureOffset(offset);
      _currentExposure = offset;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to set exposure: $e");
    }
  }

  Future<void> setZoom(double level) async {
    if (!isCameraInitialized) return;
    try {
      await _controller!.setZoomLevel(level);
      _currentZoom = level;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to set zoom: $e");
    }
  }

  Future<void> toggleAutoFocus() async {
    if (!isCameraInitialized) return;
    _isAutoFocus = !_isAutoFocus;
    try {
      await _controller!.setFocusMode(
        _isAutoFocus ? FocusMode.auto : FocusMode.locked,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to set focus mode: $e');
    }
  }

  // --- Game Mode Logic ---
  void startDonotBlinkGame(VoidCallback onBlink) {
    _onBlinkCallback = onBlink;
    _isGameFaceDetected = false;

    int frontCameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (frontCameraIndex == -1) frontCameraIndex = 0;

    if (_currentCameraIndex != frontCameraIndex) {
      switchCamera(cameraIndex: frontCameraIndex).then((_) {
        startImageStream(_processImageForGame);
      });
    } else {
      startImageStream(_processImageForGame);
    }
    notifyListeners();
  }

  void stopDonotBlinkGame() {
    stopImageStream();
    _isGameFaceDetected = false;
    _onBlinkCallback = null;
    notifyListeners();
  }

  // --- Expression Game Methods (DITAMBAHKAN) ---

  /// Memulai expression game
  void startExpressionGame() {
    if (!isCameraInitialized) return;

    _isExpressionGameActive = true;
    _currentExpression = null;

    // Pastikan menggunakan front camera untuk expression game
    int frontCameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (frontCameraIndex == -1) frontCameraIndex = 0;

    if (_currentCameraIndex != frontCameraIndex) {
      switchCamera(cameraIndex: frontCameraIndex).then((_) {
        startImageStream(_processImageForExpression);
      });
    } else {
      startImageStream(_processImageForExpression);
    }

    notifyListeners();
  }

  /// Menghentikan expression game
  void stopExpressionGame() {
    _isExpressionGameActive = false;
    _currentExpression = null;
    _expressionDetectionTimer?.cancel();
    stopImageStream();
    notifyListeners();
  }

  // --- Gallery Logic ---
  Future<void> loadSavedPhotos() async {
    try {
      final Directory extDir = await getApplicationDocumentsDirectory();
      final String dirPath = '${extDir.path}/Pictures/CameraApp';
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final files =
            dir
                .listSync()
                .where(
                  (f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'),
                )
                .map((f) => f.path)
                .toList();
        files.sort(
          (a, b) =>
              File(b).lastModifiedSync().compareTo(File(a).lastModifiedSync()),
        );
        _savedPhotos = files;
        if (files.isNotEmpty) _lastPhotoPath = files.first;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
    }
  }

  Future<void> addPhotoToGallery(String path) async {
    if (path.isEmpty) return;
    _lastPhotoPath = path;
    _savedPhotos.insert(0, path);
    notifyListeners();
  }

  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      _savedPhotos.remove(path);
      if (_lastPhotoPath == path) {
        _lastPhotoPath = _savedPhotos.isNotEmpty ? _savedPhotos.first : null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete photo: $e');
    }
  }

  // --- Internal & Private Methods ---

  /// Mengatur nilai countdown dan memberitahu UI.
  void _setCountdown(int duration) {
    _countdownValue = duration;
    notifyListeners();
  }

  /// Eksekusi inti pengambilan gambar.
  Future<void> _executePictureCapture({GlobalKey? repaintBoundaryKey}) async {
    if (repaintBoundaryKey != null) {
      await _captureWidgetFromKey(repaintBoundaryKey);
      return;
    }

    if (!isCameraInitialized || _controller!.value.isTakingPicture) return;
    final wasStreaming = _controller!.value.isStreamingImages;
    if (wasStreaming) stopImageStream();

    try {
      final imageFile = await _controller!.takePicture();
      final savedPath = await _savePhoto(imageFile.path);
      if (savedPath != null) {
        addPhotoToGallery(savedPath);
      }
    } catch (e) {
      debugPrint('Error executing picture capture: $e');
    } finally {
      if (wasStreaming) {
        if (_isSmileDetectionOn && _activeScreen == ActiveScreen.photo) {
          startImageStream(_processImageForSmile);
        } else if (_isExpressionGameActive &&
            _activeScreen == ActiveScreen.game) {
          startImageStream(_processImageForExpression);
        }
      }
    }
  }

  /// Mengambil gambar dari widget menggunakan [RepaintBoundary].
  Future<void> _captureWidgetFromKey(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final filePath = await _generateFilePath(asPNG: true);
      await File(filePath).writeAsBytes(pngBytes);
      await addPhotoToGallery(filePath);
    } catch (e) {
      debugPrint("Error capturing widget from key: $e");
    }
  }

  /// Inisialisasi detektor wajah untuk mode Photo.
  void _setupFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  /// Inisialisasi detektor wajah untuk mode Game.
  void _setupGameFaceDetector() {
    _gameFaceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  /// Inisialisasi detektor wajah untuk expression game (DITAMBAHKAN).
  void _setupExpressionFaceDetector() {
    _expressionFaceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );
  }

  /// Memulai image stream dari kamera untuk diproses.
  void startImageStream(Function(CameraImage) processFunction) {
    if (!isCameraInitialized || _controller!.value.isStreamingImages) return;
    _controller!.startImageStream(processFunction);
    debugPrint("Image stream started for $_activeScreen");
  }

  /// Menghentikan image stream dari kamera.
  void stopImageStream() {
    if (!isCameraInitialized || !_controller!.value.isStreamingImages) return;
    _controller!.stopImageStream();
    _isProcessing = false;
    debugPrint("Image stream stopped.");
  }

  /// Memproses gambar untuk mendeteksi senyuman.
  Future<void> _processImageForSmile(CameraImage image) async {
    if (isCountingDown ||
        isProcessing ||
        _faceDetector == null ||
        _activeScreen != ActiveScreen.photo)
      return;
    _isProcessing = true;
    final inputImage = _convertToInputImage(image);
    if (inputImage != null) {
      final faces = await _faceDetector!.processImage(inputImage);
      _detectedFaceCount = faces.length;
      bool smileDetected = faces.any(
        (face) => (face.smilingProbability ?? 0) > 0.6,
      );
      if (smileDetected && !_isSmiling) {
        triggerPhotoCapture();
      }
      if (_isSmiling != smileDetected || _detectedFaceCount != faces.length) {
        _isSmiling = smileDetected;
        notifyListeners();
      }
    }
    _isProcessing = false;
  }

  /// Memproses gambar untuk mendeteksi kedipan mata.
  Future<void> _processImageForGame(CameraImage image) async {
    if (_isProcessing ||
        _gameFaceDetector == null ||
        _activeScreen != ActiveScreen.game)
      return;
    _isProcessing = true;
    final inputImage = _convertToInputImage(image);
    if (inputImage != null) {
      final faces = await _gameFaceDetector!.processImage(inputImage);
      bool faceCurrentlyDetected = faces.isNotEmpty;
      if (_isGameFaceDetected != faceCurrentlyDetected) {
        _isGameFaceDetected = faceCurrentlyDetected;
        notifyListeners();
      }
      if (faces.any(
        (face) =>
            (face.leftEyeOpenProbability ?? 1.0) < 0.2 &&
            (face.rightEyeOpenProbability ?? 1.0) < 0.2,
      )) {
        _onBlinkCallback?.call();
      }
    }
    _isProcessing = false;
  }

  /// Memproses gambar untuk mendeteksi ekspresi wajah (DITAMBAHKAN).
  Future<void> _processImageForExpression(CameraImage image) async {
    if (_isProcessing ||
        _expressionFaceDetector == null ||
        _activeScreen != ActiveScreen.game ||
        !_isExpressionGameActive)
      return;

    _isProcessing = true;
    final inputImage = _convertToInputImage(image);

    if (inputImage != null) {
      try {
        final faces = await _expressionFaceDetector!.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          String? detectedExpression = _determineExpression(face);

          if (_currentExpression != detectedExpression) {
            _currentExpression = detectedExpression;
            notifyListeners();
          }
        } else {
          if (_currentExpression != null) {
            _currentExpression = null;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error processing expression: $e');
      }
    }
    _isProcessing = false;
  }

  /// Menentukan ekspresi berdasarkan probabilitas wajah - UPDATED untuk mengganti wink dengan sleep.
  String? _determineExpression(Face face) {
    final smile = face.smilingProbability ?? 0.0;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    // Sleep detection - kedua mata tertutup
    if (leftEye < 0.3 && rightEye < 0.3) {
      return 'sleep';
    }

    // Happy detection - senyum dan mata terbuka
    if (smile > 0.4 && leftEye > 0.3 && rightEye > 0.3) {
      return 'happy';
    }

    // Surprised detection - mata terbuka lebar, tidak senyum
    if (leftEye > 0.75 && rightEye > 0.75 && smile < 0.2) {
      return 'surprised';
    }


    // Default
    return 'neutral';
  }

  /// Menghasilkan path file unik untuk menyimpan gambar.
  Future<String> _generateFilePath({bool asPNG = false}) async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/CameraApp';
    await Directory(dirPath).create(recursive: true);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String extension = asPNG ? 'png' : 'jpg';
    return '$dirPath/$timestamp.$extension';
  }

  /// Menyimpan gambar dari path sementara ke path final.
  Future<String?> _savePhoto(String tempPath) async {
    try {
      final filePath = await _generateFilePath();
      await File(tempPath).copy(filePath);
      return filePath;
    } catch (e) {
      debugPrint('Error saving photo: $e');
      return null;
    }
  }

  /// Mengonversi format [CameraImage] ke format [InputImage] ML Kit.
  InputImage? _convertToInputImage(CameraImage image) {
    final camera = _cameras[_currentCameraIndex];
    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    if (image.planes.isEmpty) return null;
    final plane = image.planes[0];
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // --- Lifecycle ---

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector?.close();
    _gameFaceDetector?.close();
    _expressionFaceDetector?.close(); // DITAMBAHKAN
    _countdownTimer?.cancel();
    _expressionDetectionTimer?.cancel(); // DITAMBAHKAN
    super.dispose();
  }
}
