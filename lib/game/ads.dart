import 'package:flutter/foundation.dart';

/// الإعلانات: موقوفة مؤقتاً (مكتبة AdMob چانت تطب اللعبة أول ما تنفتح).
/// نفس الأوامر موجودة حتى باقي اللعبة ما يتغير، بس ما تسوي شي هسه.
/// لما نرجّع الإعلانات نبدل هذا الملف بس.
class Ads {
  static final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  static Future<void> init() async {}

  static void showRewarded(VoidCallback onReward) {}

  static void betweenLevels() {}
}
