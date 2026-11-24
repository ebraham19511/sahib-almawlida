import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/generator_game.dart';
import 'game/state.dart';
import 'ui/hud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await GameState.load();
  runApp(GeneratorApp(gameState: state));
}

class GeneratorApp extends StatefulWidget {
  final GameState gameState;
  const GeneratorApp({super.key, required this.gameState});

  @override
  State<GeneratorApp> createState() => _GeneratorAppState();
}

class _GeneratorAppState extends State<GeneratorApp> with WidgetsBindingObserver {
  late final GeneratorGame game = GeneratorGame(widget.gameState);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      widget.gameState.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صاحب المولدة',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE8892B),
      ),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: game),
            GameHud(state: widget.gameState),
          ],
        ),
      ),
    );
  }
}
