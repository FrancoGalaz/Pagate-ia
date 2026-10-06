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
export 'pagate_inline_error.dart';
export 'pagate_skeleton.dart';

// ─── Navegación y superficies ────────────────────────────────────
export 'pagate_action_bar.dart';
export 'pagate_bottom_nav.dart';
export 'pagate_month_selector.dart';
export 'pagate_sheet.dart';

// ─── BAJAS DEL PASO R-5 ──────────────────────────────────────────
// Tres archivos borrados, con su motivo:
//
// · `pagate_info_card.dart` — CERO consumidores fuera de su propio
//   archivo, verificado con grep. Ya estaba marcado como código muerto en
//   la auditoría previa.
// · `pagate_label.dart` — versalitas con tracking 0,8 en `textTertiary`
//   #9CA3AF: 2,54 sobre blanco, un fallo de AA repetido en diecisiete
//   sitios. La etiqueta de campo se integró en `PagateTextField`.
// · `pagate_back_button.dart` — un círculo de 40 dp, por debajo del área
//   táctil mínima de 48. Pasa a `IconButton(tooltip: 'Volver')`, que trae
//   la caja de 48 del tema y una etiqueta para el lector de pantalla, que
//   el círculo no tenía.
