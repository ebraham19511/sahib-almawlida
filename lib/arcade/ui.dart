import 'package:flutter/material.dart';

import 'game.dart';
import 'world.dart';

const _gold = Color(0xFFFFC107);
const _panel = Color(0xEE152028);

/// كل الواجهات فوك اللعبة: القائمة، الأرقام، العد، الإيقاف، النتيجة
class ArcadeUI extends StatelessWidget {
  final ArcadeWorld wd;
  const ArcadeUI({super.key, required this.wd});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    Arena.topSpace = top + 78;
    return AnimatedBuilder(
      animation: wd,
      builder: (context, _) {
        switch (wd.phase) {
          case Phase.menu:
            return SizedBox.expand(child: _Menu(wd: wd));
          case Phase.countdown:
            return Stack(fit: StackFit.expand, children: [
              _Hud(wd: wd),
              Center(
                child: Text(
                  wd.countdown > 0 ? '${wd.countdown.ceil()}' : 'يلا!',
                  style: const TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: Colors.white, shadows: [
                    Shadow(blurRadius: 20, color: Colors.black),
                  ]),
                ),
              ),
            ]);
          case Phase.playing:
            return Stack(fit: StackFit.expand, children: [
              _Hud(wd: wd),
              if (wd.hintTime > 0)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: IgnorePointer(child: Center(child: _Bubble(text: '👆 اسحب بأي مكان وامشِ\n⚡ اركض للبيت الطافي'))),
                ),
            ]);
          case Phase.paused:
            return Stack(fit: StackFit.expand, children: [
              _Hud(wd: wd),
              _Dim(
                child: _Card(children: [
                  const Text('⏸️', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Big(icon: Icons.home_rounded, onTap: wd.toMenu),
                    const SizedBox(width: 14),
                    _Big(icon: Icons.replay_rounded, onTap: () => wd.start(wd.level)),
                    const SizedBox(width: 14),
                    _Big(icon: Icons.play_arrow_rounded, onTap: wd.resume, main: true),
                  ]),
                ]),
              ),
            ]);
          case Phase.won:
          case Phase.lost:
            return Stack(fit: StackFit.expand, children: [_Hud(wd: wd), _Result(wd: wd)]);
        }
        // ignore: dead_code
        return const SizedBox.shrink();
      },
    );
  }
}

// ---------------- القائمة ----------------
class _Menu extends StatelessWidget {
  final ArcadeWorld wd;
  const _Menu({required this.wd});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text('⚡', style: TextStyle(fontSize: 64)),
          const Text('صاحب المولدة',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _gold, shadows: [Shadow(blurRadius: 12, color: Colors.black)])),
          const SizedBox(height: 6),
          Text('⭐ ${wd.totalStars} / ${levels.length * 3}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 26),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                for (var i = 0; i < levels.length; i++) _LevelButton(wd: wd, index: i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final ArcadeWorld wd;
  final int index;
  const _LevelButton({required this.wd, required this.index});

  @override
  Widget build(BuildContext context) {
    final open = wd.unlocked(index);
    final st = wd.stars[index];
    return Material(
      color: open ? const Color(0xFF2E7D32) : const Color(0xFF37474F),
      borderRadius: BorderRadius.circular(22),
      elevation: open ? 6 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: open ? () => wd.start(index) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            open
                ? Text('${index + 1}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))
                : const Icon(Icons.lock_rounded, size: 34, color: Colors.white38),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < 3; k++) Icon(Icons.star_rounded, size: 20, color: k < st ? _gold : Colors.white24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- الأرقام فوك ----------------
class _Hud extends StatelessWidget {
  final ArcadeWorld wd;
  const _Hud({required this.wd});

  @override
  Widget build(BuildContext context) {
    final low = wd.timeLeft <= 10;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Round(icon: Icons.pause_rounded, onTap: wd.pause),
                const SizedBox(width: 8),
                Text('❤️' * wd.hearts + '🖤' * (3 - wd.hearts), style: const TextStyle(fontSize: 20)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: low ? const Color(0xFFD32F2F) : _panel, borderRadius: BorderRadius.circular(16)),
                  child: Text('⏱ ${wd.timeLeft.ceil()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
                  child: Text('⭐ ${wd.score}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _gold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('المرحلة ${wd.level + 1}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const Spacer(),
                if (wd.combo > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFF6F00), borderRadius: BorderRadius.circular(12)),
                    child: Text('🔥 ×${wd.combo}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  ),
                const SizedBox(width: 8),
                // أهداف النجوم
                for (var k = 0; k < 3; k++)
                  Icon(Icons.star_rounded, size: 18, color: wd.score >= wd.cfg.stars[k] ? _gold : Colors.white24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- النتيجة ----------------
class _Result extends StatelessWidget {
  final ArcadeWorld wd;
  const _Result({required this.wd});

  @override
  Widget build(BuildContext context) {
    final won = wd.phase == Phase.won;
    final hasNext = wd.level + 1 < levels.length && wd.unlocked(wd.level + 1);
    return _Dim(
      child: _Card(children: [
        Text(won ? 'عاشت إيدك! 🎉' : (wd.hearts <= 0 ? 'الناس زعلت 😡' : 'قريب! 💪'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < 3; k++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + k * 300),
                curve: Curves.elasticOut,
                builder: (_, v, __) => Transform.scale(
                  scale: k < wd.lastStars ? v : 1,
                  child: Icon(Icons.star_rounded, size: k == 1 ? 76 : 60, color: k < wd.lastStars ? _gold : Colors.white24),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('⭐ ${wd.score}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _gold)),
        if (wd.newBest) const Text('🏆 رقم قياسي!', style: TextStyle(fontSize: 18, color: Color(0xFF69F0AE))),
        const SizedBox(height: 6),
        Text('⚡ ${wd.fixes}    👮 ${wd.caught}', style: const TextStyle(fontSize: 20, color: Colors.white70)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Big(icon: Icons.home_rounded, onTap: wd.toMenu),
          const SizedBox(width: 14),
          _Big(icon: Icons.replay_rounded, onTap: () => wd.start(wd.level), main: !hasNext),
          if (hasNext) ...[
            const SizedBox(width: 14),
            _Big(icon: Icons.skip_next_rounded, onTap: () => wd.start(wd.level + 1), main: true),
          ],
        ]),
      ]),
    );
  }
}

// ---------------- قطع صغيرة ----------------
class _Dim extends StatelessWidget {
  final Widget child;
  const _Dim({required this.child});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xAA000000),
          child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
        ),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2833),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _gold, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
}

class _Big extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool main;
  const _Big({required this.icon, required this.onTap, this.main = false});

  @override
  Widget build(BuildContext context) => Material(
        color: main ? const Color(0xFF43A047) : const Color(0xFF37474F),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(main ? 20 : 16), child: Icon(icon, size: main ? 40 : 32)),
        ),
      );
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _panel,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 24)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );
}
