import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);

  static Route<T> route<T>(Widget child, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.035, 0.018), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class AppReveal extends StatefulWidget {
  const AppReveal({super.key, required this.child, this.delay = Duration.zero, this.offset = const Offset(0, .055)});
  final Widget child;
  final Duration delay;
  final Offset offset;
  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal> {
  bool visible = false;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => visible = true);
    });
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.slow,
      curve: Curves.easeOutCubic,
      opacity: visible ? 1 : 0,
      child: AnimatedSlide(
        duration: AppMotion.slow,
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : widget.offset,
        child: widget.child,
      ),
    );
  }
}

class BreathingGlow extends StatefulWidget {
  const BreathingGlow({super.key, required this.child});
  final Widget child;
  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(begin: .985, end: 1.015).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
    child: widget.child,
  );
}


class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.pressedScale = .982});
  final Widget child;
  final bool enabled;
  final double pressedScale;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool pressed = false;
  void setPressed(bool value) {
    if (!widget.enabled || pressed == value) return;
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => setPressed(false) : null,
      child: AnimatedScale(
        scale: pressed ? widget.pressedScale : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
