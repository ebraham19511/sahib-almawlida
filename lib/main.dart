import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcade/game.dart';
import 'arcade/ui.dart';
import 'arcade/world.dart';
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
  await wd.loadProgress();
  runApp(ArcadeApp(wd: wd));
}

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
            ],
          ),
        ),
      ),
    );
  }
}
