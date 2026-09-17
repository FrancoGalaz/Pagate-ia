import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// `MaterialApp` de la app, con el tema global.
///
/// Recibe una [sessionKey] que se usa como `key` del `MaterialApp`: cuando
/// cambia la sesión (arranque → sin usuario → usuario) el `Navigator` se crea
/// de cero, así ninguna ruta apilada sobrevive a un cambio de usuario ni
/// puede quedar leyendo providers que ya no existen.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.sessionKey,
    required this.home,
  });

  final String sessionKey;
  final Widget home;

  @override
  Widget build(final BuildContext context) => MaterialApp(
        key: ValueKey('app-$sessionKey'),
        title: 'Págate-IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: home,
      );
}
