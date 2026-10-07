// Política de privacidad de Págate-IA (tarea P-08).
//
// Cada dato que se enumera aquí fue verificado contra el código, no inventado:
//   · perfil y valor hora  → lib/features/user_profile/data/models/
//   · transacciones y gastos fijos → lib/features/finances/data/models/
//   · inventario → lib/features/inventory/data/models/
//   · lo que sale hacia OpenRouter → functions/src/prompt.ts y chat.ts
//   · lista de espera → functions/src/waitlist.ts
//   · qué funciones del cliente existen de verdad → FUNCIONES_APP en
//     content/legal-meta.ts, comprobado contra lib/ por honestidad.test.ts
// Si se añade un campo nuevo al modelo de datos, hay que añadirlo aquí: el
// formulario de Seguridad de Datos de Google Play exige que coincidan.

import LegalLayout, { LegalList, LegalSection } from './LegalLayout';
import {
  APP_NAME,
  BACKUP_RETENTION_DAYS,
  BUZON,
  CANAL_ALTERNATIVO,
  DELETION_SLA_DAYS,
  FUNCIONES_APP,
  LEGAL_ROUTES,
  RESPONSABLE_IDENTIFICADO,
  RESPONSABLE_SIN_IDENTIFICAR,
  RESPONSIBLE,
  siteUrl,
} from '../content/legal-meta';

// Texto del canal de privacidad. Mientras no haya buzón publicado se nombra el
// canal que sí existe siempre (el correo del desarrollador en la ficha de Play)
// en lugar de imprimir el marcador entre corchetes.
const CONTACTO_PRIVACIDAD = BUZON.privacidad ?? CANAL_ALTERNATIVO;
const CONTACTO_SOPORTE = BUZON.soporte ?? CANAL_ALTERNATIVO;

export default function PrivacidadPage() {
  return (
    <LegalLayout
      title="Política de privacidad"
      intro={`Este documento explica qué datos recoge ${APP_NAME}, dónde se guardan, con quién se comparten, cuánto tiempo se conservan y cómo puedes ejercer tus derechos sobre ellos.`}
    >
      <LegalSection id="responsable" title="1. Quién es responsable de tus datos">
        {/* Dos redacciones, no un marcador: con la identidad publicada se dan
            nombre, RUT y domicilio; sin ella se describe al responsable por lo
            que sí se sabe de él. Nunca se imprime un corchete. */}
        {RESPONSABLE_IDENTIFICADO ? (
          <p>
            El responsable del tratamiento de los datos personales que se describen en
            este documento es {RESPONSIBLE.legalName}, RUT {RESPONSIBLE.taxId}, con
            domicilio en {RESPONSIBLE.address}, {RESPONSIBLE.country}.
          </p>
        ) : (
          <p>
            El responsable del tratamiento de los datos personales que se describen en
            este documento es {RESPONSABLE_SIN_IDENTIFICAR}. Su nombre completo, RUT y
            domicilio se publican en esta misma página en cuanto estén definidos.
          </p>
        )}
        <p>
          Para cualquier consulta sobre privacidad puedes escribir a{' '}
          <strong>{CONTACTO_PRIVACIDAD}</strong>.
        </p>
      </LegalSection>

      <LegalSection id="datos" title="2. Qué datos recogemos exactamente">
        <p>
          {APP_NAME} no pide ningún dato que no use. Esta es la lista completa, campo
          por campo.
        </p>

        <h3 className="font-semibold text-text-primary pt-2">
          2.1 Datos de la cuenta
        </h3>
        <LegalList
          items={[
            <>
              <strong>Correo electrónico y contraseña</strong>, cuando creas la cuenta
              con correo. La contraseña la gestiona y cifra Firebase Authentication:
              la app nunca la guarda ni la puede leer.
            </>,
            <>
              <strong>Correo y nombre que entrega Google</strong>, si entras con tu
              cuenta de Google. Este acceso hoy solo funciona en la versión web.
            </>,
          ]}
        />

        <h3 className="font-semibold text-text-primary pt-2">
          2.2 Datos de tu perfil y tu negocio
        </h3>
        <LegalList
          items={[
            <>
              <strong>Tu nombre</strong> y las iniciales que se muestran en el avatar.
            </>,
            <>
              <strong>Nombre del negocio</strong> y <strong>tipo o rubro</strong> del
              negocio.
            </>,
            <>
              <strong>Moneda</strong> en la que trabajas y{' '}
              <strong>meta mensual de ingresos</strong>.
            </>,
            <>
              <strong>Cálculo de tu valor hora</strong>: el sueldo mensual que quieres
              ganar, las horas que tienes disponibles al mes y el valor hora resultante.
            </>,
          ]}
        />

        <h3 className="font-semibold text-text-primary pt-2">
          2.3 Datos financieros de tu negocio
        </h3>
        <LegalList
          items={[
            <>
              <strong>Transacciones</strong>: título, descripción, monto, si es ingreso
              o gasto, categoría y fecha. El título es texto libre que escribes tú.
            </>,
            <>
              En los ingresos, <strong>si los anotas</strong>: con qué documento lo
              respaldaste —boleta de venta, boleta de honorarios o sin documento— y la{' '}
              <strong>comisión que te descontó el medio de pago</strong>. Los dos son
              opcionales: si no los anotas, no se guardan.
            </>,
            <>
              <strong>Gastos fijos</strong>: nombre y monto de cada uno.
            </>,
            <>
              {/* `supplier` y `code` existen en el modelo
                  (`inventory_item_model.dart`), pero mientras el formulario de alta
                  no los pida el usuario no tiene forma de indicarlos: nombrarlos
                  aquí era describir un campo al que no se llega. Lo decide
                  FUNCIONES_APP, no una suposición. */}
              <strong>Inventario</strong>: nombre del producto o material, tipo, precio,
              stock actual, stock mínimo, unidad de medida
              {FUNCIONES_APP.fichaInventarioCompleta
                ? ' y, si los indicas, proveedor y código interno.'
                : '.'}
            </>,
            <>
              <strong>Resúmenes mensuales</strong> que el servidor calcula a partir de
              tus transacciones: ingresos, gastos, suma de las comisiones de los medios
              de pago y número de movimientos por mes.
            </>,
          ]}
        />
        <p>
          Estos datos son información financiera. Google Play los clasifica como
          categoría sensible y los tratamos como tales: no se usan para publicidad, no
          se venden y no se cruzan con los de otras personas.
        </p>

        <h3 className="font-semibold text-text-primary pt-2">
          2.4 Conversaciones con el asistente
        </h3>
        <LegalList
          items={[
            <>
              <strong>Tus mensajes</strong> al asistente y{' '}
              <strong>las respuestas</strong> que te da, con la fecha de cada uno y un
              título generado a partir de tu primer mensaje.
            </>,
            <>
              Un <strong>contador de mensajes</strong> para aplicar el límite del
              asistente: cuántos has enviado <strong>en total</strong> desde que
              creaste la cuenta, y cuántos hoy.
            </>,
            <>
              Si <strong>reportas una respuesta</strong> del asistente: el motivo que
              elijas, el comentario que escribas si escribes uno, y el texto de la
              respuesta reportada. Nos sirve para corregir el asistente y{' '}
              <strong>no sale de nuestro proyecto</strong>: no se envía al proveedor
              del modelo.
            </>,
          ]}
        />

        <h3 className="font-semibold text-text-primary pt-2">
          2.5 Lista de espera de este sitio web
        </h3>
        <LegalList
          items={[
            <>
              Si te inscribes en la lista de espera: <strong>nombre</strong>,{' '}
              <strong>correo electrónico</strong> y el{' '}
              <strong>origen de la inscripción</strong> (por ejemplo, «landing-page»).
            </>,
            <>
              Tu <strong>dirección IP</strong>, que el servidor usa de forma temporal
              para limitar el número de inscripciones por hora y frenar el envío
              automatizado. No se guarda junto a tu inscripción.
            </>,
          ]}
        />

        <h3 className="font-semibold text-text-primary pt-2">
          2.6 Boletas y facturas que leas con una foto o un documento
        </h3>
        {/* La imagen no se guarda en ningún momento, y de ahí sale todo lo demás:
            no aparece en el §6 de retención, no aparece en la lista de lo que
            borra la eliminación de cuenta y no se declara como dato recopilado en
            el formulario de Seguridad de los datos de Play. El razonamiento, con
            la regla de Play citada, está en docs/SEGURIDAD-DATOS-PLAY.md §1.7. */}
        {!FUNCIONES_APP.lectorBoletas && (
          <p>
            <strong>Esta función todavía no está en la app publicada</strong>: se
            está construyendo. La describimos aquí desde ya, y no el día que
            llegue, para que nadie se la encuentre sin haber podido leer antes qué
            hace con sus datos. Lo que sigue es lo que hará.
          </p>
        )}
        <p>
          Para que no tengas que teclear material por material lo que compraste, la
          app te deja leer una boleta o una factura de tres maneras: tomando una
          foto con la cámara de tu teléfono, eligiendo una imagen que ya tienes en
          la galería, o compartiendo a la app una imagen o un PDF desde donde lo
          tengas: WhatsApp, el correo o la app de Archivos del propio teléfono. La
          app no abre tus carpetas por su cuenta; eres tú quien le manda el
          archivo desde la otra app.
        </p>
        <LegalList
          items={[
            <>
              <strong>La imagen no se guarda.</strong> Ni en tu teléfono ni en
              nuestros servidores. Se abre, se lee y se descarta en el momento. No
              hay un álbum de boletas dentro de la app, no se sube a ninguna parte
              y no queda una copia que podamos ver nosotros, ni ahora ni después.
            </>,
            <>
              <strong>El texto se lee dentro de tu teléfono.</strong> El
              reconocimiento de texto lo hace el propio teléfono, sin conexión a
              internet y sin enviar la imagen a ningún servidor, nuestro ni de
              nadie.
            </>,
            <>
              <strong>Lo único que puede salir del teléfono es el texto.</strong>{' '}
              El reconocimiento devuelve líneas sueltas, y ordenarlas en artículos
              con su cantidad, su nombre y su precio es un paso aparte. Cuando ese
              paso está activo lo hace nuestro servidor, por el mismo camino que
              describe el punto 5.2: desde ahí, OpenRouter y el proveedor del
              modelo. Viaja el texto; la imagen no sale nunca.
            </>,
            // Dos hechos distintos, y el documento necesita los dos: que el
            // lector exista no significa que salga texto hacia un tercero. Eso
            // solo ocurre con el callable `scanReceipt` desplegado, y lo dice
            // FUNCIONES_APP.ordenadoDeBoletasEnServidor, no una suposición.
            // Escrito así, el apartado es cierto en los dos estados.
            FUNCIONES_APP.ordenadoDeBoletasEnServidor ? (
              <>
                <strong>Ese paso está activo hoy.</strong> Cuando leas una boleta,
                el texto reconocido saldrá hacia nuestro servidor para ordenarlo. Si
                no quieres que salga, escribe los materiales a mano.
              </>
            ) : (
              <>
                <strong>Y hoy ese paso todavía no está activo</strong>, así que por
                ahora el texto tampoco sale: la lista la arma tu propio teléfono, de
                principio a fin, y no se envía nada a ninguna parte. Lo de arriba
                describe lo que pasará el día que lo activemos, y lo contamos desde
                ya para que nadie se lo encuentre sin avisar. Mientras tanto, cada
                vez que la app no use ese paso —porque no esté disponible, porque no
                tengas señal o porque hayas agotado tus lecturas— te lo dice en la
                propia pantalla de revisión, con esas palabras.
              </>
            ),
            <>
              <strong>Nada entra a tu inventario sin que tú lo confirmes.</strong>{' '}
              La app te muestra la lista que entendió para que la corrijas, borres
              lo que no corresponda y la confirmes. Mientras no confirmes, no se
              guarda nada.
            </>,
            <>
              <strong>Lo que queda guardado son artículos de inventario</strong>, los
              mismos campos del punto 2.3, como si los hubieras escrito tú. Nada
              más.
            </>,
          ]}
        />
        <p>
          <strong>El reconocimiento no es perfecto.</strong> Una boleta desvaída,
          arrugada o impresa en papel térmico gastado da lecturas con errores: una
          cifra de menos, un nombre partido en dos. Por eso el paso de revisión no
          se puede saltar: la app propone, tú corriges y tú confirmas.
        </p>
        <p>
          <strong>Una boleta puede llevar datos de otra persona.</strong> No lleva
          solo lo que compraste: casi siempre lleva el nombre, el RUT, la dirección
          o el teléfono de quien te la emitió, y a veces los tuyos. Eso son datos
          personales de un tercero, y la app no los separa por ti, igual que no
          separa el nombre de un cliente escrito en el título de una transacción. Si
          el texto reconocido sale para ordenarlo, esos datos salen con él. Si
          prefieres evitarlo, escribe los materiales a mano
          {FUNCIONES_APP.ordenadoDeBoletasEnServidor
            ? ': la pantalla de revisión te deja corregir lo que entra a tu inventario, pero para poder proponerte esa lista el texto ya habrá viajado.'
            : '. Mientras el paso de ordenado siga sin activarse, ese texto no sale del teléfono y la cuestión no se plantea; cuando se active, para poder proponerte la lista el texto ya habrá viajado.'}
        </p>

        <h3 className="font-semibold text-text-primary pt-2">2.7 Qué NO recogemos</h3>
        <LegalList
          items={[
            'No hay publicidad ni identificadores publicitarios.',
            'No hay SDK de analítica ni de seguimiento de uso.',
            // La app no pide permiso de cámara ni de fotos: usa la cámara y el
            // selector del propio teléfono, que no los exigen. Pero decir «no se
            // accede a tu cámara» con el lector de boletas ya en la app sería
            // falso, así que la frase cambia con la función.
            FUNCIONES_APP.lectorBoletas
              ? 'No se accede a tus contactos, tu ubicación ni tu micrófono. A la cámara y a tus archivos se llega solo cuando tú eliges leer una boleta, con la cámara y el selector del propio teléfono, y la imagen no se guarda (punto 2.6).'
              : 'No se accede a tus contactos, tu ubicación, tu cámara, tu micrófono ni tus archivos.',
            FUNCIONES_APP.lectorBoletas
              ? 'No se conecta a tus cuentas bancarias y no se leen tus movimientos reales: todo lo que ves en la app lo pusiste tú, escribiéndolo o confirmando lo que la app leyó de una boleta.'
              : 'No se conecta a tus cuentas bancarias y no se leen tus movimientos reales: todo lo que ves en la app lo escribes tú.',
          ]}
        />
      </LegalSection>

      <LegalSection id="uso" title="3. Para qué usamos estos datos">
        <LegalList
          items={[
            'Crear tu cuenta y permitirte entrar.',
            'Mostrarte tus ingresos, gastos, resúmenes mensuales e inventario.',
            ...(FUNCIONES_APP.lectorBoletas
              ? [
                  'Leer el texto de una boleta que fotografíes o compartas, para proponerte los materiales que compraste antes de que los confirmes.',
                ]
              : []),
            'Calcular tu valor hora y comparar tus ingresos con tu meta mensual.',
            'Dar contexto al asistente para que sus respuestas se refieran a tu negocio y no a un caso genérico.',
            'Aplicar el límite de mensajes del asistente y evitar abusos del servicio.',
            'Avisarte por correo cuando la app esté disponible, si te inscribiste en la lista de espera.',
          ]}
        />
        <p>
          No usamos tus datos para perfilarte con fines publicitarios ni para tomar
          decisiones automatizadas que te afecten legalmente.
        </p>
      </LegalSection>

      <LegalSection id="donde" title="4. Dónde se guardan">
        <p>
          La app no guarda tus datos en un servidor propio: usa la infraestructura de
          Firebase, de Google Cloud Platform.
        </p>
        <LegalList
          items={[
            <>
              <strong>Firebase Authentication</strong> guarda tu correo y la credencial
              de acceso.
            </>,
            <>
              <strong>Cloud Firestore</strong> guarda tu perfil, tus transacciones, tus
              gastos fijos, tu inventario, tus resúmenes mensuales, tus conversaciones y
              la lista de espera.
            </>,
            <>
              <strong>Cloud Functions</strong> ejecuta la lógica de servidor en la
              región <code>southamerica-west1</code> (Santiago de Chile).
            </>,
          ]}
        />
        <p>
          Toda la comunicación entre la app y estos servicios va cifrada en tránsito
          mediante TLS (HTTPS). En reposo, Firestore cifra los datos con el cifrado por
          defecto de Google Cloud. Google puede replicar la información en centros de
          datos fuera de Chile; al usar la app aceptas esa transferencia internacional.
        </p>
      </LegalSection>

      <LegalSection id="terceros" title="5. Con quién se comparten">
        <h3 className="font-semibold text-text-primary">
          5.1 Google (Firebase y Google Cloud)
        </h3>
        <p>
          Google aloja y procesa los datos por nuestra cuenta, siguiendo nuestras
          instrucciones y sin usarlos para sus propios fines. Puedes consultar su{' '}
          <a
            className="text-brand underline"
            href="https://firebase.google.com/support/privacy"
            target="_blank"
            rel="noreferrer noopener"
          >
            aviso de privacidad y seguridad de Firebase
          </a>
          .
        </p>

        <h3 className="font-semibold text-text-primary pt-2">
          5.2 OpenRouter y el proveedor del modelo de lenguaje
        </h3>
        <p>
          El asistente no funciona dentro de tu teléfono. Cada vez que le envías un
          mensaje, nuestro servidor construye un texto de contexto y lo envía a{' '}
          <a
            className="text-brand underline"
            href="https://openrouter.ai/"
            target="_blank"
            rel="noreferrer noopener"
          >
            OpenRouter
          </a>
          , que a su vez lo reenvía al proveedor del modelo de lenguaje que esté
          configurado en ese momento. Esto es lo que viaja en cada mensaje, sin
          excepción:
        </p>
        <LegalList
          items={[
            'Tu nombre, el nombre de tu negocio, tu rubro, tu moneda, tu meta mensual de ingresos y tu plan.',
            'El sueldo mensual que quieres ganar, las horas disponibles al mes y tu valor hora calculado.',
            'Los totales del último mes con movimientos: ingresos, comisiones de medios de pago, ingresos netos de esas comisiones, gastos, balance y número de movimientos.',
            'Tus últimas 10 transacciones, cada una con su fecha, tipo, categoría, título y monto. En las que lo tengan anotado, además: con qué documento respaldaste el ingreso (boleta de venta, boleta de honorarios o sin documento) y la comisión que te descontó el medio de pago.',
            'Cuántos productos y cuántos materiales tienes registrados en el inventario. Solo esas dos cuentas: ni los nombres, ni los precios, ni el stock, ni los proveedores.',
            'Los últimos 6 mensajes de la conversación en curso, tuyos y del asistente.',
            'Dos cabeceras técnicas que identifican a la app ante OpenRouter.',
          ]}
        />
        <p>
          <strong>Esto importa por dos motivos.</strong> El primero: el título de una
          transacción es texto libre y mucha gente escribe ahí el nombre de un cliente
          («Pedido de Juana»). Si lo haces, ese nombre sale hacia OpenRouter. Si
          prefieres evitarlo, usa títulos genéricos. El segundo: OpenRouter es un
          enrutador, no el modelo; el proveedor que finalmente procesa el texto es
          configurable y puede cambiar. Puedes revisar la{' '}
          <a
            className="text-brand underline"
            href="https://openrouter.ai/privacy"
            target="_blank"
            rel="noreferrer noopener"
          >
            política de privacidad de OpenRouter
          </a>{' '}
          y su{' '}
          <a
            className="text-brand underline"
            href="https://openrouter.ai/docs/features/privacy-and-logging"
            target="_blank"
            rel="noreferrer noopener"
          >
            documentación sobre registro de datos
          </a>
          .
        </p>
        {/* El lector solo manda texto a un tercero con el callable desplegado.
            Mientras no lo esté, prometer que «sale» sería falso en la dirección
            contraria a la habitual: alarmar con un envío que no ocurre. */}
        {FUNCIONES_APP.lectorBoletas &&
          (FUNCIONES_APP.ordenadoDeBoletasEnServidor ? (
            <p>
              Por este mismo camino sale una segunda cosa, y solo si la pides: el{' '}
              <strong>texto que la app lee de una boleta</strong> con el lector del
              punto 2.6, para ordenarlo en artículos de inventario. Sale el texto
              reconocido, nunca la imagen, y no se guarda como conversación.
            </p>
          ) : (
            <p>
              Por este mismo camino saldría una segunda cosa el día que activemos
              el paso de ordenado del punto 2.6: el{' '}
              <strong>texto que la app lee de una boleta</strong>, para convertirlo
              en artículos de inventario. Saldría el texto reconocido, nunca la
              imagen, y no se guardaría como conversación.{' '}
              <strong>Hoy no sale</strong>: ese paso no está activo y el lector
              trabaja entero dentro de tu teléfono.
            </p>
          ))}
        <p>
          Si no quieres que esta información salga hacia un tercero, no uses el
          asistente
          {FUNCIONES_APP.ordenadoDeBoletasEnServidor
            ? ' ni el lector de boletas'
            : ''}
          : el resto de la app (transacciones, inventario, valor hora, resúmenes)
          funciona sin{' '}
          {FUNCIONES_APP.ordenadoDeBoletasEnServidor ? 'ellos' : 'él'} y no envía
          nada a OpenRouter.
        </p>

        <h3 className="font-semibold text-text-primary pt-2">
          5.3 A quién NO se los damos
        </h3>
        <LegalList
          items={[
            'No vendemos ni arrendamos tus datos a nadie.',
            'No los compartimos con anunciantes, redes publicitarias ni intermediarios de datos.',
            'No los compartimos con otros usuarios: cada cuenta solo puede leer y escribir sus propios datos.',
            'Solo los entregaríamos a una autoridad si una orden judicial o legal válida nos obligara.',
          ]}
        />
      </LegalSection>

      <LegalSection id="retencion" title="6. Cuánto tiempo los conservamos">
        <LegalList
          items={[
            'Los datos de tu cuenta, tu perfil, tus transacciones, tu inventario y tus conversaciones se conservan mientras tu cuenta exista.',
            <>
              Cuando pides la eliminación de tu cuenta, los borramos en un plazo máximo
              de {DELETION_SLA_DAYS} días.
            </>,
            <>
              Las copias de respaldo técnicas de la base de datos pueden tardar hasta{' '}
              {BACKUP_RETENTION_DAYS} días más en expirar. Durante ese tiempo los datos
              ya no son accesibles desde la app ni se usan para nada.
            </>,
            ...(FUNCIONES_APP.lectorBoletas
              ? [
                  'Las imágenes de boletas no se conservan ningún tiempo, porque no se guardan en ningún momento: no hay nada que expire ni que haya que borrar después.',
                ]
              : []),
            'Tu inscripción en la lista de espera se conserva hasta el lanzamiento de la app o hasta que pidas que la borremos, lo que ocurra primero.',
            'Los registros técnicos de las llamadas al servidor (fecha, función invocada y errores) se conservan según la retención por defecto de Google Cloud Logging y no se usan para identificarte.',
          ]}
        />
      </LegalSection>

      <LegalSection id="derechos" title="7. Tus derechos y cómo ejercerlos">
        <p>
          Conforme a la Ley 19.628 sobre protección de la vida privada y a la Ley 21.719
          que la moderniza en Chile, tienes derecho a:
        </p>
        <LegalList
          items={[
            <>
              <strong>Acceder</strong> a los datos que tenemos sobre ti y pedir una copia.
            </>,
            <>
              {/* Esta frase decía que las cuatro cosas se editaban «en cualquier
                  momento» y tres eran falsas: ninguna pantalla llama a
                  `updateTransaction`, `FinancesRepository` no tiene ningún método
                  para actualizar un gasto fijo (solo `addFixedExpense` y
                  `deleteFixedExpense`) y del inventario solo se puede ajustar el
                  stock o borrar la ficha. Lo que sí existe es editar el perfil
                  (`editar_perfil_screen.dart`) y repetir el cálculo del valor hora
                  (`hourly_rate_setup_page.dart`), los dos desde Configuración. El
                  derecho se cumple igual: lo que no puede corregir el usuario lo
                  corregimos nosotros, y eso es lo que ahora dice la frase. */}
              <strong>Rectificar</strong> los que estén equivocados. Tu perfil y tu
              valor hora los cambias tú desde la app, en Perfil → Configuración. Una
              transacción o un gasto fijo mal anotado se corrige borrándolo y
              volviéndolo a anotar.
              {FUNCIONES_APP.fichaInventarioCompleta
                ? ' De tu inventario puedes editar la ficha completa, ajustar el stock o borrarla.'
                : ' De tu inventario puedes ajustar el stock o borrar la ficha.'}{' '}
              Si hay algo que no puedas corregir tú, escríbenos y lo corregimos
              nosotros.
            </>,
            <>
              <strong>Eliminar</strong> tu cuenta y todos los datos asociados.
            </>,
            <>
              <strong>Oponerte</strong> a que tus datos salgan hacia el proveedor del
              modelo de lenguaje: basta con no usar el asistente.
            </>,
            <>
              <strong>Pedir que te entreguemos tus datos</strong> en un formato legible
              para llevártelos a otro servicio.
            </>,
          ]}
        />
        <p>
          Para ejercer cualquiera de estos derechos escribe a{' '}
          <strong>{CONTACTO_PRIVACIDAD}</strong> desde el correo con el que creaste la
          cuenta. Te responderemos en un plazo máximo de {DELETION_SLA_DAYS} días. Si
          lo que quieres es borrar tu cuenta, la página de{' '}
          <a className="text-brand underline" href={siteUrl(LEGAL_ROUTES.eliminarCuenta)}>
            eliminación de cuenta y datos
          </a>{' '}
          explica el procedimiento paso a paso.
        </p>
      </LegalSection>

      <LegalSection id="seguridad" title="8. Seguridad">
        <LegalList
          items={[
            'Todo el tráfico entre la app y el servidor va cifrado con TLS.',
            'Las reglas de seguridad de Firestore están escritas para que cada cuenta solo pueda leer y escribir los documentos que cuelgan de su propio identificador de usuario.',
            'Las conversaciones del asistente y los resúmenes mensuales solo los puede escribir el servidor, nunca la app.',
            'La clave de acceso al proveedor del modelo vive en el gestor de secretos del servidor y no se incluye en la app que instalas.',
          ]}
        />
        <p>
          Ningún sistema es infalible. Si detectamos una vulneración que afecte a tus
          datos personales, te lo comunicaremos al correo de tu cuenta.
        </p>
      </LegalSection>

      <LegalSection id="menores" title="9. Menores de edad">
        <p>
          {APP_NAME} está dirigida a personas que gestionan un negocio o un trabajo
          independiente y no está diseñada para menores de 18 años. No recogemos datos
          de menores a sabiendas. Si crees que un menor ha creado una cuenta, escríbenos
          a {CONTACTO_PRIVACIDAD} y la eliminaremos.
        </p>
      </LegalSection>

      <LegalSection id="cambios" title="10. Cambios en esta política">
        <p>
          Si cambiamos qué datos recogemos o con quién los compartimos, actualizaremos
          este documento, subiremos su número de versión y, cuando el cambio sea
          relevante, te avisaremos dentro de la app o por correo antes de que entre en
          vigor.
        </p>
      </LegalSection>

      <LegalSection id="contacto" title="11. Contacto">
        <p>
          Privacidad y ejercicio de derechos: <strong>{CONTACTO_PRIVACIDAD}</strong>
          <br />
          Soporte general: <strong>{CONTACTO_SOPORTE}</strong>
          <br />
          Responsable:{' '}
          {RESPONSABLE_IDENTIFICADO
            ? `${RESPONSIBLE.legalName}, ${RESPONSIBLE.address}, ${RESPONSIBLE.country}`
            : RESPONSABLE_SIN_IDENTIFICAR}
        </p>
      </LegalSection>
    </LegalLayout>
  );
}
