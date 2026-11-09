# REDUCE Codebase Configuration Notes

## Repository Overview
- **Repository Root**: `C:\Users\Lenovo\StudioProjects\EventsManager`
- **Main Languages**: Dart (Flutter client), TypeScript (Supabase Edge Functions), SQL (Database migrations/schemas)

## Tooling & Commands
- **Working Directory**: `helm/` (client codebase)
- **Package Manager**: `flutter pub`
- **Build Command**: `flutter build web --release --pwa-strategy=none`
- **Type Checking & Linting**: `flutter analyze --fatal-infos`
- **Test Command**: `flutter test`

## Runtime & Traffic Observation
- **Traffic / Telemetry Data**: Local development and test environments only. No live external production access logs available locally. Conservative evidence bar enforced: symbols without static or verified dynamic call paths are scrutinized before classification.

## Public Surface & Dependent Interfaces
- **Database Schema & RPCs**: PostgreSQL tables, functions, triggers, and RLS policies (`supabase/migrations/`).
- **Edge Functions**: `/ai` endpoint (`supabase/functions/ai/index.ts`).
- **Web App Routing & URLs**: Deep link schemes and route parameters (`invite_service.dart`, `main.dart`, `web/`).
- **App Widgets / OS Integration**: `home_widget` channel integration.

## Do-Not-Touch Paths (Protected)
- `supabase/migrations/**` (Database schema and migrations)
- `helm/assets/EULA.md` (Legal and compliance)
- `helm/assets/Privacy_policy.md` (Legal and compliance)
- `helm/lib/models/hive_models.g.dart` (Generated TypeAdapters)
- `.dart_tool/**`, `helm/build/**` (Generated build outputs)
- `.git/**` (VCS metadata)

## Autonomy Configuration
- **Level**: `safe-auto`
  - Tier 0: Delete automatically (unused imports, variables, dead comments, stray temp files).
  - Tier 1: Delete automatically after static proof (private dead functions, unused private files/assets).
  - Tier 2: Propose only (unused exported symbols, unused dependencies, unused configuration).
  - Tier 3: Propose only, require explicit human confirmation (public surface, database objects, contracts).

## Storage Locations
- **Baselines**: `docs/reduce/BASELINES.md`
- **Session Reports**: `docs/reduce/reports/`

