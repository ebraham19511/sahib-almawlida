import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';

class NpcReply {
  final String text;
  final String action; // none, pay_debt, subscribe, buy_amps, happy, angry
  final bool fromAi;
  const NpcReply(this.text, this.action, this.fromAi);
}

/// المحادثة ويه صاحب البيت: ذكاء اصطناعي إذا أكو نت، وردود جاهزة إذا ماكو
class NpcChat {
  static final _rnd = Random();

  static String get aiLabel => AppConfig.aiEnabled ? '🤖 ذكاء اصطناعي' : '💬 ردود جاهزة';

  static Future<NpcReply> send({
    required Map<String, dynamic> context,
    required List<(bool, String)> history,
    required String message,
    required bool aiAllowed,
  }) async {
    if (AppConfig.aiEnabled && aiAllowed) {
      try {
        final res = await http
            .post(
              Uri.parse('${AppConfig.supabaseUrl}/functions/v1/npc-chat'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'apikey': AppConfig.supabaseAnonKey,
              },
              body: jsonEncode({
                'context': context,
                'history': [
                  for (final m in history.length > 10 ? history.sublist(history.length - 10) : history)
                    {'me': m.$1, 'text': m.$2}
                ],
                'message': message,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final text = (j['reply'] as String?)?.trim();
          if (text != null && text.isNotEmpty) {
            return NpcReply(text, (j['action'] as String?) ?? 'none', true);
          }
        }
      } catch (_) {
        // نرجع للردود الجاهزة
      }
    }
    return offline(context, message);
  }

  static String _pick(List<String> l) => l[_rnd.nextInt(l.length)];

  /// ردود جاهزة تفهم كلمات مفتاحية
  static NpcReply offline(Map<String, dynamic> ctx, String msg) {
    final m = msg.replaceAll('أ', 'ا').replaceAll('إ', 'ا');
    bool has(List<String> w) => w.any(m.contains);
    final debt = (ctx['debt'] as num?)?.toInt() ?? 0;
    final sub = ctx['subscribed'] == true;
    final price = (ctx['price'] as num?)?.toInt() ?? 15000;
    final maxP = (ctx['maxPrice'] as num?)?.toInt() ?? 15000;
    final lit = ctx['lit'] == true;

    if (has(['دين', 'فلوس', 'ادفع', 'تدفع', 'الحساب', 'عليك'])) {
      if (debt <= 0) return NpcReply('ما عليّ شي ابني، دفعت كلشي 🤲', 'none', false);
      if (_rnd.nextDouble() < 0.5) return NpcReply('زين ذكرتني، تفضل فلوسك 💵', 'pay_debt', false);
      return NpcReply(_pick(['والله الراتب بعده ما نزل', 'باچر أدزهن ويه الجاهل', 'اصبر عليّ كم يوم، العباس أنطيك']), 'none', false);
    }
    if (has(['اشترك', 'اشتراك', 'توصل', 'اوصلك', 'خط'])) {
      if (sub) return NpcReply('آني مشترك وياك أصلاً 😄', 'none', false);
      if (price > maxP) return NpcReply('سعرك غالي علينا، نزّله شوية وأشترك', 'none', false);
      return NpcReply('اتفقنا، وصّلني 🤝', 'subscribe', false);
    }
    if (has(['امبير', 'زياده', 'زيادة', 'مبردة', 'سبلت'])) {
      if (!sub) return NpcReply('بعدني ما مشترك وياك', 'none', false);
      if (_rnd.nextBool()) return NpcReply('زين، زيدني شوية، الصيف نار 🔥', 'buy_amps', false);
      return NpcReply('لا عيني يكفيني اللي عندي', 'none', false);
    }
    if (has(['سعر', 'غالي', 'رخيص'])) {
      return NpcReply(price > maxP ? 'إي والله غالي، الناس كلها تشتكي' : 'السعر مقبول، الله يخليك', 'none', false);
    }
    if (has(['كهرباء', 'طافية', 'طفت', 'ضوء', 'وطنية'])) {
      return NpcReply(lit ? 'الحمد لله هسه الكهرباء زينة 👍' : 'طافية! شنو القصة؟ شغّلها دخيلك 😠', lit ? 'happy' : 'angry', false);
    }
    if (has(['شلونك', 'شلونكم', 'هلا', 'سلام', 'مرحبا', 'صباح', 'مساء'])) {
      return NpcReply(_pick(['هلا بيك ابني، الحمد لله تمام', 'الله بالخير، تفضل اگعد ☕', 'هلا وغلا، نورت']), 'happy', false);
    }
    if (has(['شكرا', 'تسلم', 'الله يخليك'])) {
      return NpcReply('العفو ابني، إحنا أهل 🤍', 'happy', false);
    }
    if (has(['جاي', 'چاي', 'قهوة'])) {
      return NpcReply('هسه أگول للعيال يسوون جاي ☕', 'happy', false);
    }
    return NpcReply(
      _pick([
        'والله ما فهمت عليك ابني 😅',
        'إي إي... المهم لا تطفيها علينا',
        'الصيف هالسنة نار، دخيلك على الكهرباء',
        'هاي سالفة طويلة، خليها لبعدين',
      ]),
      'none',
      false,
    );
  }
}
