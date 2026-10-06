// Página pública de solicitud de eliminación de cuenta y datos (tarea P-07).
//
// Google Play exige DOS caminos para toda app con cuentas: uno dentro de la
// app y además una URL web accesible SIN iniciar sesión, cuya dirección se
// declara en Play Console → Seguridad de los datos → Eliminación de cuenta.
// Esta página es la segunda. No pide credenciales ni formulario con datos
// personales a propósito: un formulario público que acepte un correo es un
// vector de borrado ajeno, así que la solicitud se hace por correo desde la
// dirección de la cuenta, que es lo que nos permite verificar quién la pide.
//
// La lista de «qué se borra» está derivada del modelo de datos real
// (docs/ARQUITECTURA.md y firestore.rules), no de una plantilla.

import LegalLayout, { LegalList, LegalSection } from './LegalLayout';
import {
  ANDROID_PACKAGE,
  APP_NAME,
  BACKUP_RETENTION_DAYS,
  BUZON,
  CANAL_ALTERNATIVO,
  DELETION_SLA_DAYS,
  LEGAL_ROUTES,
  siteUrl,
} from '../content/legal-meta';

/** Asunto prellenado del correo, para que la solicitud llegue identificable. */
const MAIL_SUBJECT = encodeURIComponent(
  `Solicitud de eliminación de cuenta y datos — ${APP_NAME}`,
);

const MAIL_BODY = encodeURIComponent(
  [
    `Solicito la eliminación de mi cuenta de ${APP_NAME} y de todos los datos asociados.`,
    '',
    'Correo de la cuenta: (escribe aquí el correo con el que te registraste)',
    '',
    'Entiendo que esta acción es irreversible y que perderé mis transacciones,',
    'mi inventario y mis conversaciones con el asistente.',
  ].join('\n'),
);

export default function EliminarCuentaPage() {
  return (
    <LegalLayout
      title="Eliminar tu cuenta y tus datos"
      intro={`Esta página explica cómo pedir la eliminación definitiva de tu cuenta de ${APP_NAME} y de todo lo que hayas registrado en ella. No necesitas tener la app instalada ni iniciar sesión para solicitarlo.`}
    >
      <LegalSection id="app" title="De qué aplicación hablamos">
        <p>
          Esta página corresponde a <strong>{APP_NAME}</strong>, la aplicación de gestión
          financiera para artesanos y microemprendedores publicada en Google Play con el
          identificador <code>{ANDROID_PACKAGE}</code>.
        </p>
      </LegalSection>

      <LegalSection id="como" title="Cómo solicitarlo">
        <p>
          Escríbenos un correo desde <strong>la misma dirección con la que creaste tu
          cuenta</strong>. Ese es el único requisito: nos permite comprobar que la
          solicitud la haces tú y no un tercero.
        </p>

        {/* El botón `mailto:` solo se renderiza si hay un buzón publicado. Con
            el marcador sin rellenar, `mailto:[CORREO…]` sería un enlace roto que
            abre el cliente de correo con un destinatario inválido: peor que no
            ofrecer el botón. En ese caso se nombra el canal que sí existe, el
            correo del desarrollador que Google Play publica en la ficha. */}
        {BUZON.privacidad ? (
          <>
            <p>
              <a
                className="inline-flex items-center justify-center px-5 py-3 rounded-lg bg-brand text-white font-semibold text-sm hover:bg-brand-dark transition-colors"
                href={`mailto:${BUZON.privacidad}?subject=${MAIL_SUBJECT}&body=${MAIL_BODY}`}
              >
                Escribir para pedir la eliminación
              </a>
            </p>
            <p>
              Si el botón no abre tu cliente de correo, envía el mensaje manualmente a{' '}
              <strong>{BUZON.privacidad}</strong> con el asunto «Solicitud de
              eliminación de cuenta y datos» e indica el correo de tu cuenta.
            </p>
          </>
        ) : (
          <p>
            Envía el mensaje a {CANAL_ALTERNATIVO}, con el asunto «Solicitud de
            eliminación de cuenta y datos», e indica el correo de tu cuenta. En cuanto
            haya un buzón de privacidad propio aparecerá aquí, en esta misma página.
          </p>
        )}

        <p>
          Confirmaremos la recepción y te avisaremos cuando el borrado esté hecho.
        </p>
      </LegalSection>

      <LegalSection id="que-se-borra" title="Qué se borra">
        <p>Se eliminan de forma definitiva:</p>
        <LegalList
          items={[
            'Tu cuenta de acceso, con el correo y la credencial asociada.',
            'Tu perfil: nombre, nombre del negocio, rubro, moneda y meta mensual de ingresos.',
            'Tu cálculo de valor hora: sueldo deseado, horas disponibles y valor hora resultante.',
            'Todas tus transacciones, con su título, descripción, monto, categoría y fecha.',
            'Todos tus gastos fijos.',
            'Todo tu inventario: productos, materiales, precios, stock, proveedores y códigos.',
            'Todos los resúmenes mensuales calculados a partir de tus movimientos.',
            'Todas tus conversaciones con el asistente, incluidos tus mensajes y las respuestas que recibiste.',
            'El contador de uso del asistente.',
            'Tu inscripción en la lista de espera de este sitio, si coincide con el correo de la cuenta.',
          ]}
        />
      </LegalSection>

      <LegalSection id="que-no-se-borra" title="Qué no se borra, y por qué">
        <LegalList
          items={[
            <>
              <strong>Copias de respaldo técnicas.</strong> La base de datos genera
              respaldos automáticos que pueden tardar hasta {BACKUP_RETENTION_DAYS} días
              en expirar. En ese período tus datos ya no son accesibles desde la app ni
              se usan para nada, y después desaparecen solos.
            </>,
            <>
              <strong>Registros técnicos del servidor.</strong> Fecha, función invocada y
              errores. No contienen el contenido de tus transacciones ni de tus
              conversaciones y se conservan según la retención por defecto del proveedor
              de infraestructura.
            </>,
            <>
              <strong>Lo que ya procesó el proveedor del modelo de lenguaje.</strong> Si
              usaste el asistente, el texto de contexto salió hacia OpenRouter y el
              proveedor del modelo en su momento. No podemos borrar lo que esté en sus
              sistemas; su retención se rige por sus propias políticas, enlazadas en
              nuestra{' '}
              <a
                className="text-brand underline"
                href={siteUrl(LEGAL_ROUTES.privacidad)}
              >
                política de privacidad
              </a>
              .
            </>,
          ]}
        />
      </LegalSection>

      <LegalSection id="plazo" title="En cuánto tiempo">
        <LegalList
          items={[
            'Confirmamos la recepción de tu solicitud dentro de los 5 días hábiles siguientes.',
            <>
              Completamos el borrado en un plazo máximo de {DELETION_SLA_DAYS} días
              corridos desde la solicitud.
            </>,
            <>
              Las copias de respaldo expiran en hasta {BACKUP_RETENTION_DAYS} días
              adicionales.
            </>,
          ]}
        />
      </LegalSection>

      <LegalSection id="irreversible" title="Es irreversible">
        <p>
          Una vez borrada, la cuenta no se puede recuperar y los datos no se pueden
          restaurar. Si solo quieres dejar de usar la app por un tiempo, basta con
          cerrar sesión. Si quieres conservar tus números, exporta o anota lo que
          necesites antes de pedir el borrado.
        </p>
      </LegalSection>

      <LegalSection id="parcial" title="Si solo quieres borrar una parte">
        <p>
          No hace falta eliminar la cuenta para deshacerte de datos concretos. Desde la
          propia app puedes borrar transacciones, gastos fijos e ítems de inventario uno
          a uno. Si quieres que borremos únicamente tu historial de conversaciones con
          el asistente y conservar el resto, pídelo en el mismo correo indicándolo
          expresamente.
        </p>
      </LegalSection>

      <LegalSection id="contacto" title="Contacto">
        <p>
          Solicitudes de eliminación y privacidad:{' '}
          <strong>{BUZON.privacidad ?? CANAL_ALTERNATIVO}</strong>
          <br />
          Soporte general: <strong>{BUZON.soporte ?? CANAL_ALTERNATIVO}</strong>
        </p>
      </LegalSection>
    </LegalLayout>
  );
}
