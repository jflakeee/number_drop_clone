import 'dart:async';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/auth_service.dart';
import 'battle_screen.dart';

/// Matchmaking screen for finding or creating battles
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  Battle? _battle;
  StreamSubscription<Battle?>? _battleSubscription;
  bool _isSearching = true;
  bool _isReady = false;
  String? _errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _battleSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final battle = await BattleService.instance.findOrCreateBattle();
      if (battle == null) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Failed to find or create battle';
        });
        return;
      }

      setState(() {
        _battle = battle;
        _isSearching = false;
      });

      // Subscribe to battle updates
      _battleSubscription =
          BattleService.instance.watchBattle(battle.id).listen((updatedBattle) {
        if (updatedBattle == null) {
          // Battle was deleted
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        setState(() => _battle = updatedBattle);

        // Check if both players are ready and battle should start
        if (updatedBattle.allPlayersReady &&
            updatedBattle.status == BattleStatus.waiting) {
          _startBattle();
        }

        // Check if battle started
        if (updatedBattle.status == BattleStatus.playing) {
          _goToBattleScreen();
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _toggleReady() async {
    if (_battle == null) return;

    final newReady = !_isReady;
    final success =
        await BattleService.instance.setPlayerReady(_battle!.id, newReady);
    if (success && mounted) {
      setState(() => _isReady = newReady);
    }
  }

  Future<void> _startBattle() async {
    if (_battle == null) return;

    // Only the first player (host) starts the battle
    final auth = AuthService.instance;
    final players = _battle!.players.values.toList();
    if (players.isNotEmpty && players.first.userId == auth.userId) {
      await BattleService.instance.startBattle(_battle!.id);
    }
  }

  void _goToBattleScreen() {
    if (_battle == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BattleScreen(battle: _battle!),
      ),
    );
  }

  Future<void> _leaveBattle() async {
    if (_battle != null) {
      await BattleService.instance.leaveBattle(_battle!.id);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _leaveBattle,
        ),
        title: const Text(
          'BATTLE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildError();
    }

    if (_isSearching) {
      return _buildSearching();
    }

    if (_battle == null) {
      return _buildError();
    }

    return _buildLobby();
  }

  Widget _buildSearching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _animationController,
            child: const Icon(
              Icons.sync,
              color: GameColors.primary,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Finding opponent...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? 'Unknown error',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startMatchmaking,
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    final battle = _battle!;
    final auth = AuthService.instance;
    final myId = auth.userId;
    final players = battle.players.values.toList();
    final opponent = battle.getOpponent(myId ?? '');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Battle info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Room: ${battle.id.substring(0, 8)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seed: ${battle.seed}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // VS Display
          Expanded(
            child: Row(
              children: [
                // Player 1 (Me)
                Expanded(
                  child: _buildPlayerCard(
                    player: battle.getPlayer(myId ?? ''),
                    isMe: true,
                    isReady: _isReady,
                  ),
                ),

                // VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'VS',
                        style: TextStyle(
                          color: GameColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: GameColors.primary.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Player 2 (Opponent)
                Expanded(
                  child: _buildPlayerCard(
                    player: opponent,
                    isMe: false,
                    isReady: opponent?.isReady ?? false,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Ready button
          if (battle.isFull)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleReady,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isReady ? Colors.green : GameColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isReady ? 'WAITING...' : 'READY',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                RotationTransition(
                  turns: _animationController,
                  child: const Icon(
                    Icons.hourglass_empty,
                    color: Colors.white54,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for opponent...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Cancel button
          TextButton(
            onPressed: _leaveBattle,
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    BattlePlayer? player,
    required bool isMe,
    required bool isReady,
  }) {
    if (player == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              color: Colors.white.withOpacity(0.3),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.green.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? Colors.green : Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey[700],
            backgroundImage: player.photoUrl != null
                ? NetworkImage(player.photoUrl!)
                : null,
            child: player.photoUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 32)
                : null,
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            player.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (isMe) ...[
            const SizedBox(height: 4),
            Text(
              '(You)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Ready status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isReady
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isReady ? 'READY' : 'NOT READY',
              style: TextStyle(
                color: isReady ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
