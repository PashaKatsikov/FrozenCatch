import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

/// First screen shown on cold start. It adapts to whichever orientation the
/// device happens to be in (both a vertical and a horizontal loading artwork
/// are bundled), while the progress bar always fills left-to-right and only
/// reaches 100% right before the game is actually handed off to the player.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  int _dotCount = 0;
  Timer? _dotTimer;
  bool _navigated = false;

  static const double _preLaunchCap = 0.93;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
    _runLoadingSequence();
  }

  Future<void> _runLoadingSequence() async {
    final stopwatch = Stopwatch()..start();
    const minimumDuration = Duration(milliseconds: 2400);

    final precacheFuture = _precacheAssets();
    await _animateProgressTo(_preLaunchCap, const Duration(milliseconds: 2000));

    final elapsed = stopwatch.elapsed;
    if (elapsed < minimumDuration) {
      await Future.delayed(minimumDuration - elapsed);
    }
    await precacheFuture;

    // Only now, immediately before the game actually launches, do we fill
    // the bar the rest of the way.
    await _animateProgressTo(1.0, const Duration(milliseconds: 320));
    await Future.delayed(const Duration(milliseconds: 180));
    _goToGame();
  }

  Future<void> _precacheAssets() async {
    final assets = <String>[
      AppAssets.gameLogo,
      AppAssets.bgAurora,
      AppAssets.bgNorthernLights,
      AppAssets.bgSnowValley,
      AppAssets.fishermanSeated,
      AppAssets.fishermanAgedSeated,
      AppAssets.fisherFemaleSeated,
      AppAssets.fishermanStanding,
      AppAssets.fishermanAgedStanding,
      AppAssets.fisherFemaleStanding,
      ...AppAssets.fish,
    ];
    if (!mounted) return;
    try {
      await Future.wait(
        assets.map((a) => precacheImage(AssetImage(a), context)),
      );
    } catch (_) {
      // Precaching best-effort only; never block the game on a decode error.
    }
  }

  Future<void> _animateProgressTo(double target, Duration duration) async {
    final completer = Completer<void>();
    final start = _progress;
    final startTime = DateTime.now();
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      final t = DateTime.now().difference(startTime).inMilliseconds /
          duration.inMilliseconds;
      if (t >= 1.0) {
        setState(() => _progress = target);
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      } else {
        final eased = Curves.easeOutCubic.transform(t);
        setState(() => _progress = start + (target - start) * eased);
      }
    });
    return completer.future;
  }

  void _goToGame() {
    if (_navigated) return;
    _navigated = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, anim, _) => FadeTransition(
          opacity: anim,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final asset =
        isLandscape ? AppAssets.loadingHorizontal : AppAssets.loadingVertical;

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.10,
                  vertical: size.height * (isLandscape ? 0.06 : 0.08),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingLabel(dotCount: _dotCount),
                    const SizedBox(height: 14),
                    _ProgressBar(progress: _progress),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  const _LoadingLabel({required this.dotCount});

  final int dotCount;

  @override
  Widget build(BuildContext context) {
    final dots = '.' * dotCount;
    final padding = '.' * (3 - dotCount);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Loading'),
          TextSpan(text: dots),
          TextSpan(
            text: padding,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 18,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
