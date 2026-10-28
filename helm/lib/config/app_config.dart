/// Build-time configuration for the whole app.
///
/// Every value is injected with `--dart-define` (or
/// `--dart-define-from-file=.env` for local development). **No configuration
/// is read from a bundled asset**, so nothing here can leak through
/// `build/web/assets/` the way the old `.env` asset did.
///
/// Only the Supabase *publishable* key belongs in a client build: it is public
/// by design and constrained by Row-Level Security. The Gemini API key is a real
/// secret and is never read by this app — AI requests go through the `ai` Edge
/// Function, which holds the key server-side.
class AppConfig {
  const AppConfig._();

  // Public values, used as defaults so a plain `flutter run` works with no
  // flags. Override per environment with --dart-define when needed.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eknzdxexfcfdmqvbyvxt.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_fUoY96CXli7DwbZayu8pFQ_4yExvoJg',
  );

  /// Name of the Edge Function that proxies Gemini
  /// (`supabase/functions/ai`).
  static const String aiFunctionName = String.fromEnvironment(
    'AI_FUNCTION_NAME',
    defaultValue: 'ai',
  );

  /// A `GEMINI_API_KEY` define is deliberately **not** wired to anything. If an
  /// old build script still passes it, it has no effect — there is no
  /// client-side path to Google's API anymore.
  static const String legacyGeminiDefineName = 'GEMINI_API_KEY';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Shown when the build is missing configuration, instead of a blank screen.
  static const String misconfiguredMessage = 'Helm is missing its Supabase configuration.\n\n'
      'Run it with:\n'
      'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n\n'
      'or with a dart-define file:\n'
      'flutter run --dart-define-from-file=.env';
}
