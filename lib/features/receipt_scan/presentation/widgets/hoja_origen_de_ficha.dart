import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/receipt_scan_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../inventory/domain/entities/inventory_item_type.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../inventory/presentation/widgets/item_form_sheet.dart';
import '../../data/datasources/mlkit_text_reader.dart';
import '../../data/datasources/receipt_picker_datasource.dart';
import '../../data/repositories/receipt_scan_repository_impl.dart';
import '../../domain/entities/receipt_document.dart';
import '../../domain/receipt_scan_availability.dart';
import '../../domain/repositories/receipt_scan_repository.dart';
import '../pages/lectura_boleta_screen.dart';
import '../providers/receipt_scan_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// DE DÓNDE SALE LA FICHA
// ═══════════════════════════════════════════════════════════════════════
// Cuatro filas, no cuatro botones: es el componente 5 del sistema
// (`PagateDataRow` navegable, 48 dp, chevron, presionado `sunken`) dentro
// del componente 14 (`PagateSheet`).
//
// POR QUÉ CUELGA DEL FAB Y NO DE UN SEGUNDO CONTROL. El principio 2 pide
// una sola acción dominante por pantalla y el 11 pide densidad: un botón
// secundario bajo los chips le roba altura a la lista, que es lo que se
// viene a ver, y un segundo FAB serían dos controles flotantes. El coste
// es un toque extra en el camino manual, que se paga una vez por ficha.
//
// EN WEB Y ESCRITORIO ESTA HOJA NO SE ABRE. [abrirAgregarAlInventario] va
// directo al formulario manual cuando `lecturaDeBoletasDisponible` es
// falso: ofrecer "tomar una foto" donde el plugin no está registrado sería
// un rótulo que no se puede cumplir, y el error nativo que saldría
// (`MissingPluginException`) no lo entiende nadie.
//
// LA FILA DE LA GALERÍA DICE "UNA IMAGEN", NO "UNA IMAGEN O UN PDF".
// `image_picker` no tiene ninguna API que devuelva un PDF, así que ese
// rótulo habría ofrecido algo que el selector de fotos no entrega.
//
// LA CUARTA FILA ES LA QUE SÍ DA EL PDF, y es la que pidió el dueño:
// "Buscar el archivo en el teléfono" abre el selector de DOCUMENTOS del
// sistema, el de Descargas y Archivos, no el de fotos. Hasta ahora la
// única forma de leer un PDF guardado era salir de Págate, abrir Archivos
// y compartirlo de vuelta; la línea del pie, que lo explicaba, seguía
// siendo cierta pero ya no es el único camino.
//
// EL ORDEN DE LAS CUATRO ES EL DE USO ESPERADO, no el de implementación:
// a mano primero (es lo que el usuario ya conocía), después la foto (el
// caso corriente: la boleta está en el mostrador), y al final las dos
// entradas de "algo que ya tengo guardado".
// ═══════════════════════════════════════════════════════════════════════

/// Punto de entrada único de "agregar al inventario".
///
/// Lo llaman el FAB de la pestaña y la acción del estado vacío. Decide
/// entre la hoja de origen y el formulario manual según la plataforma, así
/// que ninguno de los dos llamadores tiene que saber de plataformas.
Future<void> abrirAgregarAlInventario(
  final BuildContext context,
  final InventoryItemType tipo, {
  final ReceiptScanRepository? repositorio,
}) {
  if (!lecturaDeBoletasDisponible) return mostrarHojaDeItem(context, tipo);

  final inventario = context.read<InventoryProvider>();
  return showPagateSheet<void>(
    context: context,
    builder: (final _) => ChangeNotifierProvider<InventoryProvider>.value(
      value: inventario,
      child: HojaOrigenDeFicha(tipo: tipo, repositorio: repositorio),
    ),
  );
}

class HojaOrigenDeFicha extends StatelessWidget {
  const HojaOrigenDeFicha({super.key, required this.tipo, this.repositorio});

  final InventoryItemType tipo;

  /// Inyectable para los tests, que no tienen cámara ni selector nativo.
  /// En la app va nulo y se usa [crearReceiptScanRepository].
  final ReceiptScanRepository? repositorio;

  @override
  Widget build(final BuildContext context) => PagateSheet(
        title: 'Agregar al inventario',

        // Cero relleno en el cuerpo: las filas del sistema traen el suyo y
        // sus divisores van a sangre. El texto del pie pone el suyo.
        bodyPadding: const EdgeInsets.only(bottom: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PagateDataRow(
              label: 'Escribir la ficha a mano',
              subtitle: 'Como hasta ahora',
              value: '',
              onTap: () => _manual(context),
            ),
            PagateDataRow(
              label: 'Tomar una foto de la boleta',
              subtitle: 'Se abre la cámara del teléfono',
              value: '',
              onTap: () => _leer(context, _Origen.camara),
            ),
            PagateDataRow(
              label: 'Elegir una imagen de la galería',
              subtitle: 'Una que ya tengas guardada',
              value: '',
              onTap: () => _leer(context, _Origen.galeria),
            ),
            PagateDataRow(
              label: 'Buscar el archivo en el teléfono',
              subtitle: 'Un PDF o una imagen, por ejemplo en Descargas',
              value: '',
              showDivider: false,
              onTap: () => _leer(context, _Origen.archivo),
            ),
            const SizedBox(height: AppSpacing.x4),

            // Informa, no es un control: el camino de compartir no se puede
            // iniciar desde dentro de la app.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Text(
                'También puedes compartir una boleta o un PDF a $kAppName '
                'desde WhatsApp o el correo, sin pasar por aquí.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
              ),
            ),
          ],
        ),
      );

  Future<void> _manual(final BuildContext context) async {
    final navigator = Navigator.of(context);
    // El contexto del Navigator y no el de la hoja: la hoja se va a
    // desmontar en la línea siguiente, y abrir la siguiente desde un
    // contexto muerto no encuentra ni el Navigator ni los providers.
    final padre = navigator.context;
    navigator.pop();
    await mostrarHojaDeItem(padre, tipo);
  }

  Future<void> _leer(final BuildContext context, final _Origen origen) async {
    final inventario = context.read<InventoryProvider>();
    final navigator = Navigator.of(context);
    final padre = navigator.context;
    navigator.pop();

    final lector = repositorio ?? crearReceiptScanRepository();
    final ReceiptDocument? documento;
    try {
      documento = switch (origen) {
        _Origen.camara => await lector.tomarFoto(),
        _Origen.galeria => await lector.elegirImagen(),
        _Origen.archivo => await lector.elegirDocumento(),
      };
    } on ReceiptScanException catch (e) {
      // CANCELAR NO PASA POR AQUÍ: los dos selectores devuelven `null`.
      // Esto es un permiso denegado, un `SecurityException` por un permiso
      // declarado y no concedido, que no hay app de cámara, o un archivo
      // elegido que no está en el disco local. La app sigue entera: se
      // dice qué pasó y qué se puede hacer.
      if (!padre.mounted) return;
      AppFeedback.showError(
        padre,
        e.hint == null ? e.message : '${e.message} ${e.hint}',
      );
      return;
    }

    // El usuario canceló. No se dice nada: cancelar es una decisión suya,
    // no un error que haya que explicarle.
    if (documento == null) return;
    if (!padre.mounted) return;

    await abrirLecturaDeBoleta(
      padre,
      documento: documento,
      inventario: inventario,
      repositorio: lector,
    );
  }
}

enum _Origen { camara, galeria, archivo }

/// Monta el provider de la lectura y empuja la pantalla de revisión.
///
/// El provider se crea AQUÍ y no en `UserScope` a propósito: una lectura es
/// un trabajo con principio y fin, así que su estado tiene que morir con la
/// pantalla. Uno de alcance de usuario conservaría la lista de la boleta
/// anterior y la segunda lectura empezaría con artículos de la primera.
Future<void> abrirLecturaDeBoleta(
  final BuildContext context, {
  required final ReceiptDocument documento,
  required final InventoryProvider inventario,
  final ReceiptScanRepository? repositorio,
  final String? avisoDeEntrada,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (final _) => MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: inventario),
            ChangeNotifierProvider<ReceiptScanProvider>(
              create: (final _) => ReceiptScanProvider(
                repository: repositorio ?? crearReceiptScanRepository(),
                inventory: inventario,
              ),
            ),
          ],
          child: LecturaBoletaScreen(
            documento: documento,
            avisoDeEntrada: avisoDeEntrada,
          ),
        ),
      ),
    );

/// Fábrica por defecto del repositorio. Los tests pasan el suyo.
ReceiptScanRepository crearReceiptScanRepository() => ReceiptScanRepositoryImpl(
      picker: ReceiptPickerDatasource(),
      reader: MlkitTextReader(),
      service: ReceiptScanService(),
    );
