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
import '../widgets/animated_game_board.dart';
import '../widgets/score_popup.dart';
import '../widgets/next_block_preview.dart';
import 'main_menu_screen.dart';

/// Daily Challenge game screen
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  bool _hammerMode = false;
  bool _hasShownGameOver = false;
  bool _isSubmittingScore = false;
  bool _scoreSubmitted = false;
  bool _isInitialized = false;
  bool _isNewHighScore = false;
  int _todaysBestScore = 0;
  int _todaysPlays = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _startDailyChallenge();
    }
  }

  Future<void> _startDailyChallenge() async {
    // Load today's stats
    final stats = await StorageService.instance.getDailyChallengeStats();
    if (mounted) {
      setState(() {
        _todaysBestScore = stats['highScore'] ?? 0;
        _todaysPlays = stats['plays'] ?? 0;
      });
    }

    // Start daily challenge game using addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameState = context.read<GameState>();
        gameState.newDailyChallenge();
        _loadUserData();
        // Start BGM
        AudioService.instance.playBGM();
      }
    });
  }

  @override
  void dispose() {
    // Stop BGM when leaving
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

    // Record daily challenge score
    final isNewHigh =
        await StorageService.instance.recordDailyChallengeScore(gameState.score);
    setState(() {
      _isNewHighScore = isNewHigh;
      if (isNewHigh) {
        _todaysBestScore = gameState.score;
      }
      _todaysPlays++;
    });
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
    final gameState = context.read<GameState>();
    gameState.newGame();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
  }

  Future<void> _submitScore(GameState gameState) async {
    if (_isSubmittingScore) return;

    if (!AuthService.instance.isSignedIn) {
      await AuthService.instance.init();
    }

    setState(() => _isSubmittingScore = true);

    try {
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
        }
      }
    } catch (e) {
      // Silent fail for daily challenge
    }

    if (mounted) {
      setState(() => _isSubmittingScore = false);
    }
  }

  Future<void> _shareScore(GameState gameState) async {
    final score = gameState.score;
    final seed = gameState.gameSeed;
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month}/${now.day}';

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
Number Drop - Daily Challenge ($dateStr)

Score: $score
Highest Block: $highestBlock
Today's Best: $_todaysBestScore

Can you beat my score? Everyone plays the same puzzle today!
Seed: $seed
''';

    try {
      await Share.share(
        shareText.trim(),
        subject: 'Number Drop Daily Challenge - $score points',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            final shouldShowGameOver =
                gameState.isGameOver && gameState.score > 0;

            if (shouldShowGameOver && !_hasShownGameOver) {
              _hasShownGameOver = true;
              _scoreSubmitted = false;
              _saveGameData(gameState);
              AudioService.instance.playGameOver();
              VibrationService.instance.vibrateGameOver();
              _submitScore(gameState);
            }
            if (!gameState.isGameOver) {
              _hasShownGameOver = false;
              _scoreSubmitted = false;
              _isNewHighScore = false;
            }

            return Stack(
              children: [
                Column(
                  children: [
                    // Daily Challenge header
                    _buildDailyChallengeHeader(gameState),

                    // Next block preview
                    const NextBlockPreview(),

                    // Game board
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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

                // Game over overlay
                if (shouldShowGameOver)
                  _buildGameOverOverlay(context, gameState),

                // Pause overlay
                if (gameState.isPaused) _buildPauseOverlay(context, gameState),

                // Combo display
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

  Widget _buildDailyChallengeHeader(GameState gameState) {
    final now = DateTime.now();
    final dateStr = '${now.month}/${now.day}';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          // Back button + Daily badge
          GestureDetector(
            onTap: () => gameState.pause(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'DAILY $dateStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Today's best
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3D5A80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: GameColors.coinYellow, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatNumber(_todaysBestScore),
                  style: const TextStyle(
                    color: GameColors.coinYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Current score
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SCORE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                ),
              ),
              Text(
                _formatNumber(gameState.score),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Coins
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            decoration: BoxDecoration(
              color: const Color(0xFF4A9FE8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D6AB3), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: GameColors.coinYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('\$', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatNumber(gameState.coins),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Menu button
          GestureDetector(
            onTap: () => gameState.pause(),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF3D5A80),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 16),
            ),
          ),
        ],
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
          // Plays count
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5A80),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$_todaysPlays',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'PLAYS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // AD video button
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
                Icon(icon, color: iconColor, size: 24),
                if (label != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
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
            border: _isNewHighScore
                ? Border.all(color: GameColors.coinYellow, width: 2)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Daily Challenge badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'DAILY CHALLENGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isNewHighScore) ...[
                const Text(
                  'NEW BEST!',
                  style: TextStyle(
                    color: GameColors.coinYellow,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Text(
                _formatNumber(gameState.score),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      color: GameColors.coinYellow, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "Today's Best: ${_formatNumber(_todaysBestScore)}",
                    style: const TextStyle(
                      color: GameColors.coinYellow,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Plays today: $_todaysPlays',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 16),

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
                      'Submitting...',
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
                      final gameState = context.read<GameState>();
                      gameState.newDailyChallenge();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'TRY AGAIN',
                      style: TextStyle(
                        fontSize: 14,
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
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'SHARE',
                          style: TextStyle(
                            fontSize: 14,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'DAILY CHALLENGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${_formatNumber(gameState.score)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                "Today's Best: ${_formatNumber(_todaysBestScore)}",
                style: const TextStyle(
                  color: GameColors.coinYellow,
                  fontSize: 14,
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
                      final gs = context.read<GameState>();
                      gs.newDailyChallenge();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('RESTART'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final score = gameState.score;
                      final seed = gameState.gameSeed;
                      final now = DateTime.now();
                      final dateStr = '${now.year}/${now.month}/${now.day}';

                      final shareText = '''
Number Drop - Daily Challenge ($dateStr)

Current Score: $score
Today's Best: $_todaysBestScore

Challenge me with the same puzzle!
Seed: $seed
''';
                      await Share.share(shareText.trim());
                    },
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 10000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
