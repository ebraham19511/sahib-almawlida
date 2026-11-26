import 'package:flutter/material.dart';

import '../game/music.dart';
import '../game/sound.dart';
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
                child: IgnorePointer(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 26),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _gold, width: 2)),
                      child: Column(children: [
                        Text('المرحلة ${wd.level + 1}: ${wd.cfg.title}',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _gold)),
                        const SizedBox(height: 8),
                        Text(wd.cfg.tip, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      wd.countdown > 0 ? '${wd.countdown.ceil()}' : 'يلا!',
                      style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900, color: Colors.white, shadows: [
                        Shadow(blurRadius: 20, color: Colors.black),
                      ]),
                    ),
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
                  bottom: 60,
                  child: IgnorePointer(child: Center(child: _Bubble(text: '👆 اسحب بأي مكان وامشِ\n⚡ اتبع الأسهم للبيت الطافي'))),
                ),
              if (wd.bannerT > 0 && wd.banner.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  top: Arena.topSpace + 34,
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(wd.banner),
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: _Bubble(text: wd.banner),
                      ),
                    ),
                  ),
                ),
              Positioned(right: 16, bottom: 34, child: _Actions(wd: wd)),
              if (wd.overloadOn && wd.nearGenerator)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 70,
                  child: Center(child: _CoolButton(onTap: wd.tapCool)),
                ),
            ]);
          case Phase.paused:
            return Stack(fit: StackFit.expand, children: [
              _Hud(wd: wd),
              _Dim(
                child: _Card(children: [
                  const Text('⏸️', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const _SoundToggles(),
                  const SizedBox(height: 12),
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
          const Align(alignment: AlignmentDirectional.topEnd, child: Padding(padding: EdgeInsets.all(8), child: _SoundToggles())),
          const Text('⚡', style: TextStyle(fontSize: 54)),
          const Text('صاحب المولدة',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _gold, shadows: [Shadow(blurRadius: 12, color: Colors.black)])),
          const SizedBox(height: 6),
          Text('⭐ ${wd.totalStars} / ${levels.length * 3}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
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
      color: open ? (levels[index].boss > 0 ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32)) : const Color(0xFF37474F),
      borderRadius: BorderRadius.circular(22),
      elevation: open ? 6 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: open ? () => wd.start(index) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            open
                ? Text(levels[index].boss > 0 ? '👹' : '${index + 1}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))
                : const Icon(Icons.lock_rounded, size: 26, color: Colors.white38),
            if (open)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(levels[index].title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white70)),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < 3; k++) Icon(Icons.star_rounded, size: 14, color: k < st ? _gold : Colors.white24),
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
                const SizedBox(width: 10),
                // صحة اللاعب
                const Text('💪', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 70,
                  height: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (wd.hp / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.black54,
                      color: wd.hp > 50 ? const Color(0xFF69F0AE) : (wd.hp > 25 ? const Color(0xFFFFB300) : const Color(0xFFFF1744)),
                    ),
                  ),
                ),
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
        Text(won ? 'عاشت إيدك! 🎉' : 'قريب! 💪', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        if (!won && wd.lostReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(wd.lostReason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: Colors.white70)),
          ),
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
        Text('⚡ ${wd.fixes}    👮 ${wd.caught}    👊 ${wd.beaten}', style: const TextStyle(fontSize: 20, color: Colors.white70)),
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

/// زر كبير للتبريد وقت الحمل الزائد
class _CoolButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CoolButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0288D1),
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
        elevation: 10,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {},
          onTapDown: (_) => onTap(),
          child: const Padding(
            padding: EdgeInsets.all(26),
            child: Text('❄️\nاضغط!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ),
      );
}

/// أزرار الفعل: ضربة، اركب/انزل
class _Actions extends StatelessWidget {
  final ArcadeWorld wd;
  const _Actions({required this.wd});

  @override
  Widget build(BuildContext context) {
    final showRide = wd.cfg.vehicle && (wd.riding || wd.nearTruck);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRide)
          _ActionBtn(
            label: wd.riding ? '🚶\nانزل' : '🚙\nاركب',
            color: const Color(0xFF43A047),
            onTap: wd.toggleRide,
          ),
        if (showRide && wd.canFight) const SizedBox(height: 12),
        if (wd.canFight && !wd.riding) _ActionBtn(label: '👊', color: const Color(0xFFD84315), onTap: wd.attack, big: true),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool big;
  const _ActionBtn({required this.label, required this.color, required this.onTap, this.big = false});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withAlpha(230),
        shape: const CircleBorder(side: BorderSide(color: Colors.white70, width: 2)),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {},
          onTapDown: (_) => onTap(),
          child: SizedBox(
            width: big ? 84 : 70,
            height: big ? 84 : 70,
            child: Center(
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: big ? 38 : 15, fontWeight: FontWeight.w900, height: 1.1)),
            ),
          ),
        ),
      );
}

/// تشغيل/إطفاء الموسيقى والأصوات
class _SoundToggles extends StatefulWidget {
  const _SoundToggles();

  @override
  State<_SoundToggles> createState() => _SoundTogglesState();
}

class _SoundTogglesState extends State<_SoundToggles> {
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Round(
            icon: Music.enabled ? Icons.music_note_rounded : Icons.music_off_rounded,
            onTap: () {
              Music.setEnabled(!Music.enabled);
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _Round(
            icon: Sfx.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            onTap: () {
              Sfx.enabled = !Sfx.enabled;
              setState(() {});
            },
          ),
        ],
      );
}
