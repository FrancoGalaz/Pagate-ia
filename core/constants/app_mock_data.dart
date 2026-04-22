import '../../features/finances/domain/entities/finances_summary_entity.dart';
import '../../features/finances/domain/entities/fixed_expense_entity.dart';
import '../../features/inventory/domain/entities/inventory_item_entity.dart';
import '../../features/inventory/domain/entities/inventory_item_type.dart';
import '../../features/user_profile/domain/entities/user_profile_entity.dart';

/// Centralized static mock data for Págate-IA MVP.
class AppMockData {
  AppMockData._();

  // ─── User Profile ─────────────────────────────────────────────────
  static const UserProfileEntity user = UserProfileEntity(
    id: 'u1',
    name: 'Carlos Mendoza',
    businessName: 'Taller Mendoza',
    businessType: 'Taller Mecánico',
    currency: 'MXN',
    monthlyGoal: 35000,
    isPro: true,
    avatarInitials: 'CM',
  );

  // ─── Recent Activity ──────────────────────────────────────────────
  static const List<Map<String, String>> recentActivity = [
    {
      'type': 'income',
      'title': 'Servicio de frenos',
      'subtitle': 'Cliente: Juan Pérez',
      'amount': '+\$850',
      'time': 'Hoy, 10:30',
    },
    {
      'type': 'expense',
      'title': 'Aceite motor 5W-30',
      'subtitle': 'Proveedor: AutoPartes SA',
      'amount': '-\$320',
      'time': 'Hoy, 09:15',
    },
    {
      'type': 'income',
      'title': 'Cambio de clutch',
      'subtitle': 'Cliente: María García',
      'amount': '+\$2,200',
      'time': 'Ayer, 16:45',
    },
    {
      'type': 'income',
      'title': 'Afinación general',
      'subtitle': 'Cliente: Roberto Silva',
      'amount': '+\$1,100',
      'time': 'Ayer, 14:20',
    },
    {
      'type': 'expense',
      'title': 'Renta local',
      'subtitle': 'Gasto fijo mensual',
      'amount': '-\$5,000',
      'time': '13 mar',
    },
  ];

  // ─── Inventory Items ──────────────────────────────────────────────
  static const List<InventoryItemEntity> inventoryItems = [
    InventoryItemEntity(
      id: 'i1',
      name: 'Aceite Motor 5W-30',
      type: InventoryItemType.material,
      price: 89.50,
      stock: 24,
      minStock: 10,
      unit: 'litros',
      supplier: 'AutoPartes SA',
      code: 'ACE-5W30',
    ),
    InventoryItemEntity(
      id: 'i2',
      name: 'Filtro de Aceite',
      type: InventoryItemType.material,
      price: 45.00,
      stock: 3,
      minStock: 5,
      unit: 'piezas',
      supplier: 'AutoPartes SA',
      code: 'FIL-ACE',
    ),
    InventoryItemEntity(
      id: 'i3',
      name: 'Pastillas de Freno',
      type: InventoryItemType.product,
      price: 280.00,
      stock: 0,
      minStock: 4,
      unit: 'juegos',
      supplier: 'FrenosMax',
      code: 'PAS-FRE',
    ),
    InventoryItemEntity(
      id: 'i4',
      name: 'Líquido de Frenos DOT4',
      type: InventoryItemType.material,
      price: 65.00,
      stock: 18,
      minStock: 6,
      unit: 'litros',
      supplier: 'AutoPartes SA',
      code: 'LIQ-DOT4',
    ),
    InventoryItemEntity(
      id: 'i5',
      name: 'Bujías NGK Premium',
      type: InventoryItemType.product,
      price: 95.00,
      stock: 2,
      minStock: 8,
      unit: 'piezas',
      supplier: 'NGK México',
      code: 'BUJ-NGK',
    ),
    InventoryItemEntity(
      id: 'i6',
      name: 'Kit de Embrague',
      type: InventoryItemType.product,
      price: 1850.00,
      stock: 7,
      minStock: 2,
      unit: 'juegos',
      supplier: 'TransMax',
      code: 'KIT-EMB',
    ),
  ];

  // ─── Fixed Expenses ───────────────────────────────────────────────
  static const List<FixedExpenseEntity> fixedExpenses = [
    FixedExpenseEntity(
      id: 'e1',
      name: 'Renta del local',
      amount: 5000,
      category: 'Infraestructura',
    ),
    FixedExpenseEntity(
      id: 'e2',
      name: 'Electricidad',
      amount: 850,
      category: 'Servicios',
    ),
    FixedExpenseEntity(
      id: 'e3',
      name: 'Internet y teléfono',
      amount: 450,
      category: 'Servicios',
    ),
  ];

  // ─── Finances Summary ─────────────────────────────────────────────
  static const List<FinancesSummaryEntity> monthsSummary = [
    FinancesSummaryEntity(
      month: 'Marzo 2025',
      totalIncome: 23800,
      totalExpenses: 8300,
      monthlyGoal: 35000,
      fixedExpenses: fixedExpenses,
    ),
    FinancesSummaryEntity(
      month: 'Febrero 2025',
      totalIncome: 31200,
      totalExpenses: 9100,
      monthlyGoal: 35000,
      fixedExpenses: fixedExpenses,
    ),
    FinancesSummaryEntity(
      month: 'Enero 2025',
      totalIncome: 28500,
      totalExpenses: 7800,
      monthlyGoal: 30000,
      fixedExpenses: fixedExpenses,
    ),
  ];

  // ─── FAQ Help Items ───────────────────────────────────────────────
  static const List<Map<String, String>> faqItems = [
    {
      'question': '¿Cómo registro un nuevo ingreso?',
      'answer':
          'Ve a Inicio y toca el botón "Venta" en las acciones rápidas. Ingresa el monto, concepto y cliente. El ingreso se registrará automáticamente en tu resumen del mes.',
    },
    {
      'question': '¿Cómo funciona la meta mensual?',
      'answer':
          'La meta mensual es el objetivo de ingresos que estableces para tu negocio. Puedes configurarla en la sección de Finanzas. La app te mostrará tu progreso en tiempo real.',
    },
    {
      'question': '¿Cómo agrego productos al inventario?',
      'answer':
          'En la sección Inventario, toca el botón + (teal) en la esquina inferior derecha. Completa los datos del producto o material y guarda.',
    },
    {
      'question': '¿Qué significa el stock en rojo?',
      'answer':
          'El stock en rojo indica que el producto tiene 0 unidades disponibles (sin stock). El amarillo significa que está por debajo del mínimo configurado. El verde indica stock suficiente.',
    },
  ];
}
