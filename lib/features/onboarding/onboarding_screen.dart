import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';
import 'illustrations.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  /// When true, the screen is being replayed from the account sheet — it
  /// pops on completion instead of pushing into `RoleSelectionScreen` and
  /// does not flip the onboarding-completed flag.
  final bool replay;

  const OnboardingScreen({super.key, this.replay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_PageData> _buildPages(AppLocalizations l) => [
        _PageData(
          scene: OnboardingScene.route,
          accent: AppColors.primary,
          title: l.onboardTitle1,
          subtitle: l.onboardSubtitle1,
        ),
        _PageData(
          scene: OnboardingScene.matching,
          accent: AppColors.teal,
          title: l.onboardTitle2,
          subtitle: l.onboardSubtitle2,
        ),
        _PageData(
          scene: OnboardingScene.co2,
          accent: const Color(0xFFFFD166),
          title: l.onboardTitle3,
          subtitle: l.onboardSubtitle3,
        ),
        _PageData(
          scene: OnboardingScene.pickupCode,
          accent: const Color(0xFF7C3AED),
          title: l.onboardTitle4,
          subtitle: l.onboardSubtitle4,
        ),
      ];

  static const int _pageCount = 4;

  Future<void> _finishOnboarding() async {
    if (!widget.replay) {
      await TokenStorage().markOnboardingCompleted();
    }
    if (!mounted) return;
    if (widget.replay) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    }
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pages = _buildPages(l);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 24),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    l.skip,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: _page == pages.length - 1
                        ? FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(58),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                l.getStarted,
                                key: const ValueKey('get-started'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : FilledButton.tonal(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(58),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                l.continueLabel,
                                key: const ValueKey('continue'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
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

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OnboardingArt(scene: data.scene, accent: data.accent),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final OnboardingScene scene;
  final Color accent;
  final String title;
  final String subtitle;
  const _PageData({
    required this.scene,
    required this.accent,
    required this.title,
    required this.subtitle,
  });
}
