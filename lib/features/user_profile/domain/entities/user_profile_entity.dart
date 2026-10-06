import 'package:equatable/equatable.dart';

/// Moneda por defecto: el mercado inicial es Chile.
const String kDefaultCurrency = 'CLP';

/// Monedas que el usuario puede elegir en onboarding y en Editar perfil.
/// Por ahora solo Chile (CLP) y dólar (USD); las reglas de Firestore
/// rechazan cualquier otro valor.
const List<String> kSupportedCurrencies = ['CLP', 'USD'];

/// Rubros ofrecidos en onboarding y en Editar perfil.
///
/// Los seis primeros son los oficios del artesano chileno, que es el usuario
/// al que apunta la app y que antes no tenía dónde elegir: la lista empezaba
/// en "Taller Mecánico" y no incluía cerámica, telar ni joyería.
///
/// Los valores existentes NO se renombran (ni para corregirles las
/// mayúsculas): `businessType` se guarda como texto libre, así que cambiarle
/// el nombre dejaría huérfano el rubro de los perfiles ya creados.
const List<String> kBusinessTypes = [
  'Cerámica y greda',
  'Tejido y telar',
  'Joyería',
  'Cuero',
  'Velas y cosmética',
  'Alimentos y conservas',
  'Carpintería',
  'Herrería',
  'Costura / Moda',
  'Electrónica',
  'Taller Mecánico',
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

  /// Iniciales a partir del nombre ("María González" → "MG").
  ///
  /// Sin nombre devuelve cadena vacía, no "IA": esas dos letras se pintaban
  /// en el avatar como si fueran las iniciales del usuario.
  static String initialsFor(final String name) {
    final parts = name
        .split(' ')
        .where((final part) => part.trim().isNotEmpty)
        .take(2)
        .map((final part) => part.trim()[0].toUpperCase())
        .toList();
    return parts.join();
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
