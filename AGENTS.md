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

## Web Deployment
- Build: `flutter build web --release`
- Deploy: `firebase deploy --only hosting`
- Or use the script: `./scripts/deploy-web.sh`
- URL: `https://pagate-17211.web.app`
- The app auto-detects web vs mobile via `LayoutBuilder` (breakpoint 720px).
  - Desktop: NavigationRail sidebar
  - Mobile: BottomNavigationBar
- Google Sign-In works automatically on web (Firebase Auth popup).
- For the AI chat, compile with:
  `flutter build web --release --dart-define=OPENROUTER_API_KEY=sk-or-...`

## Web Firebase Configuration
The web Firebase config in `firebase_options.dart` needs updating before deployment:
1. Go to Firebase Console → Project Settings → Add app → Web
2. Copy the `apiKey` and `appId` into `firebase_options.dart`
3. In Firebase Console → Authentication → Sign-in method → Enable Google provider

## Roadmap (orden de prioridad)

### Fase 1 — Deploy y Pulido (AHORA)
1. Actualizar firebase_options.dart con credenciales web reales ⏳ (requiere credenciales de Firebase Console)
2. Deploy a Firebase Hosting: `./scripts/deploy-web.sh` ⏳ (bloqueado por #1)
3. Test Google Sign-In en producción ⏳ (bloqueado por #2)
4. ✅ Pulir UI mobile — BottomNavigationBar adaptativa (iconos solo en pantallas <380px, indicador activo)

### Fase 2 — Features Core
5. ✅ Completar dashboard con métricas financieras reales (gráficos, resumen mensual)
6. ✅ CRUD completo de inventario (agregar/editar/eliminar items con fotos) — Firestore persistence
7. ✅ Perfil de usuario con edición de datos (Configuración con datos reales Firestore)

### Fase 3 — AI + Finanzas
8. ✅ Mejorar chat AI con más contexto (historial, preferencias)
9. ✅ Exportación de reportes financieros (PDF)
10. Sincronización de gastos automáticos (bank integration) 📋 (investigación completa en docs/bank-integration-research.md — recomienda: Fase 1 = carga manual PDF/CSV, Fase 2 = Belvo Connect)

### Fase 4 — Monetización
11. ✅ Landing page con formulario de waitlist — formulario captura email + nombre, almacena en localStorage (listo para migrar a Firestore cuando haya credenciales web)
12. Pricing tiers (freemium + premium)
13. Pasarela de pago integrada

## Reglas para Agentes Autónomos
- Avanzar sin preguntar. Solo pausar ante blockers reales.
- `flutter analyze` debe pasar antes de commitear.
- Commits atómicos con push inmediato.
- Usar tokens de diseño de `app_constants.dart`, no hardcodear estilos.
- Features nuevas deben seguir el patrón `data/domain/presentation` con Provider.

