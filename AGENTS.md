# AGENTS

## Environment and Toolchain
- Use Flutter/Dart from the beta line: `pubspec.yaml` requires `sdk: ^3.12.0-113.1.beta` and `.metadata` is on `channel: beta`.
- Bootstrap deps with `flutter pub get` before running analyze/tests.

## Verify Commands
- Static checks: `flutter analyze`
- Full tests: `flutter test`
- Single test file: `flutter test test/widget_test.dart`
- Run app locally: `flutter run` (pick target device), or `flutter run -d chrome` for web.

## Actual App Wiring (important entrypoints)
- App entry is `lib/main.dart`; `PagateIAApp` configures all `ChangeNotifierProvider`s in `MultiProvider`.
- Initial route is `LoginScreen` (`home: const LoginScreen()`), then login/onboarding navigates to `SetupInicialScreen` and finally `DashboardScreen`.
- Feature structure is `features/<feature>/{data,domain,presentation}` with provider-based state, not Bloc/Cubit.

## Data Layer Reality
- Main app currently wires mock repositories (`Mock*Repository`) for hourly rate, inventory, finances, and profile.
- There is a Firestore datasource at `lib/features/hourly_value/data/datasources/hourly_rate_local_datasource.dart`, but it is not used by `main.dart`.
- Do not switch to Firestore wiring casually: there is no `firebase_options.dart` or Firebase initialization path in `main.dart`.

## UI/Theming Conventions Used Here
- `lib/core/constants/app_constants.dart` is the design token source (colors, spacing, radii, sizes, durations).
- `lib/core/theme/app_theme.dart` centralizes Material theme setup; follow existing pattern and avoid ad-hoc style constants when editing screens.

## Repo Boundaries / Non-app Files
- `components/` and `frames/` contain JSX design/prototype artifacts; they are not part of the Flutter build/test pipeline.
- Root `.mcp.json` config is project-local MCP setup for OpenCode tooling; keep repo path values aligned if the project folder is moved.
