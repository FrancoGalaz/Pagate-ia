# AGENTS

## Environment and Toolchain
- Use Flutter/Dart from the beta line: `pubspec.yaml` requires `sdk: ^3.12.0-113.1.beta` and `.metadata` is on `channel: beta`.
- Bootstrap deps with `flutter pub get` before running analyze/tests.
- Font **Manrope** is bundled as variable font at `assets/fonts/Manrope[wght].ttf`.

## Verify Commands
- Static checks: `flutter analyze`
- Full tests: `flutter test`
- Single test file: `flutter test test/widget_test.dart`
- Run app locally: `flutter run` (pick target device), or `flutter run -d chrome` for web.
- Compile with API key: `flutter run --dart-define=OPENROUTER_API_KEY=sk-or-...`

## Actual App Wiring (important entrypoints)
- App entry is `lib/main.dart`; `PagateIAApp` configures all `ChangeNotifierProvider`s in `MultiProvider`.
- Initial route is `LoginScreen` (`home: const LoginScreen()`), then login/onboarding navigates to `SetupInicialScreen` and finally `DashboardScreen`.
- Feature structure is `features/<feature>/{data,domain,presentation}` with provider-based state, not Bloc/Cubit.

## Data Layer Reality
- **All features use real Firestore datasources** (no more mocks).
- Firebase initialized in `main.dart` via `DefaultFirebaseOptions.currentPlatform`.
- Auth uses `FirebaseAuthService` with `authStateChanges` listener.
- Datasources are scoped by `userId`, injected via `ChangeNotifierProxyProvider`.
- `AiService` connects to OpenRouter for the AI chat feature. API key configured via `--dart-define=OPENROUTER_API_KEY=...`.

## Collections in Firestore
- `user_profiles/{userId}` — user profile data
- `inventory_items/{itemId}` — inventory items (filtered by `userId` field)
- `finances/{userId}/summaries/{year-month}` — monthly financial summaries
- `finances/{userId}/transactions/{transactionId}` — individual transactions
- `users/{userId}` — hourly rate config (stored under `hourlyRate` field)

## Key Services
- `lib/core/services/ai_service.dart` — OpenRouter HTTP client
- `lib/core/services/firebase_auth_service.dart` — Firebase Auth wrapper
- `lib/features/dashboard/presentation/providers/ai_provider.dart` — AI chat state management with financial context injection

## UI/Theming Conventions Used Here
- `lib/core/constants/app_constants.dart` is the design token source (colors, spacing, radii, sizes, durations).
- `lib/core/theme/app_theme.dart` centralizes Material theme setup; follow existing pattern and avoid ad-hoc style constants when editing screens.

## Repo Boundaries / Non-app Files
- `components/` and `frames/` contain JSX design/prototype artifacts; they are not part of the Flutter build/test pipeline.
- Root `.mcp.json` config is project-local MCP setup for OpenCode tooling; keep repo path values aligned if the project folder is moved.
- `lib/core/constants/app_mock_data.dart` is dead code (no imports), kept for reference.
