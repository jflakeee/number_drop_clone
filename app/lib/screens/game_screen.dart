import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/game_state.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../services/vibration_service.dart';
import '../services/auth_service.dart';
import '../services/ranking_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/animated_game_board.dart';
import '../widgets/score_popup.dart';
import '../widgets/next_block_preview.dart';
import '../widgets/score_display.dart';
import 'main_menu_screen.dart';

/// Main game screen
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _hammerMode = false;
  bool _hasShownGameOver = false;
  bool _isSubmittingScore = false;
  bool _scoreSubmitted = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final gameState = context.read<GameState>();
          gameState.newGame();
          _loadUserData();
          // Start BGM (may fail if file doesn't exist)
          AudioService.instance.playBGM();
        }
      });
    }
  }

  @override
  void dispose() {
    // Stop BGM when leaving game screen
    AudioService.instance.stopBGM();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await StorageService.instance.loadUserData();
    if (mounted) {
      final gameState = context.read<GameState>();
      gameState.setHighScore(userData.highScore);
      gameState.setCoins(userData.coins);
    }
  }

  Future<void> _saveGameData(GameState gameState) async {
    await StorageService.instance.updateHighScore(gameState.score);
    await StorageService.instance.updateCoins(gameState.coins);
    await StorageService.instance.incrementGamesPlayed();
  }

  void _toggleHammerMode(GameState gameState) {
    if (gameState.coins < GameConstants.hammerCost) return;
    setState(() {
      _hammerMode = !_hammerMode;
    });
  }

  void _useHammer(GameState gameState, int row, int column) {
    if (!_hammerMode) return;
    if (gameState.useHammer(row, column)) {
      AudioService.instance.playClick();
      setState(() {
        _hammerMode = false;
      });
      StorageService.instance.updateCoins(gameState.coins);
    }
  }

  void _goToMainMenu() {
    // Reset game state before going to main menu
    final gameState = context.read<GameState>();
    gameState.newGame();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
  }

  Future<void> _shareScore(GameState gameState) async {
    final score = gameState.score;
    final highScore = gameState.highScore;
    final seed = gameState.gameSeed;

    // Find highest block value achieved
    int highestBlock = 2;
    for (int row = 0; row < GameConstants.rows; row++) {
      for (int col = 0; col < GameConstants.columns; col++) {
        final block = gameState.board[row][col];
        if (block != null && block.value > highestBlock) {
          highestBlock = block.value;
        }
      }
    }

    final shareText = '''
Number Drop - I scored $score points!

Highest Block: $highestBlock
Best Score: $highScore
Game Seed: $seed

Can you beat my score? Try the same game with seed: $seed
''';

    try {
      await Share.share(
        shareText.trim(),
        subject: 'Number Drop - Score $score',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSignIn() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in successfully!'),
          backgroundColor: GameColors.primary,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _submitScore(GameState gameState) async {
    if (_isSubmittingScore) return;

    // Always signed in (anonymous or Google)
    if (!AuthService.instance.isSignedIn) {
      // This shouldn't happen, but initialize if needed
      await AuthService.instance.init();
    }

    setState(() => _isSubmittingScore = true);

    try {
      // Find highest block on the board
      int highestBlock = 2;
      for (int row = 0; row < GameConstants.rows; row++) {
        for (int col = 0; col < GameConstants.columns; col++) {
          final block = gameState.board[row][col];
          if (block != null && block.value > highestBlock) {
            highestBlock = block.value;
          }
        }
      }

      final success = await RankingService.instance.submitScore(
        score: gameState.score,
        highestBlock: highestBlock,
        gameSeed: gameState.gameSeed,
      );

      if (mounted) {
        if (success) {
          setState(() => _scoreSubmitted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Score submitted to ranking!'),
              backgroundColor: GameColors.primary,
            ),
          );
        } else {
          // Check if score was queued for offline submission
          final hasPending =
              await OfflineQueueService.instance.hasPendingScores();
          if (hasPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Score saved. Will submit when online.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your existing score is higher!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit score: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSubmittingScore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            // Skip game over handling during first frame (before newGame() takes effect)
            final shouldShowGameOver = gameState.isGameOver && gameState.score > 0;

            // Save data and auto-submit score when game over
            if (shouldShowGameOver && !_hasShownGameOver) {
              _hasShownGameOver = true;
              _scoreSubmitted = false;
              _saveGameData(gameState);
              AudioService.instance.playGameOver();
              VibrationService.instance.vibrateGameOver();
              // Auto-submit score to ranking
              _submitScore(gameState);
            }
            if (!gameState.isGameOver) {
              _hasShownGameOver = false;
              _scoreSubmitted = false;
            }

            return Stack(
              children: [
                // Main game content
                Column(
                  children: [
                    // Top bar with score and coins
                    const ScoreDisplay(),

                    // Next block preview (compact)
                    const NextBlockPreview(),

                    // Game board - maximized
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 5 / 8,
                            child: AnimatedGameBoard(
                              hammerMode: _hammerMode,
                              onHammerUse: (row, col) =>
                                  _useHammer(gameState, row, col),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom controls (compact)
                    _buildBottomControls(context, gameState),

                    const SizedBox(height: 4),
                  ],
                ),

                // Hammer mode indicator
                if (_hammerMode)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: _buildHammerModeIndicator(),
                  ),

                // Game over overlay (only show if score > 0 to avoid showing on screen init)
                if (shouldShowGameOver)
                  _buildGameOverOverlay(context, gameState),

                // Pause overlay
                if (gameState.isPaused) _buildPauseOverlay(context, gameState),

                // Combo display (IgnorePointer allows touches to pass through)
                if (gameState.comboCount > 1)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.3,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: ComboPopup(
                          key: ValueKey('combo_${gameState.comboCount}'),
                          comboCount: gameState.comboCount,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHammerModeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hardware, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'TAP A BLOCK TO REMOVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _hammerMode = false),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Piggy bank with progress (benchmark style)
          _buildPiggyBank(gameState),

          // AD video button (+coins)
          _buildToolButton(
            icon: Icons.play_circle_filled,
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF3D5A80),
            label: 'AD',
            coinAmount: 111,
            showPlus: true,
            onTap: () {
              gameState.addCoins(111);
              gameState.addToPiggyBank(111);
              AudioService.instance.playCoin();
            },
          ),

          // Shuffle button
          _buildToolButton(
            icon: Icons.swap_horiz,
            iconColor: Colors.orange,
            backgroundColor: const Color(0xFF3D5A80),
            coinAmount: GameConstants.shuffleCost,
            onTap: () {
              if (gameState.coins < GameConstants.shuffleCost) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Not enough coins!'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              if (gameState.shuffle()) {
                AudioService.instance.playClick();
              }
            },
          ),

          // Hammer button
          _buildToolButton(
            icon: Icons.hardware,
            iconColor: Colors.blueGrey[300]!,
            backgroundColor: const Color(0xFF3D5A80),
            coinAmount: GameConstants.hammerCost,
            isActive: _hammerMode,
            onTap: () => _toggleHammerMode(gameState),
          ),
        ],
      ),
    );
  }

  Widget _buildPiggyBank(GameState gameState) {
    return GestureDetector(
      onTap: () {
        if (gameState.piggyBankCoins >= GameConstants.mascotGoalCoins) {
          gameState.collectPiggyBank();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Golden piggy image (compact)
          Container(
            width: 44,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE135), Color(0xFFFFB800), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🐷', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${gameState.piggyBankCoins}/${GameConstants.mascotGoalCoins}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required int coinAmount,
    required VoidCallback onTap,
    String? label,
    bool showPlus = false,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container (compact)
          Container(
            width: 44,
            height: 38,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: GameColors.coinYellow, width: 2)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
                if (label != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Coin amount
          Text(
            showPlus ? '+$coinAmount' : '$coinAmount',
            style: const TextStyle(
              color: GameColors.coinYellow,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(BuildContext context, GameState gameState) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Score: ${gameState.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: GameColors.coinYellow,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Best: ${gameState.highScore}',
                    style: const TextStyle(
                      color: GameColors.coinYellow,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Seed: ${gameState.gameSeed}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              // Auto-submit score status
              if (_isSubmittingScore)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submitting to ranking...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else if (_scoreSubmitted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Ranking Updated!',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _hasShownGameOver = false;
                      _scoreSubmitted = false;
                      gameState.newGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _shareScore(gameState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'SHARE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToMainMenu,
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay(BuildContext context, GameState gameState) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Current score display
              Text(
                'Score: ${gameState.score}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => gameState.resume(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'RESUME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      gameState.resume();
                      gameState.newGame();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('NEW GAME'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _shareCurrentGame(gameState),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('SHARE'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  gameState.resume();
                  _goToMainMenu();
                },
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareCurrentGame(GameState gameState) async {
    final score = gameState.score;
    final seed = gameState.gameSeed;

    final shareText = '''
Number Drop - I'm playing a game!

Current Score: $score
Game Seed: $seed

Challenge me! Play the same game with seed: $seed
''';

    try {
      await Share.share(
        shareText.trim(),
        subject: 'Number Drop Challenge',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
