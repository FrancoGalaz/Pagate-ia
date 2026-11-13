// Términos de servicio de Págate-IA (tarea P-10).
//
// La sección 4 («Qué NO es Págate-IA») no es relleno legal: es la que decide
// cómo clasifica Google Play la app. Verificado en el código que la app no
// mueve dinero: functions/src/index.ts solo exporta `chat`,
// `onTransactionWritten` y `waitlist`, y no hay pasarela de pago, saldo ni
// transferencia en todo lib/. Si alguna vez se añade un cobro, esta sección
// hay que reescribirla ANTES de publicar la versión que lo incluya.

import LegalLayout, { LegalList, LegalSection } from './LegalLayout';
import {
  APP_NAME,
  BUZON,
  CANAL_ALTERNATIVO,
  LEGAL_ROUTES,
  RESPONSABLE_IDENTIFICADO,
  RESPONSABLE_SIN_IDENTIFICAR,
  RESPONSIBLE,
  siteUrl,
} from '../content/legal-meta';

// Ver la nota de legal-meta.ts: mientras el buzón sea un marcador se nombra el
// canal que sí existe, en vez de imprimir corchetes.
const CONTACTO_SOPORTE = BUZON.soporte ?? CANAL_ALTERNATIVO;

export default function TerminosPage() {
  return (
    <LegalLayout
      title="Términos de servicio"
      intro={`Estas son las condiciones bajo las que puedes usar ${APP_NAME}. Al crear una cuenta las aceptas, así que vale la pena leerlas: son cortas y están escritas para entenderse.`}
    >
      <LegalSection id="quienes" title="1. Quién presta el servicio">
        {RESPONSABLE_IDENTIFICADO ? (
          <p>
            {APP_NAME} es un servicio prestado por {RESPONSIBLE.legalName}, RUT{' '}
            {RESPONSIBLE.taxId}, con domicilio en {RESPONSIBLE.address},{' '}
            {RESPONSIBLE.country}. Puedes contactarnos en {CONTACTO_SOPORTE}.
          </p>
        ) : (
          <p>
            {APP_NAME} es un servicio prestado por {RESPONSABLE_SIN_IDENTIFICAR}. Su
            nombre completo, RUT y domicilio se publican en esta misma página en cuanto
            estén definidos. Puedes contactarnos en {CONTACTO_SOPORTE}.
          </p>
        )}
      </LegalSection>

      <LegalSection id="que-es" title="2. Qué es Págate-IA">
        <p>
          {APP_NAME} es una aplicación de <strong>gestión y orientación</strong> para
          artesanos, microemprendedores y talleres pequeños. Te deja registrar tus
          ingresos y gastos, llevar tu inventario, calcular cuánto vale tu hora de
          trabajo y conversar con un asistente que te ayuda a interpretar esos números.
        </p>
      </LegalSection>

      <LegalSection id="cuenta" title="3. Tu cuenta">
        <LegalList
          items={[
            'Necesitas una cuenta para usar la app. Debes ser mayor de 18 años y dar datos veraces.',
            'Eres responsable de mantener tu contraseña en secreto y de la actividad que ocurra en tu cuenta.',
            'Una cuenta es para una persona. No la compartas.',
            <>
              Puedes cerrar tu cuenta cuando quieras. El procedimiento está en la página
              de{' '}
              <a
                className="text-brand underline"
                href={siteUrl(LEGAL_ROUTES.eliminarCuenta)}
              >
                eliminación de cuenta y datos
              </a>
              .
            </>,
          ]}
        />
      </LegalSection>

      <LegalSection id="no-es" title="4. Qué NO es Págate-IA">
        <p>
          Esto es lo más importante de este documento. Lee los cuatro puntos.
        </p>
        <LegalList
          items={[
            <>
              <strong>
                No es asesoría financiera, contable ni tributaria profesional.
              </strong>{' '}
              Lo que la app calcula y lo que el asistente responde es{' '}
              <strong>orientación informativa de carácter general</strong>. No sustituye
              a un contador, a un asesor tributario ni a un abogado. Antes de declarar
              impuestos, emitir documentos tributarios o tomar una decisión importante,
              consulta a un profesional.
            </>,
            <>
              <strong>No mueve dinero y no procesa pagos.</strong> {APP_NAME} no
              transfiere fondos, no mantiene saldos, no emite medios de pago, no cobra a
              tus clientes y no es una billetera ni una cuenta. Los montos que ves son
              anotaciones tuyas sobre operaciones que ocurrieron fuera de la app.
            </>,
            <>
              <strong>No se conecta a tus cuentas bancarias.</strong> No leemos tus
              movimientos reales ni tenemos acceso a ninguna institución financiera. Todo
              lo que la app sabe de tu negocio lo escribiste tú.
            </>,
            <>
              <strong>No es un sistema de facturación electrónica.</strong> No emite
              boletas ni facturas ante el Servicio de Impuestos Internos ni ante ninguna
              autoridad tributaria, y los informes que puedas exportar no tienen validez
              tributaria.
            </>,
          ]}
        />
      </LegalSection>

      <LegalSection id="asistente" title="5. El asistente de inteligencia artificial">
        <LegalList
          items={[
            'Las respuestas del asistente las genera un modelo de lenguaje. Pueden contener errores, cifras equivocadas o afirmaciones desactualizadas. Verifica siempre antes de actuar.',
            'El asistente usa como contexto los datos de tu negocio que tengas registrados. Qué datos salen exactamente y hacia dónde está detallado en la política de privacidad.',
            'El asistente tiene un límite de mensajes. En las cuentas gratuitas es un número total, no una cuota diaria: cuando se agota no se renueva al día siguiente. La app te lo dice en ese momento, y el resto de la app sigue funcionando igual.',
            'Puedes reportar cualquier respuesta del asistente con el botón que lleva cada mensaje.',
            'No uses el asistente para obtener instrucciones sobre asuntos legales, médicos o tributarios concretos: no está hecho para eso y puede equivocarse.',
          ]}
        />
      </LegalSection>

      <LegalSection id="uso-aceptable" title="6. Uso aceptable">
        <p>No puedes usar {APP_NAME} para:</p>
        <LegalList
          items={[
            'Actividades ilegales, ni para registrar o encubrir operaciones ilícitas.',
            'Intentar acceder a datos de otras cuentas, a nuestros servidores o a nuestras claves.',
            'Llamar al servidor de forma automatizada fuera de la app, saltarse los límites de uso o consumir el servicio de forma abusiva.',
            'Subir datos personales de terceros que no tengas derecho a tratar.',
            'Revender el servicio o presentarlo como propio.',
          ]}
        />
        <p>
          Si incumples estas reglas podemos suspender o cerrar tu cuenta, avisándote al
          correo asociado salvo que la gravedad del caso lo impida.
        </p>
      </LegalSection>

      <LegalSection id="datos" title="7. Tus datos siguen siendo tuyos">
        <p>
          Lo que registras en {APP_NAME} es tuyo. No reclamamos ninguna propiedad sobre
          tus transacciones, tu inventario ni tus conversaciones. Solo los tratamos para
          prestarte el servicio, en los términos de la{' '}
          <a className="text-brand underline" href={siteUrl(LEGAL_ROUTES.privacidad)}>
            política de privacidad
          </a>
          , que forma parte de estos términos.
        </p>
      </LegalSection>

      <LegalSection id="planes" title="8. Planes y pagos">
        <p>
          Hoy {APP_NAME} se ofrece de forma gratuita y{' '}
          <strong>no existe ninguna función de pago ni suscripción activa</strong>. Si en
          el futuro se introduce un plan pagado, sus condiciones, su precio y su forma de
          cancelación se publicarán antes de que puedas contratarlo, y el cobro se hará a
          través del sistema de facturación de Google Play.
        </p>
      </LegalSection>

      <LegalSection id="disponibilidad" title="9. Disponibilidad del servicio">
        <p>
          {APP_NAME} se ofrece «tal como está». Nos esforzamos por mantenerlo
          funcionando, pero no garantizamos disponibilidad ininterrumpida ni ausencia de
          errores. Podemos cambiar, suspender o descontinuar funciones; si una
          descontinuación afecta tus datos, te avisaremos con antelación razonable para
          que puedas exportarlos.
        </p>
        <p>
          Te recomendamos no usar {APP_NAME} como único registro de tu contabilidad:
          guarda también tus respaldos.
        </p>
      </LegalSection>

      <LegalSection id="responsabilidad" title="10. Límite de responsabilidad">
        <p>
          En la medida que lo permita la ley chilena, no respondemos por pérdidas
          derivadas de decisiones de negocio que tomes a partir de la información o las
          sugerencias de la app, ni por lucro cesante, ni por la pérdida de datos causada
          por fallos de los proveedores de infraestructura. Nada en esta cláusula limita
          los derechos que la ley te reconoce como consumidor y que no pueden excluirse.
        </p>
      </LegalSection>

      <LegalSection id="cambios" title="11. Cambios en estos términos">
        <p>
          Podemos actualizar estos términos. Cuando el cambio sea relevante subiremos el
          número de versión y te avisaremos dentro de la app o por correo. Si no estás de
          acuerdo con la nueva versión, puedes cerrar tu cuenta.
        </p>
      </LegalSection>

      <LegalSection id="ley" title="12. Ley aplicable">
        <p>
          Estos términos se rigen por las leyes de {RESPONSIBLE.country}. Cualquier
          controversia se someterá a los tribunales competentes de{' '}
          {RESPONSIBLE.country}.
        </p>
      </LegalSection>

      <LegalSection id="contacto" title="13. Contacto">
        <p>
          Dudas sobre estos términos: <strong>{CONTACTO_SOPORTE}</strong>
        </p>
      </LegalSection>
    </LegalLayout>
  );
}
