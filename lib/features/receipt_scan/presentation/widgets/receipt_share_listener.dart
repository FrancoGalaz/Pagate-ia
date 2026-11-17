import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_feedback.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../data/datasources/receipt_share_datasource.dart';
import '../../domain/receipt_scan_availability.dart';
import 'hoja_origen_de_ficha.dart';

// ═══════════════════════════════════════════════════════════════════════
// LA BOLETA QUE LLEGA DE OTRA APP
// ═══════════════════════════════════════════════════════════════════════
// Vive DEBAJO del auth gate, dentro de `UserScope`, porque necesita el
// `InventoryProvider` del usuario para emparejar con lo que ya tiene y el
// Navigator de la sesión para empujar la pantalla de revisión.
//
// DESVIACIÓN DELIBERADA DE LA ESPECIFICACIÓN, Y EL MOTIVO. La
// especificación decía "envolviendo `AppShell`". `AppShell` ES el
// `MaterialApp`, así que un widget por encima de él está POR ENCIMA DEL
// Navigator: `Navigator.of(context)` desde ahí no encuentra ninguno y la
// pantalla de lectura no se podría abrir. Por eso envuelve el `home` del
// `MaterialApp`, que es el primer sitio que ya tiene Navigator y sigue
// estando dentro de `UserScope`.
//
// HACEN FALTA LOS DOS CAMINOS. `getInitialMedia()` cubre que la app
// estuviera CERRADA y el sistema la abriera con el archivo;
// `getMediaStream()` cubre que ya estuviera abierta, y su propia
// documentación avisa de que NO emite la entrega inicial. Con uno solo, la
// mitad de los casos se pierde en silencio.
//
// NO SE ABRE LA LECTURA ANTES DE QUE EXISTA EL PERFIL. Si la app se abre
// con una boleta compartida y el usuario está a medio onboarding, el
// documento se queda en espera y la pantalla se abre cuando el perfil está
// listo. Empujar una ruta encima del onboarding dejaría al usuario en una
// pantalla de inventario de un taller que todavía no existe.
// ═══════════════════════════════════════════════════════════════════════

class ReceiptShareListener extends StatefulWidget {
  const ReceiptShareListener({
    super.key,
    required this.child,
    this.datasource,
  });

  final Widget child;

  /// Inyectable para los tests, que no tienen plugin nativo.
  final ReceiptShareDatasource? datasource;

  @override
  State<ReceiptShareListener> createState() => _ReceiptShareListenerState();
}

class _ReceiptShareListenerState extends State<ReceiptShareListener> {
  ReceiptShareDatasource? _datasource;
  StreamSubscription<SharedReceipt>? _sub;

  /// Entrega recibida que todavía no se ha podido procesar (no hay perfil,
  /// o ya hay una lectura abierta).
  SharedReceipt? _pendiente;

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    if (!lecturaDeBoletasDisponible && widget.datasource == null) return;

    final fuente = widget.datasource ?? ReceiptShareDatasource();
    _datasource = fuente;

    unawaited(_consultarInicial(fuente));
    _sub = fuente.entregas().listen(_recibir);
  }

  Future<void> _consultarInicial(final ReceiptShareDatasource fuente) async {
    final entrega = await fuente.inicial();
    if (!mounted) return;
    _recibir(entrega);
  }

  void _recibir(final SharedReceipt entrega) {
    if (!entrega.hayAlgo) return;
    _pendiente = entrega;
    // En el siguiente frame: `_recibir` puede llegar en mitad de un build
    // (el stream del plugin emite cuando le llega el intento) y navegar
    // desde ahí lanza.
    WidgetsBinding.instance.addPostFrameCallback((final _) => _intentar());
  }

  void _intentar() {
    if (!mounted || _procesando) return;
    final entrega = _pendiente;
    if (entrega == null) return;

    // Sin perfil todavía no hay inventario con el que emparejar. Se queda
    // en espera; `didChangeDependencies` vuelve a intentarlo cuando el
    // provider del perfil notifique.
    final perfil = context.read<UserProfileProvider>();
    if (perfil.profile == null) return;

    _pendiente = null;
    unawaited(_procesar(entrega));
  }

  Future<void> _procesar(final SharedReceipt entrega) async {
    _procesando = true;
    try {
      // `reset()` SIEMPRE y antes de abrir nada. Sin él,
      // `getInitialMedia()` devuelve la misma entrega en cada consulta y la
      // pantalla de lectura reaparecería sola al volver a Inventario.
      await _datasource?.consumir();
      if (!mounted) return;

      final aviso = entrega.aviso;
      final documento = entrega.documento;

      if (documento == null) {
        if (aviso != null) AppFeedback.showError(context, aviso);
        return;
      }

      await abrirLecturaDeBoleta(
        context,
        documento: documento,
        inventario: context.read<InventoryProvider>(),
        avisoDeEntrada: aviso,
      );
    } finally {
      _procesando = false;
      // Si llegó otra entrega mientras se revisaba la primera, se atiende
      // ahora en vez de perderse.
      if (mounted && _pendiente != null) _intentar();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendiente == null) return;
    WidgetsBinding.instance.addPostFrameCallback((final _) => _intentar());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_datasource?.consumir());
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    // `watch` y no `read`: es lo que hace que una entrega en espera se
    // atienda en cuanto el perfil aparece, por `didChangeDependencies`.
    context.watch<UserProfileProvider>();
    return widget.child;
  }
}
