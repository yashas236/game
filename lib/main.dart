import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: GameScreen());
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  double playerX = 0.0;
  double playerY = 0.0;
  List<Map<String, dynamic>> obstacles = [];
  bool gameOver = false;
  int score = 0;
  FocusNode focusNode = FocusNode();
  double obstacleSpeed = 0.05;
  late AnimationController explosionController;
  late Animation<double> explosionAnimation;
  bool showExplosion = false;
  Offset explosionPosition = Offset.zero;
  final AudioPlayer audioPlayer = AudioPlayer();

  void playBackgroundMusic() async {
    final AudioCache audioCache = AudioCache(prefix: 'assets/');
    audioCache.play('RetroCassetteBright25Dec2024647PM.m4a');
  }

  void movePlayer(String direction) {
    if (gameOver) return;
    setState(() {
      if (direction == 'up' && playerY > -0.8) playerY -= 0.1;
      if (direction == 'down' && playerY < 0.8) playerY += 0.1;
      if (direction == 'left' && playerX > -0.8) playerX -= 0.1;
      if (direction == 'right' && playerX < 0.8) playerX += 0.1;
    });
  }

  void moveObstacles() {
    setState(() {
      for (var obstacle in obstacles) {
        obstacle['y'] = obstacle['y']! + obstacleSpeed;

        if (obstacle['type'] == 'moving') {
          obstacle['x'] += sin(obstacle['angle']) * 0.02;
          obstacle['angle'] += 0.1;
        }

        if (obstacle['type'] == 'growing') {
          obstacle['size'] = obstacle['size']! + 0.05;
        }

        if (obstacle['type'] == 'splitting' &&
            obstacle['y'] > 0.0 &&
            !obstacle['split']) {
          obstacles.addAll([
            {
              'x': obstacle['x']! - 0.1,
              'y': obstacle['y']!,
              'type': 'normal',
              'size': 30.0,
              'split': false,
            },
            {
              'x': obstacle['x']! + 0.1,
              'y': obstacle['y']!,
              'type': 'normal',
              'size': 30.0,
              'split': false,
            },
          ]);
          obstacle['split'] = true;
        }
      }

      obstacles.removeWhere((obstacle) => obstacle['y']! > 1);

      for (var obstacle in obstacles) {
        if ((playerX - obstacle['x']!).abs() < obstacle['size']! / 100 &&
            (playerY - obstacle['y']!).abs() < obstacle['size']! / 100) {
          gameOver = true;
          explosionPosition = Offset(playerX, playerY);
          showExplosion = true;
          explosionController.forward(from: 0);
        }
      }

      if (!gameOver) {
        score += 1;
        if (score % 50 == 0) {
          obstacleSpeed += 0.01;
        }
      }
    });
  }

  void addObstacle() {
    if (!gameOver) {
      setState(() {
        double randomType = Random().nextDouble();
        obstacles.add({
          'x': Random().nextDouble() * 1.6 - 0.8,
          'y': -1.0,
          'type':
              randomType < 0.3
                  ? 'moving'
                  : randomType < 0.6
                  ? 'growing'
                  : randomType < 0.8
                  ? 'splitting'
                  : 'normal',
          'size': 30.0,
          'angle': Random().nextDouble() * pi,
          'split': false,
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    gameLoop();
    obstacleSpawner();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    playBackgroundMusic();

    explosionController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    explosionAnimation = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: explosionController, curve: Curves.easeOut),
    );

    explosionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          showExplosion = false;
        });
      }
    });
  }

  void gameLoop() async {
    while (!gameOver) {
      await Future.delayed(Duration(milliseconds: 50));
      moveObstacles();
    }
    showGameOverDialog();
  }

  void obstacleSpawner() async {
    while (!gameOver) {
      await Future.delayed(Duration(seconds: 1));
      addObstacle();
    }
  }

  void showGameOverDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Game Over'),
            content: Text('Your score: $score'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  resetGame();
                },
                child: Text('Restart'),
              ),
            ],
          ),
    );
  }

  void resetGame() {
    setState(() {
      playerX = 0.0;
      playerY = 0.0;
      obstacles = [];
      gameOver = false;
      score = 0;
      obstacleSpeed = 0.05;
    });
    gameLoop();
    obstacleSpawner();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 300,
          height: 300,
          color: Colors.grey[900],
          child: RawKeyboardListener(
            focusNode: focusNode,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent && !gameOver) {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  movePlayer('up');
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  movePlayer('down');
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  movePlayer('left');
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  movePlayer('right');
                }
              }
            },
            child: Stack(
              children: [
                // Player
                Align(
                  alignment: Alignment(playerX, playerY),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Obstacles
                ...obstacles.map(
                  (obstacle) => Align(
                    alignment: Alignment(obstacle['x']!, obstacle['y']!),
                    child: Container(
                      width: obstacle['size'],
                      height: obstacle['size'],
                      decoration: BoxDecoration(
                        color:
                            obstacle['type'] == 'growing'
                                ? Colors.green
                                : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // Explosion animation
                if (showExplosion)
                  Align(
                    alignment: Alignment(
                      explosionPosition.dx,
                      explosionPosition.dy,
                    ),
                    child: ScaleTransition(
                      scale: explosionAnimation,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                // Scoreboard
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Score: $score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
