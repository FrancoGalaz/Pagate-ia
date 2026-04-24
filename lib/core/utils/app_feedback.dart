import 'package:flutter/material.dart';

class AppFeedback {
  AppFeedback._();

  static void showMessage(
    final BuildContext context,
    final String message,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
