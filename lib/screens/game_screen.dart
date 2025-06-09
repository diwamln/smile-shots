import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/camera_manager.dart';
import 'package:camera/camera.dart'; //

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with AutomaticKeepAliveClientMixin<GameScreen> {
  Timer? _gameTimer;
  Timer? _expressionCheckTimer; // Timer untuk mengecek ekspresi secara berkala
  int _score = 0;
  bool _isGameActive = false;
  bool _gameOver = false;
  int _remainingTime = 60; // 60 detik countdown
  bool _isCurrentExpressionMatched = false; // Flag untuk melacak apakah ekspresi saat ini sudah cocok
  int _matchDuration = 0; // Durasi dalam detik untuk maintain ekspresi yang benar

  // Ekspresi target yang harus dicocokkan
  final List<String> _expressions = ['neutral', 'surprised', 'happy', 'sleep'];
  String _currentTarget = 'neutral';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _gameTimer?.cancel();
    _expressionCheckTimer?.cancel();
    Provider.of<CameraManager>(context, listen: false).stopExpressionGame();
    super.dispose();
  }

  void _startGame() {
    final cameraManager = Provider.of<CameraManager>(context, listen: false);

    setState(() {
      _score = 0;
      _gameOver = false;
      _isGameActive = true;
      _remainingTime = 60; // Reset timer ke 60 detik
      _isCurrentExpressionMatched = false;
      _matchDuration = 0;
    });

    cameraManager.startExpressionGame(); // Memulai deteksi ekspresi wajah

    _generateNextExpression(); // Set ekspresi pertama

    // Timer untuk mengecek ekspresi setiap detik
    _expressionCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final userExpression = cameraManager.currentExpression;
      
      if (_checkMatch(userExpression)) {
        if (!_isCurrentExpressionMatched) {
          // Pertama kali cocok
          setState(() {
            _isCurrentExpressionMatched = true;
            _matchDuration = 1;
          });
        } else {
          // Masih cocok, tambah durasi
          setState(() {
            _matchDuration++;
          });
        }
        
        // Jika sudah maintain ekspresi selama 2 detik, beri poin dan ganti ekspresi
        if (_matchDuration >= 2) {
          setState(() {
            _score += 100; // Tambah 100 poin per ekspresi berhasil
          });
          _generateNextExpression(); // Lanjut ke ekspresi berikutnya
        }
      } else {
        // Reset jika ekspresi tidak cocok
        if (_isCurrentExpressionMatched) {
          setState(() {
            _isCurrentExpressionMatched = false;
            _matchDuration = 0;
          });
        }
      }
    });

    // Timer utama game (60 detik)
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime--;
      });

      if (_remainingTime <= 0) {
        _endGame(); // Game berakhir setelah 60 detik
      }
    });
  }

  bool _checkMatch(String? userExpression) {
    return userExpression == _currentTarget;
  }

  void _generateNextExpression() {
    setState(() {
      _currentTarget = (_expressions..shuffle()).first;
      _isCurrentExpressionMatched = false;
      _matchDuration = 0;
    });
  }

  void _endGame() {
    _expressionCheckTimer?.cancel();
    _gameTimer?.cancel();
    Provider.of<CameraManager>(context, listen: false).stopExpressionGame();
    setState(() {
      _isGameActive = false;
      _gameOver = true;
    });
  }

  String _getDisplayExpression(String expression) {
    switch (expression) {
      case 'happy':
        return 'SMILE 😊';
      case 'surprised':
        return 'SURPRISED 😲';
      case 'sleep':
        return 'SLEEP 😴';
      case 'neutral':
        return 'NEUTRAL 😐';
      default:
        return expression.toUpperCase();
    }
  }

  Color _getExpressionColor(String? currentExpression, String targetExpression) {
    if (currentExpression == targetExpression) {
      return Colors.green;
    } else if (currentExpression != null) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String _getStatusText(String? currentExpression) {
    if (!_isGameActive) {
      return _gameOver ? 'TIME\'S UP! Final Score: $_score' : 'Tap start to play';
    }
    
    if (currentExpression == _currentTarget) {
      if (_matchDuration >= 2) {
        return '✅ PERFECT! Moving to next expression...';
      } else {
        return '✅ HOLD IT! ${2 - _matchDuration} more second${2 - _matchDuration > 1 ? 's' : ''}...';
      }
    } else {
      return 'Try to make the target expression!';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<CameraManager>(
      builder: (context, cameraManager, child) {
        if (cameraManager.activeScreen != ActiveScreen.game && _isGameActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _endGame();
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            alignment: Alignment.center,
            children: [
              // Kamera
              if (cameraManager.isCameraInitialized)
                Positioned.fill(child: CameraPreview(cameraManager.controller!))
              else
                const Center(child: CircularProgressIndicator()),

              // Lapisan gelap saat tidak aktif
              if (!_isGameActive)
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),

              // UI Game
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Atas: Skor, Timer & Ekspresi Target
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 16),
                    color: Colors.black.withOpacity(0.7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SCORE: $_score', 
                              style: const TextStyle(
                                color: Colors.yellow, 
                                fontSize: 18, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                            if (_isGameActive)
                              Text(
                                'TIME: $_remainingTime', 
                                style: const TextStyle(
                                  color: Colors.orange, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                          ],
                        ),
                        if (_isGameActive) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'TARGET EXPRESSION:', 
                            style: TextStyle(
                              color: Colors.white70, 
                              fontSize: 14,
                              fontWeight: FontWeight.w500
                            )
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.cyanAccent, width: 2),
                            ),
                            child: Text(
                              _getDisplayExpression(_currentTarget),
                              style: const TextStyle(
                                color: Colors.cyanAccent, 
                                fontSize: 24, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          // Progress indicator untuk durasi hold
                          if (_isCurrentExpressionMatched && _matchDuration < 2) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _matchDuration / 2.0,
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // Tengah: Tombol Start
                  if (!_isGameActive)
                    GestureDetector(
                      onTap: _startGame,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        decoration: BoxDecoration(
                          color: _gameOver ? Colors.blue : Colors.green,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (_gameOver ? Colors.blue : Colors.green).withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _gameOver ? 'PLAY AGAIN' : 'START GAME',
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 24, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),

                  // Bawah: Status & Current Expression
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 80, left: 20, right: 20, top: 16),
                    color: Colors.black.withOpacity(0.7),
                    child: Column(
                      children: [
                        // Current Expression Display (hanya saat game aktif)
                        if (_isGameActive) ...[
                          const Text(
                            'YOUR EXPRESSION:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _getExpressionColor(cameraManager.currentExpression, _currentTarget).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: _getExpressionColor(cameraManager.currentExpression, _currentTarget), 
                                width: 2
                              ),
                            ),
                            child: Text(
                              cameraManager.currentExpression != null 
                                  ? _getDisplayExpression(cameraManager.currentExpression!)
                                  : 'NO FACE DETECTED 😶',
                              style: TextStyle(
                                color: _getExpressionColor(cameraManager.currentExpression, _currentTarget),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Status Text
                        Text(
                          _getStatusText(cameraManager.currentExpression),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _gameOver 
                                ? Colors.redAccent 
                                : (_isGameActive && cameraManager.currentExpression == _currentTarget
                                    ? Colors.greenAccent
                                    : Colors.white),
                            fontSize: _gameOver ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}