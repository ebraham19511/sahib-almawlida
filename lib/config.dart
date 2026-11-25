/// إعدادات الاتصال بـ Supabase (للمحادثة بالذكاء الاصطناعي)
/// انسخ القيم من Supabase: Project Settings ← API
class AppConfig {
  static const supabaseUrl = ''; // مثال: https://abcdxyz.supabase.co
  static const supabaseAnonKey = ''; // anon public key

  static bool get aiEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
