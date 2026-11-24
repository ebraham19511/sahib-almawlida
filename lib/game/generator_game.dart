import 'dart:ui';

import 'package:flame/game.dart';

import 'scene.dart';
import 'state.dart';

class GeneratorGame extends FlameGame {
  final GameState state;
  GeneratorGame(this.state);

  @override
  Future<void> onLoad() async {
    add(AlleyScene(state));
  }

  @override
  void update(double dt) {
    super.update(dt);
    state.tick(dt);
  }

  @override
  Color backgroundColor() => const Color(0xFF0E1A33);
}
