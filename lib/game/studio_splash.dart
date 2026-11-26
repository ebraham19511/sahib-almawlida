import 'package:flutter/material.dart';

/// شاشة شعار «ألعاب إبراهيم الربيعي».
/// ثابتة بكل لعبة: انسخ هذا الملف + assets/images/studio_logo.png للعبة الجديدة
/// وحط StudioSplash حوالين الشاشة الرئيسية.
class StudioSplash extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const StudioSplash({super.key, required this.child, this.duration = const Duration(milliseconds: 2600)});

  @override
  State<StudioSplash> createState() => _StudioSplashState();
}

class _StudioSplashState extends State<StudioSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          GestureDetector(
            onTap: () => setState(() => _done = true), // ضغطة تتخطى الشعار
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                // يظهر بأول 25%، يبقى، ويختفي بآخر 20%
                final fadeIn = (t / 0.25).clamp(0.0, 1.0);
                final fadeOut = ((1 - t) / 0.2).clamp(0.0, 1.0);
                final scale = 0.7 + 0.3 * Curves.elasticOut.transform(fadeIn);
                return Opacity(
                  opacity: fadeOut,
                  child: Container(
                    color: const Color(0xFF0B1020),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: fadeIn,
                      child: Transform.scale(
                        scale: scale,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Image.asset(
                            'assets/images/studio_logo.png',
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => const Text(
                              'TN',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFFFC107)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
