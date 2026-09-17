import 'package:equatable/equatable.dart';

/// Moneda por defecto: el mercado inicial es Chile.
const String kDefaultCurrency = 'CLP';

/// Monedas que el usuario puede elegir en onboarding y en Editar perfil.
const List<String> kSupportedCurrencies = [
  'CLP',
  'USD',
  'ARS',
  'COP',
  'PEN',
  'MXN',
  'EUR',
];

/// Rubros ofrecidos en onboarding y en Editar perfil.
const List<String> kBusinessTypes = [
  'Taller Mecánico',
  'Carpintería',
  'Herrería',
  'Electrónica',
  'Costura / Moda',
  'Construcción',
  'Otro',
];

/// Perfil del usuario (`users/{uid}`).
///
/// [id] es el uid del documento; no se persiste como campo. [isPro] se deriva
/// de `plan == 'pro'`, que solo escribe el backend.
class UserProfileEntity extends Equatable {
  final String id;
  final String name;
  final String businessName;
  final String businessType;
  final String currency;
  final double monthlyGoal;
  final bool isPro;
  final String avatarInitials;

  const UserProfileEntity({
    required this.id,
    required this.name,
    required this.businessName,
    required this.businessType,
    required this.currency,
    required this.monthlyGoal,
    required this.isPro,
    required this.avatarInitials,
  });

  /// Iniciales a partir del nombre ("María González" → "MG"); "IA" si vacío.
  static String initialsFor(final String name) {
    final parts = name
        .split(' ')
        .where((final part) => part.trim().isNotEmpty)
        .take(2)
        .map((final part) => part.trim()[0].toUpperCase())
        .toList();
    return parts.isEmpty ? 'IA' : parts.join();
  }

  UserProfileEntity copyWith({
    final String? id,
    final String? name,
    final String? businessName,
    final String? businessType,
    final String? currency,
    final double? monthlyGoal,
    final bool? isPro,
    final String? avatarInitials,
  }) =>
      UserProfileEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        businessName: businessName ?? this.businessName,
        businessType: businessType ?? this.businessType,
        currency: currency ?? this.currency,
        monthlyGoal: monthlyGoal ?? this.monthlyGoal,
        isPro: isPro ?? this.isPro,
        avatarInitials: avatarInitials ?? this.avatarInitials,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        businessName,
        businessType,
        currency,
        monthlyGoal,
        isPro,
        avatarInitials,
      ];
}
