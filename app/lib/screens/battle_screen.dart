import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/game_state.dart';
import '../models/battle.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../widgets/animated_game_board.dart';
import '../widgets/score_popup.dart';
import '../widgets/next_block_preview.dart';
import '../widgets/opponent_score_display.dart';
import 'main_menu_screen.dart';

/// Battle game screen for 1v1 matches
class BattleScreen extends StatefulWidget {
  final Battle battle;

  const BattleScreen({
    super.key,
    required this.battle,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  bool _hasShownGameOver = false;
  bool _isGameStarted = false;

  // Opponent data from realtime database
  int _opponentScore = 0;
  int _opponentHighestBlock = 0;
  bool _opponentFinished = false;
  String _opponentName = 'Opponent';
  String? _opponentPhotoUrl;

  StreamSubscription<Map<String, dynamic>>? _liveScoreSubscription;
  StreamSubscription<Battle?>? _battleSubscription;
  Battle? _currentBattle;

  Timer? _scoreUpdateTimer;
  int _lastSentScore = 0;

  @override
  void initState() {
    super.initState();
    _currentBattle = widget.battle;
    _initBattle();
  }

  @override
  void dispose() {
    _liveScoreSubscription?.cancel();
    _battleSubscription?.cancel();
    _scoreUpdateTimer?.cancel();
    super.dispose();
  }

  void _initBattle() {
    final auth = AuthService.instance;
    final opponent = widget.battle.getOpponent(auth.userId ?? '');
    if (opponent != null) {
      _opponentName = opponent.displayName;
      _opponentPhotoUrl = opponent.photoUrl;
    }

    // Initialize game with battle seed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameState = context.read<GameState>();
        gameState.newGame(seed: widget.battle.seed);
        setState(() => _isGameStarted = true);

        // Start listening to live scores
        _startListeningToScores();

        // Start periodic score updates
        _startScoreUpdates();
      }
    });

    // Listen to battle updates
    _battleSubscription =
        BattleService.instance.watchBattle(widget.battle.id).listen((battle) {
      if (battle != null && mounted) {
        setState(() => _currentBattle = battle);
      }
    });
  }

  void _startListeningToScores() {
    final auth = AuthService.instance;
    final myId = auth.userId ?? '';

    _liveScoreSubscription = BattleService.instance
        .watchLiveScores(widget.battle.id)
        .listen((scores) {
      if (!mounted) return;

      // Find opponent's score
      for (final entry in scores.entries) {
        if (entry.key != myId) {
          final data = entry.value as Map<String, dynamic>?;
          if (data != null) {
            setState(() {
              _opponentScore = data['score'] as int? ?? 0;
              _opponentHighestBlock = data['highestBlock'] as int? ?? 0;
              _opponentFinished = data['isFinished'] as bool? ?? false;
            });
          }
        }
      }
    });
  }

  void _startScoreUpdates() {
    // Send score updates every 500ms
    _scoreUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_isGameStarted) return;

      final gameState = context.read<GameState>();
      if (gameState.score != _lastSentScore) {
        _lastSentScore = gameState.score;

        // Calculate highest block on board
        int highestBlock = 2;
        for (int row = 0; row < GameConstants.rows; row++) {
          for (int col = 0; col < GameConstants.columns; col++) {
            final block = gameState.board[row][col];
            if (block != null && block.value > highestBlock) {
              highestBlock = block.value;
            }
          }
        }

        BattleService.instance.updateLiveScore(
          battleId: widget.battle.id,
          score: gameState.score,
          highestBlock: highestBlock,
        );
      }
    });
  }

  Future<void> _handleGameOver(GameState gameState) async {
    if (_hasShownGameOver) return;
    _hasShownGameOver = true;

    AudioService.instance.playGameOver();

    // Calculate final highest block
    int highestBlock = 2;
    for (int row = 0; row < GameConstants.rows; row++) {
      for (int col = 0; col < GameConstants.columns; col++) {
        final block = gameState.board[row][col];
        if (block != null && block.value > highestBlock) {
          highestBlock = block.value;
        }
      }
    }

    // Submit final score
    await BattleService.instance.finishGame(
      battleId: widget.battle.id,
      finalScore: gameState.score,
      highestBlock: highestBlock,
    );
  }

  void _goToMainMenu() {
    // Reset game state before going to main menu
    final gameState = context.read<GameState>();
    gameState.newGame();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            // Handle game over
            if (gameState.isGameOver && !_hasShownGameOver) {
              _handleGameOver(gameState);
            }
            if (!gameState.isGameOver) {
              _hasShownGameOver = false;
            }

            final myScore = gameState.score;
            final isWinning = myScore > _opponentScore;
            final isLosing = myScore < _opponentScore;

            return Stack(
              children: [
                // Main game content
                Column(
                  children: [
                    // Top bar with scores
                    _buildBattleScoreBar(gameState),

                    const SizedBox(height: 8),

                    // Next block preview
                    const NextBlockPreview(),

                    const SizedBox(height: 8),

                    // Game board
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 5 / 8,
                            child: const AnimatedGameBoard(
                              hammerMode: false,
                              onHammerUse: null,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom info
                    _buildBottomInfo(),

                    const SizedBox(height: 16),
                  ],
                ),

                // Game over overlay
                if (gameState.isGameOver) _buildGameOverOverlay(gameState),

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

  Widget _buildBattleScoreBar(GameState gameState) {
    final myScore = gameState.score;
    final isWinning = myScore > _opponentScore;
    final isLosing = myScore < _opponentScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
      child: Row(
        children: [
          // My score
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isWinning
                    ? Colors.green.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: isWinning
                    ? Border.all(color: Colors.green.withOpacity(0.5))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isWinning) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_upward,
                            color: Colors.green, size: 12),
                      ],
                    ],
                  ),
                  Text(
                    '$myScore',
                    style: TextStyle(
                      color: isWinning ? Colors.green : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // VS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'VS',
              style: TextStyle(
                color: GameColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Opponent score
          Expanded(
            child: OpponentScoreDisplay(
              displayName: _opponentName,
              photoUrl: _opponentPhotoUrl,
              score: _opponentScore,
              highestBlock: _opponentHighestBlock,
              isFinished: _opponentFinished,
              isWinning: isLosing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vpn_key,
            color: Colors.white.withOpacity(0.4),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'Seed: ${widget.battle.seed}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState gameState) {
    final myScore = gameState.score;
    final isWinner = myScore > _opponentScore;
    final isDraw = myScore == _opponentScore;
    final bothFinished = _opponentFinished;

    String resultText;
    Color resultColor;
    IconData resultIcon;

    if (!bothFinished) {
      resultText = 'WAITING...';
      resultColor = Colors.white;
      resultIcon = Icons.hourglass_empty;
    } else if (isDraw) {
      resultText = 'DRAW!';
      resultColor = Colors.orange;
      resultIcon = Icons.handshake;
    } else if (isWinner) {
      resultText = 'YOU WIN!';
      resultColor = Colors.green;
      resultIcon = Icons.emoji_events;
    } else {
      resultText = 'YOU LOSE';
      resultColor = Colors.red;
      resultIcon = Icons.sentiment_dissatisfied;
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: resultColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resultIcon,
                color: resultColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                resultText,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Score comparison
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // My score
                  Column(
                    children: [
                      const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$myScore',
                        style: TextStyle(
                          color: isWinner ? Colors.green : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 24,
                      ),
                    ),
                  ),

                  // Opponent score
                  Column(
                    children: [
                      Text(
                        _opponentName.length > 10
                            ? '${_opponentName.substring(0, 10)}...'
                            : _opponentName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_opponentScore',
                        style: TextStyle(
                          color: !isWinner && !isDraw
                              ? Colors.red
                              : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (!bothFinished) ...[
                const SizedBox(height: 16),
                Text(
                  'Waiting for opponent to finish...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              ElevatedButton(
                onPressed: _goToMainMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
