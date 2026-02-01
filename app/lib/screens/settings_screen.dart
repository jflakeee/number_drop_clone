import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/game_settings.dart';
import '../services/audio_service.dart';
import '../services/vibration_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

/// Settings screen with gameplay, animation, and theme options
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sfxEnabled = true;
  bool _bgmEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _sfxEnabled = AudioService.instance.sfxEnabled;
      _bgmEnabled = AudioService.instance.bgmEnabled;
      _vibrationEnabled = VibrationService.instance.enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: GameColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: SettingsService.instance,
          builder: (context, _) {
            final settings = SettingsService.instance.settings;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Gameplay section
                _buildSectionTitle('GAMEPLAY'),
                const SizedBox(height: 12),
                _buildSliderTile(
                  icon: Icons.arrow_downward,
                  title: 'Drop Speed',
                  value: settings.dropDuration.toDouble(),
                  min: GameSettings.minDuration.toDouble(),
                  max: GameSettings.maxDuration.toDouble(),
                  divisions: (GameSettings.maxDuration - GameSettings.minDuration) ~/ GameSettings.durationStep,
                  suffix: 'ms',
                  onChanged: (value) {
                    SettingsService.instance.setDropDuration(value.toInt());
                  },
                ),
                const SizedBox(height: 8),
                _buildSliderTile(
                  icon: Icons.merge_type,
                  title: 'Merge Speed',
                  value: settings.mergeDuration.toDouble(),
                  min: GameSettings.minDuration.toDouble(),
                  max: GameSettings.maxDuration.toDouble(),
                  divisions: (GameSettings.maxDuration - GameSettings.minDuration) ~/ GameSettings.durationStep,
                  suffix: 'ms',
                  onChanged: (value) {
                    SettingsService.instance.setMergeDuration(value.toInt());
                  },
                ),
                const SizedBox(height: 8),
                _buildSliderTile(
                  icon: Icons.downloading,
                  title: 'Gravity Speed',
                  value: settings.gravityDuration.toDouble(),
                  min: GameSettings.minDuration.toDouble(),
                  max: GameSettings.maxDuration.toDouble(),
                  divisions: (GameSettings.maxDuration - GameSettings.minDuration) ~/ GameSettings.durationStep,
                  suffix: 'ms',
                  onChanged: (value) {
                    SettingsService.instance.setGravityDuration(value.toInt());
                  },
                ),
                const SizedBox(height: 8),
                _buildSettingTile(
                  icon: Icons.blur_on,
                  title: 'Ghost Block Preview',
                  value: settings.showGhostBlock,
                  onChanged: (value) {
                    SettingsService.instance.setShowGhostBlock(value);
                  },
                ),
                const SizedBox(height: 8),
                _buildSettingTile(
                  icon: Icons.vibration,
                  title: 'Screen Shake',
                  value: settings.screenShakeEnabled,
                  onChanged: (value) {
                    SettingsService.instance.setScreenShakeEnabled(value);
                  },
                ),

                const SizedBox(height: 32),

                // Animation section
                _buildSectionTitle('ANIMATION'),
                const SizedBox(height: 12),
                _buildDropdownTile<EasingType>(
                  icon: Icons.timeline,
                  title: 'Easing Style',
                  value: settings.easingType,
                  items: EasingType.values,
                  labelBuilder: (e) => '${e.koreanName} (${e.name})',
                  onChanged: (value) {
                    if (value != null) {
                      SettingsService.instance.setEasingType(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildDropdownTile<MergeAnimationType>(
                  icon: Icons.auto_awesome,
                  title: 'Merge Effect',
                  value: settings.mergeAnimation,
                  items: MergeAnimationType.values,
                  labelBuilder: (e) => '${e.koreanName} (${e.name})',
                  onChanged: (value) {
                    if (value != null) {
                      SettingsService.instance.setMergeAnimation(value);
                    }
                  },
                ),

                const SizedBox(height: 32),

                // Theme section
                _buildSectionTitle('THEME'),
                const SizedBox(height: 12),
                _buildThemeSelector(settings.blockTheme),

                const SizedBox(height: 32),

                // Sound section
                _buildSectionTitle('SOUND'),
                const SizedBox(height: 12),
                _buildSettingTile(
                  icon: Icons.music_note,
                  title: 'Background Music',
                  value: _bgmEnabled,
                  onChanged: (value) {
                    setState(() {
                      _bgmEnabled = value;
                    });
                    AudioService.instance.setBGMEnabled(value);
                  },
                ),
                const SizedBox(height: 8),
                _buildSettingTile(
                  icon: Icons.volume_up,
                  title: 'Sound Effects',
                  value: _sfxEnabled,
                  onChanged: (value) {
                    setState(() {
                      _sfxEnabled = value;
                    });
                    AudioService.instance.setSFXEnabled(value);
                  },
                ),

                const SizedBox(height: 32),

                // Haptics section
                _buildSectionTitle('HAPTICS'),
                const SizedBox(height: 12),
                _buildSettingTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                    VibrationService.instance.setEnabled(value);
                  },
                ),

                const SizedBox(height: 32),

                // Data section
                _buildSectionTitle('DATA'),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.restore,
                  title: 'Reset Settings',
                  subtitle: 'Restore default settings',
                  color: Colors.orange,
                  onTap: () => _showResetSettingsConfirmation(context),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.delete_outline,
                  title: 'Reset Progress',
                  subtitle: 'Clear all saved data',
                  color: Colors.red,
                  onTap: () => _showResetConfirmation(context),
                ),

                const SizedBox(height: 32),

                // About section
                _buildSectionTitle('ABOUT'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  value: '1.0.0',
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.code,
                  title: 'Built with',
                  value: 'Flutter',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.boardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GameColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.boardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${value.toInt()}$suffix',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: GameColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: GameColors.primary,
              overlayColor: GameColors.primary.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required IconData icon,
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.boardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          DropdownButton<T>(
            value: value,
            dropdownColor: GameColors.boardBackground,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BlockTheme currentTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.boardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette, color: Colors.white70, size: 24),
              const SizedBox(width: 16),
              const Text(
                'Block Theme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BlockTheme.values.map((theme) {
              final isSelected = theme == currentTheme;
              return GestureDetector(
                onTap: () {
                  SettingsService.instance.setBlockTheme(theme);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GameColors.primary.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: GameColors.primary, width: 2)
                        : null,
                  ),
                  child: Text(
                    theme.koreanName,
                    style: TextStyle(
                      color: isSelected ? GameColors.primary : Colors.white70,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GameColors.boardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.boardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Reset Settings?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will restore all gameplay, animation, and theme settings to their default values.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await SettingsService.instance.resetToDefaults();
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings have been reset'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text(
              'RESET',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Reset Progress?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all your saved data including high score, coins, and statistics. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await StorageService.instance.clearAll();
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Progress has been reset'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'RESET',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
