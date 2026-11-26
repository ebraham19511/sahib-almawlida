import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcade/game.dart';
import 'arcade/ui.dart';
import 'arcade/world.dart';
import 'game/ads.dart';
import 'game/music.dart';
import 'game/sound.dart';
import 'game/studio_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final wd = ArcadeWorld();
  wd.onSfx = (n) => Sfx.play(n);
  wd.onMusic = (n) => Music.play(n);
  // أي خطأ يصير نعرضه بالشاشة بدل ما التطبيق يطب بصمت
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    lastError.value = d.exceptionAsString();
  };
  PlatformDispatcher.instance.onError = (e, s) {
    lastError.value = '$e';
    return true;
  };
  try {
    await wd.loadProgress();
  } catch (_) {}
  runApp(ArcadeApp(wd: wd));
  // الإعلانات تبدي بعد ما اللعبة تفتح، وإذا صار بيها خلل ما توگف اللعبة
  Timer(const Duration(seconds: 3), () {
    Ads.init().catchError((Object e) {
      lastError.value = 'Ads: $e';
    });
  });
}

final ValueNotifier<String?> lastError = ValueNotifier(null);

class ArcadeApp extends StatefulWidget {
  final ArcadeWorld wd;
  const ArcadeApp({super.key, required this.wd});

  @override
  State<ArcadeApp> createState() => _ArcadeAppState();
}

class _ArcadeAppState extends State<ArcadeApp> with WidgetsBindingObserver {
  late final ArcadeGame game = ArcadeGame(widget.wd);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Music.play('music_main');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) {
      widget.wd.pause();
      Music.pause();
    } else {
      Music.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صاحب المولدة',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFFFFC107)),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        body: StudioSplash(
          child: Stack(
            children: [
              GameWidget(game: game),
              ArcadeUI(wd: widget.wd),
              // شريط صغير يبين الخطأ (للتجربة)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: ValueListenableBuilder<String?>(
                  valueListenable: lastError,
                  builder: (_, e, __) => e == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => lastError.value = null,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: const Color(0xDDB71C1C),
                            child: Text('⚠️ $e', maxLines: 4, style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
