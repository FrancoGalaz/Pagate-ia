// Política de privacidad de Págate-IA (tarea P-08).
//
// Cada dato que se enumera aquí fue verificado contra el código, no inventado:
//   · perfil y valor hora  → lib/features/user_profile/data/models/
//   · transacciones y gastos fijos → lib/features/finances/data/models/
//   · inventario → lib/features/inventory/data/models/
//   · lo que sale hacia OpenRouter → functions/src/prompt.ts y chat.ts
//   · lista de espera → functions/src/waitlist.ts
// Si se añade un campo nuevo al modelo de datos, hay que añadirlo aquí: el
// formulario de Seguridad de Datos de Google Play exige que coincidan.

import LegalLayout, { LegalList, LegalSection } from './LegalLayout';
import {
  APP_NAME,
  BACKUP_RETENTION_DAYS,
  CONTACT,
  DELETION_SLA_DAYS,
  LEGAL_ROUTES,
  RESPONSIBLE,
  siteUrl,
} from '../content/legal-meta';

export default function PrivacidadPage() {
  return (
    <LegalLayout
      title="Política de privacidad"
      intro={`Este documento explica qué datos recoge ${APP_NAME}, dónde se guardan, con quién se comparten, cuánto tiempo se conservan y cómo puedes ejercer tus derechos sobre ellos.`}
    >
      <LegalSection id="responsable" title="1. Quién es responsable de tus datos">
        <p>
          El responsable del tratamiento de los datos personales que se describen en
          este documento es {RESPONSIBLE.legalName}, RUT {RESPONSIBLE.taxId}, con
          domicilio en {RESPONSIBLE.address}, {RESPONSIBLE.country}.
        </p>
        <p>
          Para cualquier consulta sobre privacidad puedes escribir a{' '}
          <strong>{CONTACT.privacy}</strong>.
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
              <strong>Gastos fijos</strong>: nombre y monto de cada uno.
            </>,
            <>
              <strong>Inventario</strong>: nombre del producto o material, tipo, precio,
              stock actual, stock mínimo, unidad de medida y, si los indicas, proveedor
              y código interno.
            </>,
            <>
              <strong>Resúmenes mensuales</strong> que el servidor calcula a partir de
              tus transacciones: ingresos, gastos y número de movimientos por mes.
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
              Un <strong>contador de uso diario</strong> para aplicar el límite de
              mensajes de tu plan.
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

        <h3 className="font-semibold text-text-primary pt-2">2.6 Qué NO recogemos</h3>
        <LegalList
          items={[
            'No hay publicidad ni identificadores publicitarios.',
            'No hay SDK de analítica ni de seguimiento de uso.',
            'No se accede a tus contactos, tu ubicación, tu cámara, tu micrófono ni tus archivos.',
            'No se conecta a tus cuentas bancarias y no se leen tus movimientos reales: todo lo que ves en la app lo escribes tú.',
          ]}
        />
      </LegalSection>

      <LegalSection id="uso" title="3. Para qué usamos estos datos">
        <LegalList
          items={[
            'Crear tu cuenta y permitirte entrar.',
            'Mostrarte tus ingresos, gastos, resúmenes mensuales e inventario.',
            'Calcular tu valor hora y comparar tus ingresos con tu meta mensual.',
            'Dar contexto al asistente para que sus respuestas se refieran a tu negocio y no a un caso genérico.',
            'Aplicar el límite diario de mensajes del asistente y evitar abusos del servicio.',
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
            'Los totales del último mes con movimientos: ingresos, gastos, balance y número de movimientos.',
            'Tus últimas 10 transacciones, cada una con su fecha, tipo, categoría, título y monto.',
            'Cuántos productos y cuántos materiales tienes registrados en el inventario.',
            'Los últimos 20 mensajes de la conversación en curso, tuyos y del asistente.',
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
        <p>
          Si no quieres que esta información salga hacia un tercero, no uses el
          asistente: el resto de la app (transacciones, inventario, valor hora,
          resúmenes) funciona sin él y no envía nada a OpenRouter.
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
              <strong>Rectificar</strong> los que estén equivocados. Tu perfil, tus
              transacciones, tus gastos fijos y tu inventario los puedes editar tú mismo
              desde la app en cualquier momento.
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
          <strong>{CONTACT.privacy}</strong> desde el correo con el que creaste la
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
          a {CONTACT.privacy} y la eliminaremos.
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
          Privacidad y ejercicio de derechos: <strong>{CONTACT.privacy}</strong>
          <br />
          Soporte general: <strong>{CONTACT.support}</strong>
          <br />
          Responsable: {RESPONSIBLE.legalName}, {RESPONSIBLE.address},{' '}
          {RESPONSIBLE.country}
        </p>
      </LegalSection>
    </LegalLayout>
  );
}
