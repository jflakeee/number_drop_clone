import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/game_state.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
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

    if (!AuthService.instance.isSignedIn) {
      await _handleSignIn();
      if (!AuthService.instance.isSignedIn) return;
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
            // Save data when game over
            if (gameState.isGameOver && !_hasShownGameOver) {
              _hasShownGameOver = true;
              _scoreSubmitted = false;
              _saveGameData(gameState);
              AudioService.instance.playGameOver();
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

                    const SizedBox(height: 10),

                    // Next block preview
                    const NextBlockPreview(),

                    const SizedBox(height: 10),

                    // Game board
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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

                    // Bottom controls
                    _buildBottomControls(context, gameState),

                    const SizedBox(height: 16),
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

                // Game over overlay
                if (gameState.isGameOver)
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Piggy bank with progress
          _buildPiggyBank(gameState),

          // AD video button (+coins)
          _buildToolButton(
            icon: Icons.play_circle_filled,
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF3D5A80),
            label: 'AD',
            coinAmount: 109,
            showPlus: true,
            onTap: () {
              gameState.addCoins(109);
              gameState.addToPiggyBank(109);
              AudioService.instance.playCoin();
            },
          ),

          // Shuffle button
          _buildToolButton(
            icon: Icons.swap_horiz,
            iconColor: Colors.orange,
            backgroundColor: const Color(0xFF3D5A80),
            coinAmount: 120,
            onTap: () {
              // TODO: Implement shuffle
            },
          ),

          // Hammer button
          _buildToolButton(
            icon: Icons.hardware,
            iconColor: Colors.white,
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
    final progress = gameState.piggyBankCoins / GameConstants.mascotGoalCoins;
    return GestureDetector(
      onTap: () {
        if (gameState.piggyBankCoins >= GameConstants.mascotGoalCoins) {
          gameState.collectPiggyBank();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF3D5A80),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐷', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            SizedBox(
              width: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${gameState.piggyBankCoins}/${GameConstants.mascotGoalCoins}',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: GameColors.coinYellow, width: 2)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: GameColors.coinYellow.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
                if (label != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: GameColors.coinYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '😊',
                      style: TextStyle(fontSize: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  showPlus ? '+$coinAmount' : '$coinAmount',
                  style: const TextStyle(
                    color: GameColors.coinYellow,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final isSignedIn = AuthService.instance.isSignedIn;

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
              const SizedBox(height: 24),

              // Submit score button
              if (!_scoreSubmitted)
                ElevatedButton.icon(
                  onPressed:
                      _isSubmittingScore ? null : () => _submitScore(gameState),
                  icon: _isSubmittingScore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isSignedIn ? Icons.leaderboard : Icons.login,
                          size: 18,
                        ),
                  label: Text(
                    _isSubmittingScore
                        ? 'SUBMITTING...'
                        : isSignedIn
                            ? 'SUBMIT SCORE'
                            : 'SIGN IN & SUBMIT',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    disabledBackgroundColor: GameColors.accent.withOpacity(0.5),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Score Submitted!',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _hasShownGameOver = false;
                  _scoreSubmitted = false;
                  gameState.newGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              const SizedBox(height: 32),
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  gameState.resume();
                  gameState.newGame();
                },
                child: const Text(
                  'NEW GAME',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
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

}
