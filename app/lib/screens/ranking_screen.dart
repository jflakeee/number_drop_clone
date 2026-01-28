import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/ranking_entry.dart';
import '../services/auth_service.dart';
import '../services/ranking_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/ranking_list.dart';
import '../widgets/my_rank_card.dart';
import 'profile_edit_screen.dart';

/// Ranking screen with tabs for All, Daily, Weekly rankings
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<RankingType> _rankingTypes = [
    RankingType.all,
    RankingType.daily,
    RankingType.weekly,
  ];

  RankingEntry? _myRanking;
  int? _myRankPosition;
  bool _isLoadingMyRank = true;
  bool _hasPendingScores = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMyRanking();
    _checkPendingScores();

    // Listen to auth state changes
    AuthService.instance.authStateChanges.listen((user) {
      if (mounted) {
        _loadMyRanking();
        _checkPendingScores();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadMyRanking();
    }
  }

  Future<void> _loadMyRanking() async {
    if (!AuthService.instance.isSignedIn) {
      setState(() {
        _myRanking = null;
        _myRankPosition = null;
        _isLoadingMyRank = false;
      });
      return;
    }

    setState(() => _isLoadingMyRank = true);

    try {
      final ranking = await RankingService.instance.getMyRanking();
      final position = await RankingService.instance.getMyRankPosition(
        type: _rankingTypes[_tabController.index],
      );

      if (mounted) {
        setState(() {
          _myRanking = ranking;
          _myRankPosition = position;
          _isLoadingMyRank = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMyRank = false;
        });
      }
    }
  }

  Future<void> _checkPendingScores() async {
    final hasPending = await OfflineQueueService.instance.hasPendingScores();
    if (mounted) {
      setState(() => _hasPendingScores = hasPending);
    }
  }

  Future<void> _submitPendingScores() async {
    final submitted =
        await OfflineQueueService.instance.submitPendingScores();
    if (submitted > 0) {
      await _loadMyRanking();
      await _checkPendingScores();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$submitted pending score(s) submitted!'),
            backgroundColor: GameColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null && mounted) {
      await _loadMyRanking();
      await _submitPendingScores();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed in as ${user.displayName ?? user.email}!',
          ),
          backgroundColor: GameColors.primary,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      await _loadMyRanking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out. Using guest account.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {});
    }
  }

  void _navigateToProfileEdit() {
    if (!AuthService.instance.isGoogleSignedIn) {
      _showGoogleSignInRequiredDialog();
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
        )
        .then((_) => _loadMyRanking());
  }

  void _showGoogleSignInRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.boardBackground,
        title: const Text(
          'Google Sign-In Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sign in with Google to customize your display name.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _handleGoogleSignIn();
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
  Widget build(BuildContext context) {
    final isGoogleSignedIn = AuthService.instance.isGoogleSignedIn;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: GameColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RANKING',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasPendingScores)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.white70),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: _submitPendingScores,
              tooltip: 'Submit pending scores',
            ),
          // Show Google sign-in button if anonymous
          if (!isGoogleSignedIn)
            IconButton(
              icon: const Icon(Icons.g_mobiledata, color: Colors.white70),
              onPressed: _handleGoogleSignIn,
              tooltip: 'Sign in with Google',
            ),
          // Show sign-out button if signed in with Google
          if (isGoogleSignedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white70),
              onPressed: _handleSignOut,
              tooltip: 'Sign out',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GameColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'DAILY'),
            Tab(text: 'WEEKLY'),
          ],
        ),
      ),
      body: Column(
        children: [
          // My rank card
          MyRankCard(
            myRanking: _myRanking,
            rankPosition: _myRankPosition,
            isLoading: _isLoadingMyRank,
            isAnonymous: !isGoogleSignedIn,
            onSignIn: _handleGoogleSignIn,
            onProfileEdit: _navigateToProfileEdit,
          ),

          // Rankings list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _rankingTypes.map((type) {
                return _RankingTab(
                  rankingType: type,
                  onRefresh: _loadMyRanking,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTab extends StatelessWidget {
  final RankingType rankingType;
  final VoidCallback onRefresh;

  const _RankingTab({
    required this.rankingType,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RankingEntry>>(
      stream: RankingService.instance.getRankingsStream(
        type: rankingType,
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RankingList(
            rankings: [],
            isLoading: true,
          );
        }

        if (snapshot.hasError) {
          return RankingList(
            rankings: [],
            errorMessage: 'Failed to load rankings.\n${snapshot.error}',
            onRetry: onRefresh,
          );
        }

        final rankings = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: GameColors.primary,
          child: RankingList(rankings: rankings),
        );
      },
    );
  }
}
