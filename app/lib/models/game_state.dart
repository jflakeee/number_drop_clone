import 'dart:math';
import 'package:flutter/foundation.dart';
import 'block.dart';
import '../config/constants.dart';

/// Game state management
class GameState extends ChangeNotifier {
  // Board state: 2D array [row][column]
  late List<List<Block?>> _board;

  // Current and next blocks
  Block? _currentBlock;
  Block? _nextBlock;

  // Score
  int _score = 0;
  int _highScore = 0;

  // Coins
  int _coins = 0;

  // Piggy bank
  int _piggyBankCoins = 0;

  // Game status
  bool _isGameOver = false;
  bool _isPaused = false;

  // Combo tracking
  int _comboCount = 0;

  // Merge animation tracking
  bool _isMerging = false;
  Set<String> _mergingBlockIds = {};
  List<MergeAnimationData> _mergeAnimations = [];
  DroppingBlockData? _droppingBlock; // For below-merge gravity animation

  // Target system
  int _currentTargetIndex = 0;

  // Undo system
  List<List<Block?>>? _savedBoard;
  Block? _savedCurrentBlock;
  Block? _savedNextBlock;
  int _savedScore = 0;
  int _savedCoins = 0;
  bool _canUndo = false;

  // Random generator with seed support
  late Random _random;
  int _gameSeed = 0;

  // Getters
  List<List<Block?>> get board => _board;
  Block? get currentBlock => _currentBlock;
  Block? get nextBlock => _nextBlock;
  int get score => _score;
  int get highScore => _highScore;
  int get coins => _coins;
  int get piggyBankCoins => _piggyBankCoins;
  bool get isGameOver => _isGameOver;
  bool get isPaused => _isPaused;
  int get comboCount => _comboCount;
  bool get canUndo => _canUndo;
  bool get isMerging => _isMerging;
  Set<String> get mergingBlockIds => _mergingBlockIds;
  List<MergeAnimationData> get mergeAnimations => _mergeAnimations;
  DroppingBlockData? get droppingBlock => _droppingBlock;

  int get currentTarget =>
      _currentTargetIndex < GameConstants.targetBlocks.length
          ? GameConstants.targetBlocks[_currentTargetIndex]
          : GameConstants.targetBlocks.last;

  /// Current game seed for reproducible block sequence
  int get gameSeed => _gameSeed;

  /// Generate daily challenge seed (same for all players on the same day)
  static int getDailySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// Generate a random seed
  static int generateRandomSeed() {
    return DateTime.now().millisecondsSinceEpoch % 100000000;
  }

  GameState() {
    _initializeGame();
  }

  /// Initialize or reset the game
  /// [seed] - Optional seed for reproducible block sequence. If null, generates random seed.
  void _initializeGame({int? seed}) {
    // Initialize seed and random generator
    _gameSeed = seed ?? generateRandomSeed();
    _random = Random(_gameSeed);

    _board = List.generate(
      GameConstants.rows,
      (_) => List.filled(GameConstants.columns, null),
    );
    _score = 0;
    _piggyBankCoins = 0;
    _isGameOver = false;
    _isPaused = false;
    _comboCount = 0;
    _isMerging = false;
    _mergingBlockIds = {};
    _mergeAnimations = [];
    _droppingBlock = null;
    _currentTargetIndex = 0;
    _canUndo = false;
    _savedBoard = null;
    _savedCurrentBlock = null;
    _savedNextBlock = null;
    _savedScore = 0;
    _savedCoins = 0;

    _generateNextBlock();
    _generateNextBlock();
  }

  /// Start a new game
  /// [seed] - Optional seed for reproducible block sequence
  void newGame({int? seed}) {
    _initializeGame(seed: seed);
    notifyListeners();
  }

  /// Start a daily challenge game (same seed for everyone today)
  void newDailyChallenge() {
    _initializeGame(seed: getDailySeed());
    notifyListeners();
  }

  /// Start a game with a specific seed (for challenges/sharing)
  void newGameWithSeed(int seed) {
    _initializeGame(seed: seed);
    notifyListeners();
  }

  /// Generate a random block value
  int _generateRandomValue() {
    // Weighted random: smaller numbers more common
    final weights = [40, 30, 15, 10, 4, 1]; // 2, 4, 8, 16, 32, 64
    final totalWeight = weights.reduce((a, b) => a + b);
    var random = _random.nextInt(totalWeight);

    for (int i = 0; i < weights.length; i++) {
      random -= weights[i];
      if (random < 0) {
        return GameConstants.dropValues[i];
      }
    }
    return GameConstants.dropValues[0];
  }

  /// Generate the next block
  void _generateNextBlock() {
    _currentBlock = _nextBlock;
    _nextBlock = Block(
      value: _generateRandomValue(),
      row: -1,
      column: GameConstants.columns ~/ 2,
    );
  }

  /// Save current state for undo
  void _saveState() {
    // Deep copy the board
    _savedBoard = List.generate(
      GameConstants.rows,
      (row) => List.generate(
        GameConstants.columns,
        (col) => _board[row][col]?.copyWith(),
      ),
    );
    _savedCurrentBlock = _currentBlock?.copyWith();
    _savedNextBlock = _nextBlock?.copyWith();
    _savedScore = _score;
    _savedCoins = _coins;
    _canUndo = true;
  }

  /// Drop block at specified column
  Future<void> dropBlock(int column) async {
    if (_isGameOver || _isPaused || _currentBlock == null) return;
    if (column < 0 || column >= GameConstants.columns) return;

    _saveState();

    // Find landing row
    int landingRow = _findLandingRow(column);
    if (landingRow < 0) {
      // Column is full - game over
      _isGameOver = true;
      _updateHighScore();
      notifyListeners();
      return;
    }

    // Place block
    final block = _currentBlock!.copyWith(row: landingRow, column: column);
    _board[landingRow][column] = block;

    // Reset combo
    _comboCount = 0;

    // Check for merges
    await _checkAndMerge(landingRow, column);

    // Final verification: ensure all possible merges have been processed
    if (_hasPendingMerges()) {
      debugPrint('dropBlock: Additional pending merges detected, processing...');
      await _processAllPendingMerges();
    }

    // Check for game over
    if (_isTopRowBlocked()) {
      _isGameOver = true;
      _updateHighScore();
    }

    // Generate next block
    _generateNextBlock();

    notifyListeners();
  }

  /// Find the landing row for a block in the specified column
  int _findLandingRow(int column) {
    for (int row = GameConstants.rows - 1; row >= 0; row--) {
      if (_board[row][column] == null) {
        return row;
      }
    }
    return -1; // Column is full
  }

  /// Check and perform merges at the specified position
  Future<void> _checkAndMerge(int row, int column) async {
    final block = _board[row][column];
    if (block == null) return;

    // Find all adjacent blocks with same value
    final sameBlocks = _findAdjacentSame(row, column, block.value);

    if (sameBlocks.length >= 2) {
      _comboCount++;

      // Calculate new value based on number of blocks merged
      // 2 blocks = 2x, 3 blocks = 4x, 4 blocks = 8x, etc.
      final mergeCount = sameBlocks.length;
      final multiplier = 1 << (mergeCount - 1); // 2^(n-1)
      final newValue = block.value * multiplier;
      _score += newValue;

      // Award combo coins
      final comboReward = GameConstants.getComboReward(_comboCount);
      if (comboReward > 0) {
        _coins += comboReward;
      }

      // Check for target achievement
      _checkTargetAchievement(newValue);

      // The dropped block position (row, column) is the merge target
      final targetRow = row;
      final targetColumn = column;

      // Separate blocks into below-merges and other merges
      final belowBlocks = <_Position>[];
      final otherBlocks = <_Position>[];

      for (final pos in sameBlocks) {
        if (pos.row != targetRow || pos.column != targetColumn) {
          // Check if this block is directly below in the same column
          if (pos.column == targetColumn && pos.row > targetRow) {
            belowBlocks.add(pos);
          } else {
            otherBlocks.add(pos);
          }
        }
      }

      // Create merge animation data
      _isMerging = true;
      _mergeAnimations = [];

      // Add other blocks (move toward target normally)
      for (final pos in otherBlocks) {
        final movingBlock = _board[pos.row][pos.column];
        if (movingBlock != null) {
          _mergeAnimations.add(MergeAnimationData(
            id: movingBlock.id,
            value: movingBlock.value,
            fromRow: pos.row,
            fromColumn: pos.column,
            toRow: targetRow,
            toColumn: targetColumn,
            isBelowMerge: false,
          ));
        }
      }

      // Add below blocks (move up halfway with magnet effect)
      for (final pos in belowBlocks) {
        final movingBlock = _board[pos.row][pos.column];
        if (movingBlock != null) {
          _mergeAnimations.add(MergeAnimationData(
            id: movingBlock.id,
            value: movingBlock.value,
            fromRow: pos.row,
            fromColumn: pos.column,
            toRow: targetRow,
            toColumn: targetColumn,
            isBelowMerge: true,
            mergedValue: newValue,
          ));
        }
      }

      // Remove moving blocks from board (they will be animated separately)
      for (final pos in sameBlocks) {
        if (pos.row != targetRow || pos.column != targetColumn) {
          _board[pos.row][pos.column] = null;
        }
      }

      // For below merges, set up dropping block animation
      // The dropped block falls with gravity while below block rises with magnet effect
      if (belowBlocks.isNotEmpty) {
        // Find the lowest below block - this is where the merged block will ultimately land
        final lowestBelowRow = belowBlocks.map((p) => p.row).reduce((a, b) => a > b ? a : b);

        // Meeting point is exactly between the dropped block and the below block (as fraction)
        final meetRowFraction = (targetRow + lowestBelowRow) / 2.0;

        _droppingBlock = DroppingBlockData(
          id: block.id,
          value: block.value,
          mergedValue: newValue,
          startRow: targetRow,
          meetRowFraction: meetRowFraction,
          belowBlockRow: lowestBelowRow,
          column: targetColumn,
        );

        // Remove the dropped block from board during animation
        _board[targetRow][targetColumn] = null;
      }

      notifyListeners();

      // Wait for merge animation
      await Future.delayed(Duration(milliseconds: GameConstants.mergeMoveDuration));

      // Clear merge animation state
      _isMerging = false;
      _mergeAnimations = [];

      // For below-merge, place the merged block at belowBlockRow first
      // so it's visible immediately when animation ends
      final wasBelowMerge = _droppingBlock != null;
      final belowBlockRow = _droppingBlock?.belowBlockRow ?? targetRow;
      _droppingBlock = null;

      // Remove the target block (if it exists - may have been removed for below-merge)
      if (_board[targetRow][targetColumn] != null) {
        _board[targetRow][targetColumn] = null;
      }

      // For below-merge, place merged block at belowBlockRow first
      if (wasBelowMerge) {
        _board[belowBlockRow][targetColumn] = Block(
          value: newValue,
          row: belowBlockRow,
          column: targetColumn,
        );
      }

      notifyListeners();

      // Apply gravity to all columns that had merged blocks
      final affectedColumns = sameBlocks.map((p) => p.column).toSet();
      _applyGravity();

      notifyListeners();

      // Wait for gravity animation
      await Future.delayed(Duration(milliseconds: GameConstants.gravityDuration));

      // Find where the merged block is after gravity
      int actualLandingRow;
      if (wasBelowMerge) {
        // For below-merge, find where the block ended up after gravity
        actualLandingRow = -1;
        for (int r = GameConstants.rows - 1; r >= 0; r--) {
          if (_board[r][targetColumn]?.value == newValue) {
            actualLandingRow = r;
            break;
          }
        }
        if (actualLandingRow < 0) actualLandingRow = belowBlockRow;
      } else {
        // For non-below-merge, place the merged block at landing position
        int landingRow = _findLandingRow(targetColumn);
        if (landingRow < 0) landingRow = 0;

        final newBlock = Block(
          value: newValue,
          row: landingRow,
          column: targetColumn,
        );
        _board[landingRow][targetColumn] = newBlock;
        actualLandingRow = landingRow;
      }

      notifyListeners();

      // Small delay for the new block to appear
      await Future.delayed(const Duration(milliseconds: 50));

      // Recursively check for more merges at the new position
      await _checkAndMerge(actualLandingRow, targetColumn);

      // Check all affected columns for chain reactions (check all blocks, not just the lowest)
      for (final col in affectedColumns) {
        if (col != targetColumn) {
          // Check all blocks in this column for potential merges
          for (int r = GameConstants.rows - 1; r >= 0; r--) {
            if (_board[r][col] != null) {
              final sameBlocks = _findAdjacentSame(r, col, _board[r][col]!.value);
              if (sameBlocks.length >= 2) {
                await _checkAndMerge(r, col);
                // After processing a merge, the column structure changed
                // Restart checking this column from the bottom
                r = GameConstants.rows;
              }
            }
          }
        }
      }

      // Final safety check: ensure no merges were missed
      if (_hasPendingMerges()) {
        debugPrint('Warning: Pending merges detected after _checkAndMerge completed');
        await _processAllPendingMerges();
      }
    }
  }

  /// Find adjacent blocks with the same value using BFS
  List<_Position> _findAdjacentSame(int startRow, int startCol, int value) {
    final result = <_Position>[];
    final visited = <String>{};
    final queue = <_Position>[_Position(startRow, startCol)];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final key = '${current.row}_${current.column}';

      if (visited.contains(key)) continue;
      visited.add(key);

      final block = _board[current.row][current.column];
      if (block != null && block.value == value) {
        result.add(current);

        // Check 4 directions
        final directions = [
          _Position(current.row - 1, current.column), // Up
          _Position(current.row + 1, current.column), // Down
          _Position(current.row, current.column - 1), // Left
          _Position(current.row, current.column + 1), // Right
        ];

        for (final dir in directions) {
          if (_isValidPosition(dir.row, dir.column)) {
            queue.add(dir);
          }
        }
      }
    }

    return result;
  }

  /// Check if position is valid
  bool _isValidPosition(int row, int column) {
    return row >= 0 &&
        row < GameConstants.rows &&
        column >= 0 &&
        column < GameConstants.columns;
  }

  /// Apply gravity - move blocks down
  void _applyGravity() {
    for (int col = 0; col < GameConstants.columns; col++) {
      int writeRow = GameConstants.rows - 1;

      for (int row = GameConstants.rows - 1; row >= 0; row--) {
        if (_board[row][col] != null) {
          if (row != writeRow) {
            _board[writeRow][col] =
                _board[row][col]!.copyWith(row: writeRow);
            _board[row][col] = null;
          }
          writeRow--;
        }
      }
    }
  }

  /// Find all pending merges in the entire board
  /// Returns a list of positions where merges are possible
  List<_Position> _findAllPendingMerges() {
    final pendingMerges = <_Position>[];
    final checked = <String>{};

    for (int row = 0; row < GameConstants.rows; row++) {
      for (int col = 0; col < GameConstants.columns; col++) {
        final block = _board[row][col];
        if (block == null) continue;

        final key = '${row}_${col}';
        if (checked.contains(key)) continue;

        final sameBlocks = _findAdjacentSame(row, col, block.value);
        if (sameBlocks.length >= 2) {
          // Found a mergeable group - add the first position
          pendingMerges.add(_Position(row, col));
          // Mark all positions in this group as checked
          for (final pos in sameBlocks) {
            checked.add('${pos.row}_${pos.column}');
          }
        }
      }
    }

    return pendingMerges;
  }

  /// Check if there are any pending merges in the board
  bool _hasPendingMerges() {
    for (int row = 0; row < GameConstants.rows; row++) {
      for (int col = 0; col < GameConstants.columns; col++) {
        final block = _board[row][col];
        if (block == null) continue;

        final sameBlocks = _findAdjacentSame(row, col, block.value);
        if (sameBlocks.length >= 2) {
          return true;
        }
      }
    }
    return false;
  }

  /// Process all pending merges until no more merges are possible
  Future<void> _processAllPendingMerges() async {
    // Safety counter to prevent infinite loops
    int maxIterations = 100;
    int iterations = 0;

    while (iterations < maxIterations) {
      final pendingMerges = _findAllPendingMerges();
      if (pendingMerges.isEmpty) break;

      // Process the first pending merge (which will recursively handle chain reactions)
      final pos = pendingMerges.first;
      await _checkAndMerge(pos.row, pos.column);

      iterations++;
    }

    if (iterations >= maxIterations) {
      debugPrint('Warning: _processAllPendingMerges reached max iterations');
    }
  }

  /// Check if top row is blocked (game over condition)
  bool _isTopRowBlocked() {
    for (int col = 0; col < GameConstants.columns; col++) {
      if (_board[0][col] != null) {
        return true;
      }
    }
    return false;
  }

  /// Check for target achievement
  void _checkTargetAchievement(int value) {
    if (_currentTargetIndex < GameConstants.targetBlocks.length &&
        value >= GameConstants.targetBlocks[_currentTargetIndex]) {
      _currentTargetIndex++;
      // Award bonus coins for target achievement
      _coins += 50;
    }
  }

  /// Update high score
  void _updateHighScore() {
    if (_score > _highScore) {
      _highScore = _score;
    }
  }

  /// Undo last move
  void undo() {
    if (!_canUndo || _savedBoard == null) return;

    // Restore saved state
    _board = List.generate(
      GameConstants.rows,
      (row) => List.generate(
        GameConstants.columns,
        (col) => _savedBoard![row][col]?.copyWith(),
      ),
    );
    _currentBlock = _savedCurrentBlock?.copyWith();
    _nextBlock = _savedNextBlock?.copyWith();
    _score = _savedScore;
    _coins = _savedCoins;
    _isGameOver = false;

    _canUndo = false;
    notifyListeners();
  }

  /// Use hammer to remove a block
  bool useHammer(int row, int column) {
    if (_coins < GameConstants.hammerCost) return false;
    if (_board[row][column] == null) return false;

    _coins -= GameConstants.hammerCost;
    _board[row][column] = null;
    _applyGravity();
    notifyListeners();
    return true;
  }

  /// Shuffle: swap current block with next block
  bool shuffle() {
    if (_coins < GameConstants.shuffleCost) return false;
    if (_currentBlock == null || _nextBlock == null) return false;

    _coins -= GameConstants.shuffleCost;

    // Swap current and next blocks
    final temp = _currentBlock;
    _currentBlock = _nextBlock;
    _nextBlock = temp;

    notifyListeners();
    return true;
  }

  /// Add coins
  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }

  /// Set high score (for loading from storage)
  void setHighScore(int score) {
    _highScore = score;
  }

  /// Set coins (for loading from storage)
  void setCoins(int coins) {
    _coins = coins;
    notifyListeners();
  }

  /// Add coins to piggy bank
  void addToPiggyBank(int amount) {
    _piggyBankCoins += amount;
    notifyListeners();
  }

  /// Collect piggy bank coins
  void collectPiggyBank() {
    if (_piggyBankCoins >= GameConstants.mascotGoalCoins) {
      _coins += _piggyBankCoins;
      _piggyBankCoins = 0;
      notifyListeners();
    }
  }

  /// Pause the game
  void pause() {
    _isPaused = true;
    notifyListeners();
  }

  /// Resume the game
  void resume() {
    _isPaused = false;
    notifyListeners();
  }
}

/// Helper class for position
class _Position {
  final int row;
  final int column;

  _Position(this.row, this.column);
}

/// Data for merge animation
class MergeAnimationData {
  final String id;
  final int value;
  final int fromRow;
  final int fromColumn;
  final int toRow;
  final int toColumn;
  final bool isBelowMerge; // True if this block is below the dropped block
  final int? mergedValue; // The value after merge (for the falling block)

  MergeAnimationData({
    required this.id,
    required this.value,
    required this.fromRow,
    required this.fromColumn,
    required this.toRow,
    required this.toColumn,
    this.isBelowMerge = false,
    this.mergedValue,
  });
}

/// Data for the dropping block during below-merge animation
class DroppingBlockData {
  final String id;
  final int value;
  final int mergedValue;
  final int startRow; // Where the block was dropped
  final double meetRowFraction; // Where blocks meet (midpoint as fraction)
  final int belowBlockRow; // Row of the below block (for reference)
  final int column;

  DroppingBlockData({
    required this.id,
    required this.value,
    required this.mergedValue,
    required this.startRow,
    required this.meetRowFraction,
    required this.belowBlockRow,
    required this.column,
  });
}
