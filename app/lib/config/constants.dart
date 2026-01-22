/// Game constants and configuration
class GameConstants {
  // Board dimensions
  static const int columns = 5;
  static const int rows = 8;

  // Block values
  static const int minBlockValue = 2;
  static const int maxDropValue = 64; // Max value that can be dropped
  static const List<int> dropValues = [2, 4, 8, 16, 32, 64];

  // Animation durations (milliseconds)
  static const int dropDuration = 120;
  static const int mergeDuration = 250;
  static const int mergeMoveDuration = 180; // blocks moving to merge target
  static const int scoreFadeDuration = 500;
  static const int comboDuration = 500;
  static const int gravityDuration = 80;

  // Scoring
  static const int baseScore = 0;

  // Combo rewards (coins)
  static const Map<int, int> comboRewards = {
    2: 1,
    3: 1,
    4: 2,
    5: 2,
    6: 3,
    7: 3,
    8: 4,
    9: 4,
    10: 5,
  };

  // Target blocks for goal system
  static const List<int> targetBlocks = [512, 1024, 2048, 4096, 8192, 16384];

  // Rank up thresholds (score)
  static const List<int> rankUpThresholds = [
    5000,
    10000,
    25000,
    50000,
    100000,
    200000,
    500000,
    1000000,
  ];

  // Item costs (coins)
  static const int undoCost = 50;
  static const int hammerCost = 100;

  // Mascot progress
  static const int mascotGoalCoins = 5000;

  // Ad rewards
  static const int adRewardCoins = 100;
  static const int adRewardCoinsMax = 120;

  // Daily bonus
  static const int dailyBonusCoins = 100;

  // Get combo reward for a specific combo count
  static int getComboReward(int comboCount) {
    if (comboCount < 2) return 0;
    if (comboCount >= 10) return 5;
    return comboRewards[comboCount] ?? 0;
  }
}
