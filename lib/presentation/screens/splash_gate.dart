import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/recordings_provider.dart';
import '../widgets/animated_logo_mark.dart';
import 'home_screen.dart';

/// How long the equalizer runs before it is allowed to settle, so a warm start
/// still reads as an animation rather than a flicker.
const Duration _kMinPulse = Duration(milliseconds: 700);

/// Hard ceiling on waiting for the recordings list.
///
/// Deliberately an independent delay rather than `.timeout()` on the provider
/// future: a timeout would not cover the error path, and a plain delay is what
/// `pumpAndSettle` advances cleanly in tests. Without it the repeating pulse
/// controller would keep the test framework waiting forever.
const Duration _kMaxWait = Duration(milliseconds: 2000);

const double _kMarkWidth = 160;

/// The animated launch screen, shown over [HomeScreen] until startup settles.
///
/// [HomeScreen] is mounted from the first frame and the splash simply fades off
/// the top of it. That is not an implementation detail — it is the point.
/// `HomeScreen` registers `ref.listen` on `recoveredCountProvider`, and
/// `ref.listen` only fires on *change*; if a splash owned the screen first and
/// prefetched the recordings, that provider would already hold its value by the
/// time the listener existed and the interrupted-recording SnackBar would
/// silently never appear.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with TickerProviderStateMixin {
  /// Free-running clock for the equalizer.
  late final AnimationController _pulse;

  /// 0 = the logo exactly as the native launch screen drew it, 1 = equalizer.
  late final AnimationController _blend;

  /// Title fade-in. Separate from [_finish] so the name is readable for the
  /// whole hold rather than flashing during the outro.
  late final AnimationController _intro;

  /// Settle and fade out.
  late final AnimationController _finish;

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _blend = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _finish = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    // Frame 0 is the resting logo; only now does it come alive.
    _blend.forward();
    _intro.forward();

    _finish.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _pulse.stop();
        setState(() => _done = true);
      }
    });

    unawaited(_awaitStartup());
  }

  Future<void> _awaitStartup() async {
    await Future.wait([
      Future<void>.delayed(_kMinPulse),
      Future.any([
        // catchError is not optional. RecordingsNotifier.build() reaches
        // path_provider, whose channel is unmocked in widget tests, and a
        // transient disk error in production would otherwise strand the user
        // on the splash forever.
        ref
            .read(recordingsProvider.future)
            .then<void>((_) {})
            .catchError((Object _) {}),
        Future<void>.delayed(_kMaxWait),
      ]),
    ]);
    if (!mounted) return;
    _blend.reverse();
    _finish.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _blend.dispose();
    _intro.dispose();
    _finish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Stack stays even once the splash is gone. Returning a bare
    // HomeScreen instead would change the child's widget type at this slot,
    // and Flutter would tear the whole subtree down and remount HomeScreen —
    // losing its state and re-running its init at the exact moment the user
    // first sees it. Dropping only the overlay keeps HomeScreen's element,
    // which is the entire reason it is mounted from frame 0.
    return Stack(
      children: [
        const HomeScreen(),
        if (!_done)
          Positioned.fill(
          // Absorb rather than ignore: a tap during the splash must not reach
          // the record button underneath.
          child: AbsorbPointer(
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                CurvedAnimation(
                  parent: _finish,
                  // Starts once the bars have settled back into the logo.
                  curve: const Interval(0.55, 1, curve: Curves.easeIn),
                ),
              ),
              child: _SplashOverlay(
                pulse: _pulse,
                blend: _blend,
                intro: _intro,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay({
    required this.pulse,
    required this.blend,
    required this.intro,
  });

  final Animation<double> pulse;
  final Animation<double> blend;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final title = CurvedAnimation(parent: intro, curve: Curves.easeOut);

    // Material, not a bare ColoredBox: it supplies the DefaultTextStyle the
    // title inherits. Without one, Text falls back to Flutter's debug style and
    // renders monospace with a yellow underline.
    //
    // Still no Scaffold, AppBar or SafeArea, though — the mark has to land on
    // the *screen* centre, which is what LaunchScreen.storyboard centres its
    // image on, and any inset would offset it and break the handoff.
    return Material(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const markHeight = _kMarkWidth * AnimatedLogoMark.aspectRatio;
          final centreY = constraints.maxHeight / 2;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: centreY - markHeight / 2,
                height: markHeight,
                child: Center(
                  child: AnimatedLogoMark(
                    pulse: pulse,
                    blend: blend,
                    width: _kMarkWidth,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: centreY + markHeight / 2 + 28,
                child: FadeTransition(
                  opacity: title,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(title),
                    child: Text(
                      AppLocalizations.of(context)!.appTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
