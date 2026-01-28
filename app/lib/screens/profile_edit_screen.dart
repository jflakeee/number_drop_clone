import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Profile edit screen for changing display name
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _profile;

  // Forbidden words list (can be extended)
  static const List<String> _forbiddenWords = [
    'admin',
    'moderator',
    'official',
    'support',
  ];

  @override
  void initState() {
    super.initState();
    // Check if user is signed in with Google
    if (AuthService.instance.isAnonymous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGoogleSignInRequired();
      });
    } else {
      _loadProfile();
    }
  }

  void _showGoogleSignInRequired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.boardBackground,
        title: const Text(
          'Google Sign-In Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You need to sign in with Google to customize your display name.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Go Back',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final user = await AuthService.instance.signInWithGoogle();
              if (user != null && mounted) {
                _loadProfile();
              } else if (mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.g_mobiledata, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.primary,
            ),
            label: const Text('Sign In with Google'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await AuthService.instance.getUserProfile();
      if (profile != null) {
        _profile = profile;
        _nameController.text = profile.displayName;
      } else {
        // Use Google display name as fallback
        _nameController.text =
            AuthService.instance.displayName ?? 'Player';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a display name';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (trimmed.length > 20) {
      return 'Name must be 20 characters or less';
    }

    // Check for forbidden words
    final lowerName = trimmed.toLowerCase();
    for (final word in _forbiddenWords) {
      if (lowerName.contains(word)) {
        return 'This name contains a reserved word';
      }
    }

    return null;
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final success = await AuthService.instance.updateDisplayName(
        _nameController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Display name updated!'),
              backgroundColor: GameColors.primary,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update display name'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: GameColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: GameColors.primary,
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: GameColors.primary.withOpacity(0.5),
                    backgroundImage: AuthService.instance.photoUrl != null
                        ? NetworkImage(AuthService.instance.photoUrl!)
                        : null,
                    child: AuthService.instance.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: GameColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Profile photo from Google account',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Display name field
            const Text(
              'DISPLAY NAME',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              validator: _validateName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your display name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: GameColors.boardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: GameColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white38,
                  ),
                  onPressed: () => _nameController.clear(),
                ),
              ),
              maxLength: 20,
              buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength / $maxLength',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
            const Text(
              'This name will be shown in the rankings. 2-20 characters.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: GameColors.primary.withOpacity(0.5),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Account info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GameColors.boardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT INFO',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.email,
                        color: Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AuthService.instance.currentUser?.email ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 16,
                        height: 16,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata,
                          color: Colors.white38,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected with Google',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
