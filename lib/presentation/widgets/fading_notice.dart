import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/app_theme.dart';

/// Briefly show a card over the screen, then fade it away.
///
/// For confirming a change the user just made, where a SnackBar is the wrong
/// shape: it would sit on top of the record bar — the very control being
/// operated — and linger with a dismiss affordance nobody needs. This appears
/// over the middle of the screen, says what happened, and leaves.
///
/// Never blocks input: unlike the splash overlay, which absorbs taps
/// deliberately, this one is transparent to them, so a second tap on the same
/// control lands while the first notice is still fading.
void showFadingNotice(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // A quick double-toggle replaces the notice rather than stacking two.
  _current?.dismiss();

  final entry = _NoticeHandle();
  entry.insert(overlay, icon: icon, title: title, subtitle: subtitle);
  _current = entry;
}

/// The notice currently on screen, if any. Module-level because the point is to
/// have at most one, whoever asked for it.
_NoticeHandle? _current;

class _NoticeHandle {
  OverlayEntry? _entry;

  /// Set by the card while it is on screen, so a newer notice can ask this one
  /// to leave. A plain callback rather than a listenable: there is exactly one
  /// listener, and its lifetime is the card's.
  VoidCallback? onDismissRequest;

  void insert(
    OverlayState overlay, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    _entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: _FadingNoticeCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          handle: this,
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  /// Ask the card to fade out now. It removes itself when it gets there.
  void dismiss() => onDismissRequest?.call();

  void remove() {
    _entry?.remove();
    _entry = null;
    onDismissRequest = null;
    if (identical(_current, this)) _current = null;
  }
}

class _FadingNoticeCard extends StatefulWidget {
  const _FadingNoticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.handle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Owns the overlay entry this card lives in.
  final _NoticeHandle handle;

  @override
  State<_FadingNoticeCard> createState() => _FadingNoticeCardState();
}

class _FadingNoticeCardState extends State<_FadingNoticeCard>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeIn = Duration(milliseconds: 180);
  static const Duration _hold = Duration(milliseconds: 1100);
  static const Duration _fadeOut = Duration(milliseconds: 260);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _fadeIn,
    reverseDuration: _fadeOut,
  );

  /// Cancellable so a disposed notice leaves nothing pending behind it — a
  /// bare `Future.delayed` would keep firing into a dead widget.
  Timer? _holdTimer;

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    widget.handle.onDismissRequest = _leave;
    _controller.forward().then((_) {
      if (!mounted) return;
      _holdTimer = Timer(_hold, _leave);
    });
  }

  /// Start the fade out. Safe to call more than once, and after disposal.
  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _holdTimer?.cancel();
    _holdTimer = null;
    await _controller.reverse();
    if (!mounted) return;
    // Removing the entry during a build or a layout pass would throw, and this
    // can land inside the frame that the animation ends on.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.handle.remove());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    widget.handle.onDismissRequest = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    return Center(
      child: FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          // A small rise rather than a pop: the card should read as confirming
          // something, not as demanding attention.
          scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 32, color: colors.accent),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
