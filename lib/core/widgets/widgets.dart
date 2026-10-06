// Barrel del sistema visual: un solo import para todos los componentes.
//
// Uso: import 'package:pagate_ia/core/widgets/widgets.dart';
//
// REGLA: todo componente de `core/widgets/` se exporta aquí, sin
// excepciones. El barrel anterior exportaba nueve de los diez y dejaba
// fuera justamente el estado de error, que por eso casi no se usaba y que
// por eso había pantallas mostrando "$0" ante un fallo de permisos.

// ─── Controles ───────────────────────────────────────────────────
export 'pagate_chip_selector.dart';
export 'pagate_primary_button.dart';
export 'pagate_social_button.dart';
export 'pagate_text_field.dart';

// ─── Estructura ──────────────────────────────────────────────────
export 'pagate_section_card.dart';
export 'pagate_section_header.dart';
export 'pagate_step_header.dart';

// ─── Filas ───────────────────────────────────────────────────────
export 'pagate_data_row.dart';
export 'pagate_movement_row.dart';

// ─── Estados ─────────────────────────────────────────────────────
export 'pagate_empty_state.dart';
export 'pagate_error_state.dart';
export 'pagate_skeleton.dart';

// ─── Bajas del paso R-5 ──────────────────────────────────────────
// `pagate_back_button.dart`, `pagate_info_card.dart` y `pagate_label.dart`
// salen del barrel en R-5c, junto con la migración de sus call sites.
export 'pagate_back_button.dart';
export 'pagate_info_card.dart';
export 'pagate_label.dart';
