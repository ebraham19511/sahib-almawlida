import 'package:flutter/material.dart';

import '../game/ads.dart';
import '../game/music.dart';
import '../game/sound.dart';
import 'game.dart';
import 'progress.dart';
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

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final next = wd.nextLevel;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _Chip(text: '⭐ ${wd.totalStars}'),
              const SizedBox(width: 8),
              _Chip(text: '🪙 ${wd.coins}', color: _gold),
              const Spacer(),
              _Round(icon: Icons.settings_rounded, onTap: () => _push(context, SettingsPage(wd: wd))),
            ]),
          ),
          const Spacer(),
          const GameLogo(),
          const SizedBox(height: 10),
          Text('المرحلة ${next + 1}: ${levels[next].title}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 14),
          _PlayButton(onTap: () => wd.start(next)),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Expanded(child: _MenuTile(icon: '🗺️', label: 'المراحل', onTap: () => _push(context, LevelsPage(wd: wd)))),
              const SizedBox(width: 12),
              Expanded(
                child: _MenuTile(icon: '🎯', label: 'المهام', badge: wd.missions.readyCount, onTap: () => _push(context, MissionsPage(wd: wd))),
              ),
              const SizedBox(width: 12),
              Expanded(child: _MenuTile(icon: '🛒', label: 'المتجر', onTap: () => _push(context, ShopPage(wd: wd)))),
            ]),
          ),
          const Spacer(flex: 2),
          const Text('TN', style: TextStyle(fontSize: 14, color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xCC0B1020), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Text(text, style: TextStyle(fontSize: 17, color: color, fontWeight: FontWeight.w900)),
      );
}

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: 1 + _c.value * 0.05, child: child),
        child: Material(
          color: const Color(0xFF2E7D32),
          shape: const StadiumBorder(side: BorderSide(color: _gold, width: 3)),
          elevation: 12,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 56, vertical: 16),
              child: Text('▶  العب', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  final String icon;
  final String label;
  final int badge;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          elevation: 6,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(icon, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ),
        if (badge > 0)
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: Color(0xFFFF1744), shape: BoxShape.circle),
              child: Text('$badge', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ),
          ),
      ]);
}

/// صفحة بخلفية غامقة وعنوان (للمراحل والمهام والإعدادات والمتجر)
class _Page extends StatelessWidget {
  final String title;
  final ArcadeWorld wd;
  final Widget Function(BuildContext) body;
  final PreferredSizeWidget? bottom;
  const _Page({required this.title, required this.wd, required this.body, this.bottom});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF101820),
          appBar: AppBar(
            backgroundColor: const Color(0xFF101820),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            bottom: bottom,
            actions: [
              AnimatedBuilder(
                animation: wd,
                builder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text('🪙 ${wd.coins}', style: const TextStyle(fontSize: 20, color: _gold, fontWeight: FontWeight.w900))),
                ),
              ),
            ],
          ),
          body: AnimatedBuilder(animation: wd, builder: (context, _) => body(context)),
        ),
      );
}

class LevelsPage extends StatelessWidget {
  final ArcadeWorld wd;
  const LevelsPage({super.key, required this.wd});

  @override
  Widget build(BuildContext context) => _Page(
        title: '🗺️ المراحل  ⭐ ${wd.totalStars}/${levels.length * 3}',
        wd: wd,
        body: (context) => GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (var i = 0; i < levels.length; i++)
              _LevelButton(
                wd: wd,
                index: i,
                onPlay: () {
                  Navigator.of(context).pop();
                  wd.start(i);
                },
              ),
          ],
        ),
      );
}

class MissionsPage extends StatelessWidget {
  final ArcadeWorld wd;
  const MissionsPage({super.key, required this.wd});

  @override
  Widget build(BuildContext context) => _Page(
        title: '🎯 المهام اليومية',
        wd: wd,
        body: (context) {
          final ms = wd.missions;
          return ListView(padding: const EdgeInsets.all(16), children: [
            // مكافأة الدخول اليومي
            Card(
              color: const Color(0xFF4A148C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('🎁', style: TextStyle(fontSize: 44)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('هدية اليوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      Text(ms.loginClaimedToday ? 'رجع باچر وخذ أكثر! (أيام ورا بعض: ${ms.streak})' : 'كل ما تدخل أيام ورا بعض الهدية تكبر',
                          style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ]),
                  ),
                  ms.loginClaimedToday
                      ? const Text('✅', style: TextStyle(fontSize: 28))
                      : FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                          onPressed: wd.claimLogin,
                          child: const Text('استلم', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            const Text('مهام اليوم (تتجدد كل يوم):', style: TextStyle(fontSize: 15, color: Colors.white70)),
            const SizedBox(height: 8),
            for (var i = 0; i < ms.list.length; i++) _missionTile(ms.list[i], i),
          ]);
        },
      );

  Widget _missionTile(Mission m, int i) => Card(
        color: _panel,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text(m.type.icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (m.prog / m.goal).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    color: m.done ? const Color(0xFF69F0AE) : _gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${m.prog} / ${m.goal}   •   🪙 ${m.reward}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            const SizedBox(width: 8),
            m.claimed
                ? const Text('✅', style: TextStyle(fontSize: 26))
                : FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: m.done ? const Color(0xFF2E7D32) : Colors.white12),
                    onPressed: m.done ? () => wd.claimMission(i) : null,
                    child: const Text('استلم', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ]),
        ),
      );
}

class SettingsPage extends StatelessWidget {
  final ArcadeWorld wd;
  const SettingsPage({super.key, required this.wd});

  static const _how = [
    ['⚡', 'البيت الطافي عليه دائرة. اركضله قبل ما يخلص وكته وترجع الكهرباء.'],
    ['👆', 'اسحب بأي مكان بالشاشة حتى تمشي. اسحب لآخرها وكمّل حتى تركض.'],
    ['🚙', 'سيارة الشغل: أسرع، وتملي التانكر ⛽ من المحطة وتوديه للمولدة.'],
    ['🚁', 'الهليكوبتر: حوم فوگ البيت الطافي وتصلحه من الجو. انتبه لوقودها.'],
    ['⛽', 'إذا خلص كاز المولدة البيوت ما تتصلح. لمّ الجليكانات.'],
    ['🦹', 'الحرامي يگص الواير ويهرب. الحگه أو اضربه 👊.'],
    ['👹', 'الزعيم: اطلع من الدائرة الحمرة قبل ما يضرب، واغلبه قبل ما يخلص الوكت.'],
    ['🔥', 'إذا المولدة سخنت اركضلها واضغط ❄️ بسرعة.'],
    ['💧', 'المي المكهربة تشرّر. لا تدوس عليها وهي صفرة أو زرگة.'],
    ['🪙', 'الفلوس تشتري بيها ترقيات وأشكال من المتجر.'],
  ];

  @override
  Widget build(BuildContext context) => _Page(
        title: '⚙️ الإعدادات',
        wd: wd,
        body: (context) => ListView(padding: const EdgeInsets.all(16), children: [
          const Text('الصوت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _gold)),
          const SizedBox(height: 8),
          const Center(child: _SoundToggles()),
          const SizedBox(height: 22),
          const Text('شلون تلعب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _gold)),
          const SizedBox(height: 8),
          for (final h in _how)
            Card(
              color: _panel,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(h[0], style: const TextStyle(fontSize: 28)),
                title: Text(h[1], style: const TextStyle(fontSize: 15)),
              ),
            ),
          const SizedBox(height: 20),
          const Center(child: Text('صاحب المولدة • TN', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
        ]),
      );
}

class _LevelButton extends StatelessWidget {
  final ArcadeWorld wd;
  final int index;
  final VoidCallback onPlay;
  const _LevelButton({required this.wd, required this.index, required this.onPlay});

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
        onTap: open ? onPlay : null,
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
                      value: (wd.hp / wd.maxHp).clamp(0.0, 1.0),
                      backgroundColor: Colors.black54,
                      color: wd.hp > wd.maxHp * 0.5 ? const Color(0xFF69F0AE) : (wd.hp > wd.maxHp * 0.25 ? const Color(0xFFFFB300) : const Color(0xFFFF1744)),
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
        if (wd.lastCoins > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('🪙 +${wd.lastCoins}', style: const TextStyle(fontSize: 22, color: _gold, fontWeight: FontWeight.w900)),
          ),
        const SizedBox(height: 6),
        Text('⚡ ${wd.fixes}    👮 ${wd.caught}    👊 ${wd.beaten}', style: const TextStyle(fontSize: 20, color: Colors.white70)),
        // أزرار الإعلانات بمكافأة (تطلع بس إذا الإعلان جاهز)
        ValueListenableBuilder<bool>(
          valueListenable: Ads.rewardedReady,
          builder: (_, ready, __) {
            if (!ready) return const SizedBox(height: 18);
            if (wd.canRevive) {
              return _AdButton(label: '🎬 شوف إعلان وكمّل ❤️', onTap: () => Ads.showRewarded(wd.revive));
            }
            if (!wd.doubled && wd.lastCoins > 0) {
              return _AdButton(label: '🎬 شوف إعلان وضاعف 🪙', onTap: () => Ads.showRewarded(wd.doubleCoins));
            }
            return const SizedBox(height: 18);
          },
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Big(
              icon: Icons.home_rounded,
              onTap: () {
                Ads.betweenLevels();
                wd.toMenu();
              }),
          const SizedBox(width: 14),
          _Big(
              icon: Icons.replay_rounded,
              onTap: () {
                Ads.betweenLevels();
                wd.start(wd.level);
              },
              main: !hasNext),
          if (hasNext) ...[
            const SizedBox(width: 14),
            _Big(
                icon: Icons.skip_next_rounded,
                onTap: () {
                  Ads.betweenLevels();
                  wd.start(wd.level + 1);
                },
                main: true),
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
    final showRide = wd.cfg.vehicle && (wd.riding || wd.nearTruck || wd.nearHeli);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRide)
          _ActionBtn(
            label: wd.flying ? '🛬\nانزل' : (wd.riding ? '🚶\nانزل' : (wd.nearHeli ? '🚁\nطير' : '🚙\nاركب')),
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

/// المتجر: تشتري بفلوس اللعبة (🪙) اللي تجمعها من المراحل
class ShopPage extends StatelessWidget {
  final ArcadeWorld wd;
  const ShopPage({super.key, required this.wd});

  static const _kinds = [
    ['hat', '🎩 القبعات'],
    ['trail', '✨ أثر المشي'],
    ['truck', '🚙 لون السيارة'],
    ['heli', '🚁 لون الهليكوبتر'],
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: _Page(
        title: '🛒 المتجر',
        wd: wd,
        bottom: const TabBar(
          indicatorColor: _gold,
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          tabs: [Tab(text: '💪 ترقيات'), Tab(text: '🎩 أشكال')],
        ),
        body: (context) => TabBarView(children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('تجمع 🪙 من المراحل والمهام اليومية.', style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 12),
              for (var i = 0; i < ArcadeWorld.shopNames.length; i++) _upgradeTile(context, i),
              _heartTile(context),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final k in _kinds) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(k[1], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _gold)),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final it in cosItems)
                      if (it.kind == k[0]) _cosTile(it),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  Widget _cosTile(CosItem it) {
    final owned = wd.cos.owned.contains(it.id);
    final on = wd.cos.equipped[it.kind] == it.id;
    final can = !owned && wd.coins >= it.cost;
    return SizedBox(
      width: 104,
      child: Material(
        color: on ? const Color(0xFF1B5E20) : _panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: owned ? () => wd.equipCos(it.id) : (can ? () => wd.buyCos(it.id) : null),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(children: [
              Text(it.icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 4),
              Text(it.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                on ? '✅ عليك' : (owned ? 'استعمل' : '🪙 ${it.cost}'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: on ? Colors.white : (owned || can ? _gold : Colors.white38)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _upgradeTile(BuildContext context, int i) {
    final cost = wd.upgCost(i);
    final lv = wd.upg[i];
    return Card(
      color: _panel,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Text(ArcadeWorld.shopIcons[i], style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ArcadeWorld.shopNames[i], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text(ArcadeWorld.shopDesc[i], style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 6),
              Row(children: [
                for (var k = 0; k < ArcadeWorld.upgCosts.length; k++)
                  Container(
                    width: 26,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(color: k < lv ? _gold : Colors.white24, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          cost == null
              ? const Text('✅ كامل', style: TextStyle(fontSize: 16, color: Color(0xFF69F0AE), fontWeight: FontWeight.bold))
              : FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: wd.coins >= cost ? const Color(0xFF2E7D32) : Colors.white12),
                  onPressed: wd.coins >= cost ? () => wd.buyUpg(i) : null,
                  child: Text('🪙 $cost', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
        ]),
      ),
    );
  }

  Widget _heartTile(BuildContext context) {
    final can = wd.coins >= ArcadeWorld.heartCost && wd.extraHearts < 5;
    return Card(
      color: _panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Text('❤️', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('قلب إضافي', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text('تبدي المرحلة الجاية بـ 4 قلوب بدل 3. عندك: ${wd.extraHearts}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: can ? const Color(0xFF2E7D32) : Colors.white12),
            onPressed: can ? wd.buyHeart : null,
            child: const Text('🪙 ${ArcadeWorld.heartCost}', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

/// شعار اللعبة: صاعقة بدائرة متوهجة + الاسم بتدرج ذهبي وحافة غامقة
class GameLogo extends StatefulWidget {
  const GameLogo({super.key});

  @override
  State<GameLogo> createState() => _GameLogoState();
}

class _GameLogoState extends State<GameLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'صاحب المولدة';
    const style = TextStyle(fontSize: 46, fontWeight: FontWeight.w900, height: 1.1);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFE65100)]),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: const Color(0xFFFFC107).withAlpha((120 + v * 120).round()), blurRadius: 18 + v * 22, spreadRadius: 2 + v * 4)],
            ),
            child: Transform.rotate(
              angle: (v - 0.5) * 0.2,
              child: const Icon(Icons.bolt_rounded, size: 64, color: Color(0xFF1A237E)),
            ),
          ),
          const SizedBox(height: 4),
          Stack(children: [
            Text(
              title,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 8
                  ..color = const Color(0xFF1A0E00),
              ),
            ),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8E1), Color(0xFFFFC107), Color(0xFFFF6F00)],
              ).createShader(r),
              child: const Text(title, style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, height: 1.1, color: Colors.white)),
            ),
          ]),
        ]);
      },
    );
  }
}

class _AdButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AdButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
      );
}
