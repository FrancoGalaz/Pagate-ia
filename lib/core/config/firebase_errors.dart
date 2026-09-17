import 'package:firebase_core/firebase_core.dart';

/// Convierte errores de Firebase (Auth, Firestore, Functions) en un mensaje
/// legible en español. Para cualquier otro error devuelve una descripción
/// genérica; nunca oculta el error.
String describeFirebaseError(final Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      // Firestore / Functions
      case 'permission-denied':
        return 'No tienes permiso para acceder a estos datos.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Sin conexión con el servidor. Revisa tu internet.';
      case 'resource-exhausted':
        return 'Alcanzaste el límite de uso por hoy.';
      // Auth
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'web-config-not-found':
      case 'configuration-not-found':
        return 'Falta configurar la app web en Firebase Console.';
      default:
        return error.message ?? 'Error de Firebase (${error.code}).';
    }
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Datos inválidos.';
  }
  return 'Ocurrió un error inesperado: $error';
}
