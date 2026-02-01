import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../config/game_settings.dart';
import '../models/block.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../animations/easing_curves.dart';
import '../animations/merge_effects/merge_effect_factory.dart';
import '../config/block_themes.dart';
import 'animated_block_widget.dart';
import 'score_popup.dart';

/// Animated game board with drop, merge, and gravity effects
class AnimatedGameBoard extends StatefulWidget {
  final bool hammerMode;
  final void Function(int row, int column)? onHammerUse;

  const AnimatedGameBoard({
    super.key,
    this.hammerMode = false,
    this.onHammerUse,
  });

  @override
  State<AnimatedGameBoard> createState() => _AnimatedGameBoardState();
}

class _AnimatedGameBoardState extends State<AnimatedGameBoard>
    with TickerProviderStateMixin {
  int? _hoveredColumn;
  int? _droppingColumn;
  double _dropProgress = 1.0;
  AnimationController? _dropController;
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  // Score popups
  final List<_ScorePopupData> _scorePopups = [];

  // Track which blocks are newly placed or merging
  final Set<String> _newBlocks = {};
  final Set<String> _mergingBlocks = {};

  // Track previously seen block IDs to detect merges
  final Set<String> _knownBlockIds = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final settings = SettingsService.instance.settings;

    _dropController = AnimationController(
      duration: Duration(milliseconds: settings.dropDuration),
      vsync: this,
    )..addListener(() {
        setState(() {
          _dropProgress = _dropController!.value;
        });
      });

    // Screen shake controller
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _shakeController!,
        curve: const ShakeCurve(shakes: 3, decay: 0.5),
      ),
    );
  }

  @override
  void dispose() {
    _dropController?.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  void _triggerShake() {
    if (SettingsService.instance.screenShakeEnabled) {
      _shakeController?.forward(from: 0);
    }
  }

  void _handleDrop(GameState gameState, int column) async {
    if (gameState.isGameOver || gameState.isPaused) return;
    if (gameState.currentBlock == null) return;

    // Check if drop during merge is allowed
    final allowDropDuringMerge = SettingsService.instance.allowDropDuringMerge;
    if (_droppingColumn != null && !allowDropDuringMerge) return; // 이미 떨어지는 중이면 무시
    if (gameState.isMerging && !allowDropDuringMerge) return; // 병합 중이면 무시

    setState(() {
      _droppingColumn = column;
    });

    // Play drop sound
    AudioService.instance.playDrop();

    final prevScore = gameState.score;
    final prevCombo = gameState.comboCount;

    // Drop the block immediately (no animation)
    await gameState.dropBlock(column);

    // Play merge sound if score changed (meaning merge happened)
    if (gameState.score > prevScore) {
      AudioService.instance.playMerge();
      _triggerShake();
    }

    // Play combo sound if combo increased
    if (gameState.comboCount > prevCombo && gameState.comboCount > 1) {
      AudioService.instance.playCombo(gameState.comboCount);
    }

    setState(() {
      _droppingColumn = null;
    });
  }

  // ignore: unused_element
  void _addScorePopup(int score, Offset position) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _scorePopups.add(_ScorePopupData(id: id, score: score, position: position));
    });
  }

  void _removeScorePopup(String id) {
    setState(() {
      _scorePopups.removeWhere((p) => p.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        return ListenableBuilder(
          listenable: SettingsService.instance,
          builder: (context, _) {
            final settings = SettingsService.instance.settings;

            return LayoutBuilder(
              builder: (context, constraints) {
                final boardWidth = constraints.maxWidth;
                final boardHeight = constraints.maxHeight;
                final cellWidth = boardWidth / GameConstants.columns;
                final cellHeight = boardHeight / GameConstants.rows;
                final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

                return AnimatedBuilder(
                  animation: _shakeAnimation ?? const AlwaysStoppedAnimation(0),
                  builder: (context, child) {
                    final shakeOffset = (_shakeAnimation?.value ?? 0) * 3;

                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: MouseRegion(
                        onHover: (event) {
                          if (widget.hammerMode) return;
                          if (gameState.isGameOver || gameState.isPaused) return;

                          final column = (event.localPosition.dx / cellWidth).floor();
                          if (column >= 0 && column < GameConstants.columns) {
                            if (_hoveredColumn != column) {
                              setState(() {
                                _hoveredColumn = column;
                              });
                            }
                          }
                        },
                        onExit: (_) {
                          if (_hoveredColumn != null) {
                            setState(() {
                              _hoveredColumn = null;
                            });
                          }
                        },
                        child: GestureDetector(
                          onTapDown: (details) {
                            if (gameState.isGameOver || gameState.isPaused) return;
                            if (_droppingColumn != null) return;

                            final column = (details.localPosition.dx / cellWidth).floor();
                            final row = (details.localPosition.dy / cellHeight).floor();

                            // Hammer mode
                            if (widget.hammerMode) {
                              if (row >= 0 &&
                                  row < GameConstants.rows &&
                                  column >= 0 &&
                                  column < GameConstants.columns) {
                                widget.onHammerUse?.call(row, column);
                              }
                              return;
                            }

                            // Normal mode - drop block
                            if (column >= 0 && column < GameConstants.columns) {
                              _handleDrop(gameState, column);
                            }
                          },
                          onPanUpdate: (details) {
                            if (widget.hammerMode) return;

                            final column = (details.localPosition.dx / cellWidth).floor();
                            if (column >= 0 && column < GameConstants.columns) {
                              setState(() {
                                _hoveredColumn = column;
                              });
                            }
                          },
                          onPanEnd: (_) {
                            if (widget.hammerMode) return;
                            if (_droppingColumn != null) return;

                            if (_hoveredColumn != null &&
                                !gameState.isGameOver &&
                                !gameState.isPaused) {
                              _handleDrop(gameState, _hoveredColumn!);
                            }
                            setState(() {
                              _hoveredColumn = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: GameColors.boardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: widget.hammerMode
                                  ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
                                  : Border.all(color: const Color(0xFF2A3A4A), width: 2),
                            ),
                            child: Stack(
                              children: [
                                // Column dividers
                                _buildColumnDividers(boardWidth, boardHeight, cellWidth),

                                // Column highlight
                                if (!widget.hammerMode && _hoveredColumn != null)
                                  _buildColumnHighlight(
                                      _hoveredColumn!, boardHeight, cellWidth),

                                // Drop shadow preview (ghost block)
                                if (!widget.hammerMode &&
                                    _hoveredColumn != null &&
                                    gameState.currentBlock != null &&
                                    _droppingColumn == null &&
                                    settings.showGhostBlock)
                                  _buildDropShadow(
                                    gameState,
                                    _hoveredColumn!,
                                    cellWidth,
                                    cellHeight,
                                    cellSize,
                                  ),

                                // Placed blocks
                                ..._buildPlacedBlocks(
                                  gameState,
                                  cellWidth,
                                  cellHeight,
                                  cellSize,
                                  settings,
                                ),

                                // Merge animations
                                ..._buildMergeAnimations(
                                  gameState,
                                  cellWidth,
                                  cellHeight,
                                  cellSize,
                                  settings,
                                ),

                                // Score popups
                                ..._scorePopups.map((popup) {
                                  return ScorePopup(
                                    key: ValueKey(popup.id),
                                    score: popup.score,
                                    position: popup.position,
                                    onComplete: () => _removeScorePopup(popup.id),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildColumnDividers(double width, double height, double cellWidth) {
    return Stack(
      children: List.generate(GameConstants.columns - 1, (index) {
        return Positioned(
          left: (index + 1) * cellWidth,
          top: 0,
          child: Container(
            width: 1,
            height: height,
            color: GameColors.columnDivider,
          ),
        );
      }),
    );
  }

  Widget _buildColumnHighlight(int column, double height, double cellWidth) {
    return Positioned(
      left: column * cellWidth,
      top: 0,
      child: Container(
        width: cellWidth,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF26C6DA).withOpacity(0.3),
              const Color(0xFF26C6DA).withOpacity(0.15),
              const Color(0xFF26C6DA).withOpacity(0.05),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildDropShadow(
    GameState gameState,
    int column,
    double cellWidth,
    double cellHeight,
    double cellSize,
  ) {
    int landingRow = _findLandingRow(gameState.board, column);
    if (landingRow < 0) return const SizedBox.shrink();

    final shadowBlock = gameState.currentBlock!.copyWith(
      row: landingRow,
      column: column,
    );

    return Positioned(
      left: column * cellWidth + (cellWidth - cellSize) / 2,
      top: landingRow * cellHeight + (cellHeight - cellSize) / 2,
      child: AnimatedBlockWidget(
        block: shadowBlock,
        size: cellSize - 4,
        showShadow: true,
      ),
    );
  }

  Widget _buildDroppingBlock(
    GameState gameState,
    int column,
    double cellWidth,
    double cellHeight,
    double cellSize,
  ) {
    int landingRow = _findLandingRow(gameState.board, column);
    if (landingRow < 0) return const SizedBox.shrink();

    // Calculate current position based on animation progress
    final startY = -cellHeight;
    final endY = landingRow * cellHeight + (cellHeight - cellSize) / 2;
    final currentY = startY + (endY - startY) * _dropProgress;

    return Positioned(
      left: column * cellWidth + (cellWidth - cellSize) / 2,
      top: currentY,
      child: AnimatedBlockWidget(
        block: gameState.currentBlock!.copyWith(
          row: landingRow,
          column: column,
        ),
        size: cellSize - 4,
      ),
    );
  }

  List<Widget> _buildPlacedBlocks(
    GameState gameState,
    double cellWidth,
    double cellHeight,
    double cellSize,
    GameSettings settings,
  ) {
    final widgets = <Widget>[];
    final easingType = settings.easingType;

    for (int row = 0; row < GameConstants.rows; row++) {
      for (int col = 0; col < GameConstants.columns; col++) {
        final block = gameState.board[row][col];
        if (block == null) continue;

        // Track block IDs
        if (!_knownBlockIds.contains(block.id)) {
          _knownBlockIds.add(block.id);
        }

        // Check if this block is currently merging
        final isMergingBlock = gameState.mergingBlockIds.contains(block.id);
        final duration = isMergingBlock
            ? settings.mergeMoveDuration
            : settings.gravityDuration;

        // Get appropriate curve based on settings
        final curve = isMergingBlock
            ? GameEasings.getMergeCurve(easingType)
            : GameEasings.getGravityCurve(easingType);

        widgets.add(
          AnimatedPositioned(
            key: ValueKey(block.id),
            duration: Duration(milliseconds: duration),
            curve: curve,
            left: block.column * cellWidth + (cellWidth - cellSize) / 2,
            top: block.row * cellHeight + (cellHeight - cellSize) / 2,
            child: GestureDetector(
              onTap: widget.hammerMode
                  ? () => widget.onHammerUse?.call(block.row, block.column)
                  : null,
              child: _buildBlockWithEffect(
                block: block,
                size: cellSize - 4,
                isHammerTarget: widget.hammerMode,
                isMerging: isMergingBlock,
                settings: settings,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildBlockWithEffect({
    required Block block,
    required double size,
    required bool isHammerTarget,
    required bool isMerging,
    required GameSettings settings,
  }) {
    Widget blockWidget = AnimatedBlockWidget(
      block: block,
      size: size,
      isHammerTarget: isHammerTarget,
      isNew: false,
      isMerging: isMerging,
    );

    // Apply merge effect if merging
    if (isMerging) {
      final effect = MergeEffectFactory.create(settings.mergeAnimation);
      // Note: In a full implementation, we would need to track the merge animation
      // progress. For now, the effect is applied through AnimatedBlockWidget.
    }

    return blockWidget;
  }

  List<Widget> _buildMergeAnimations(
    GameState gameState,
    double cellWidth,
    double cellHeight,
    double cellSize,
    GameSettings settings,
  ) {
    if (!gameState.isMerging || gameState.mergeAnimations.isEmpty) {
      return [];
    }

    final widgets = <Widget>[];
    final easingType = settings.easingType;
    final mergeEffect = MergeEffectFactory.create(settings.mergeAnimation);

    // Add dropping block animation for below-merge (gravity effect)
    if (gameState.droppingBlock != null) {
      final drop = gameState.droppingBlock!;
      widgets.add(
        TweenAnimationBuilder<double>(
          key: ValueKey('dropping_${drop.id}'),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: settings.mergeMoveDuration),
          curve: GameEasings.getGravityCurve(easingType),
          builder: (context, value, child) {
            final startY = drop.startRow * cellHeight + (cellHeight - cellSize) / 2;
            final meetY = drop.meetRowFraction * cellHeight + (cellHeight - cellSize) / 2;
            final finalY = drop.belowBlockRow * cellHeight + (cellHeight - cellSize) / 2;
            final x = drop.column * cellWidth + (cellWidth - cellSize) / 2;

            double currentY;
            int displayValue;
            double scale = 1.0;

            if (value < 0.5) {
              final phase1Progress = value * 2;
              currentY = startY + (meetY - startY) * phase1Progress;
              displayValue = drop.value;
            } else {
              final phase2Progress = (value - 0.5) * 2;
              currentY = meetY + (finalY - meetY) * phase2Progress;
              displayValue = drop.mergedValue;

              if (phase2Progress < 0.5) {
                scale = 1.0 + 0.2 * (phase2Progress * 2);
              } else {
                scale = 1.2 - 0.2 * ((phase2Progress - 0.5) * 2);
              }
            }

            Widget blockWidget = AnimatedBlockWidget(
              block: Block(
                value: displayValue,
                row: drop.belowBlockRow,
                column: drop.column,
                id: drop.id,
              ),
              size: cellSize - 4,
            );

            // Apply merge effect during phase 2
            if (value >= 0.5) {
              final effectProgress = (value - 0.5) * 2;
              final themeData = BlockThemes.getTheme(settings.blockTheme);
              blockWidget = mergeEffect.build(
                blockWidget,
                AlwaysStoppedAnimation(effectProgress),
                themeData.getColor(displayValue),
              );
            }

            return Positioned(
              left: x,
              top: currentY,
              child: Transform.scale(
                scale: scale,
                child: blockWidget,
              ),
            );
          },
        ),
      );
    }

    // Add merge animations for other blocks
    for (final anim in gameState.mergeAnimations) {
      if (anim.isBelowMerge) {
        widgets.add(
          TweenAnimationBuilder<double>(
            key: ValueKey('merge_below_${anim.id}'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: settings.mergeMoveDuration),
            curve: GameEasings.getMergeCurve(easingType),
            builder: (context, value, child) {
              final startX = anim.fromColumn * cellWidth + (cellWidth - cellSize) / 2;
              final startY = anim.fromRow * cellHeight + (cellHeight - cellSize) / 2;
              final targetY = anim.toRow * cellHeight + (cellHeight - cellSize) / 2;

              final meetY = (startY + targetY) / 2;
              final moveProgress = value < 0.5 ? value * 2 : 1.0;
              final currentY = startY + (meetY - startY) * moveProgress;
              final opacity = value < 0.5 ? 1.0 : 1.0 - ((value - 0.5) * 2);
              final scale = value < 0.5 ? 1.0 : 1.0 - ((value - 0.5) * 0.6);

              return Positioned(
                left: startX,
                top: currentY,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale.clamp(0.4, 1.0),
                    child: AnimatedBlockWidget(
                      block: Block(
                        value: anim.value,
                        row: anim.toRow,
                        column: anim.toColumn,
                        id: anim.id,
                      ),
                      size: cellSize - 4,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      } else {
        widgets.add(
          TweenAnimationBuilder<double>(
            key: ValueKey('merge_${anim.id}'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: settings.mergeMoveDuration),
            curve: GameEasings.getMergeCurve(easingType),
            builder: (context, value, child) {
              final startX = anim.fromColumn * cellWidth + (cellWidth - cellSize) / 2;
              final startY = anim.fromRow * cellHeight + (cellHeight - cellSize) / 2;
              final endX = anim.toColumn * cellWidth + (cellWidth - cellSize) / 2;
              final endY = anim.toRow * cellHeight + (cellHeight - cellSize) / 2;

              double currentX;
              double currentY;

              if (startX != endX && startY != endY) {
                if (value < 0.5) {
                  final hProgress = value * 2;
                  currentX = startX + (endX - startX) * hProgress;
                  currentY = startY;
                } else {
                  final vProgress = (value - 0.5) * 2;
                  currentX = endX;
                  currentY = startY + (endY - startY) * vProgress;
                }
              } else {
                currentX = startX + (endX - startX) * value;
                currentY = startY + (endY - startY) * value;
              }

              final opacity = 1.0 - (value * 0.3);
              final scale = 1.0 - (value * 0.2);

              return Positioned(
                left: currentX,
                top: currentY,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale.clamp(0.8, 1.0),
                    child: AnimatedBlockWidget(
                      block: Block(
                        value: anim.value,
                        row: anim.toRow,
                        column: anim.toColumn,
                        id: anim.id,
                      ),
                      size: cellSize - 4,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return widgets;
  }

  int _findLandingRow(List<List<Block?>> board, int column) {
    for (int row = GameConstants.rows - 1; row >= 0; row--) {
      if (board[row][column] == null) {
        return row;
      }
    }
    return -1;
  }
}

class _ScorePopupData {
  final String id;
  final int score;
  final Offset position;

  _ScorePopupData({
    required this.id,
    required this.score,
    required this.position,
  });
}
