import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/colors.dart';
import '../models/game_state.dart';
import '../screens/ranking_screen.dart';

/// Widget displaying score, high score, coins, and action buttons
class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // Top row: coins and action buttons
              Row(
                children: [
                  // Coins
                  _buildCoinDisplay(gameState.coins),

                  const Spacer(),

                  // Action buttons
                  _buildIconButton(
                    Icons.pause,
                    onTap: () => gameState.pause(),
                  ),
                  const SizedBox(width: 3),
                  _buildIconButton(
                    Icons.leaderboard,
                    onTap: () {
                      gameState.pause();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RankingScreen()),
                      ).then((_) => gameState.resume());
                    },
                  ),
                  const SizedBox(width: 3),
                  _buildIconButton(
                    Icons.undo,
                    onTap: gameState.canUndo ? () => gameState.undo() : () {},
                  ),
                  const SizedBox(width: 3),
                  _buildIconButton(
                    Icons.share,
                    onTap: () {
                      Share.share(
                        'I scored ${_formatNumber(gameState.score)} points in Number Drop! Can you beat me? 🎮\nSeed: ${gameState.gameSeed}',
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Score row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // High score
                  const Icon(Icons.emoji_events, color: GameColors.coinYellow, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    _formatNumber(gameState.highScore),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  // Current score
                  Text(
                    _formatNumber(gameState.score),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoinDisplay(int coins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3D5A80),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
              child: Text('😊', style: TextStyle(fontSize: 8)),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            _formatNumber(coins),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF3D5A80),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}K';
    }
    return number.toString();
  }
}
