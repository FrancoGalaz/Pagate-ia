/// PROPÓSITO: decidir si el texto que llegó de un Cloud Function callable se
/// le puede enseñar a una persona.
///
/// Cuando el backend lanza un `HttpsError`, su mensaje viaja intacto hasta el
/// cliente y está escrito para quien usa la app. Pero cuando el fallo lo
/// genera la propia infraestructura, el SDK rellena `message` con el marcador
/// del código en mayúsculas y sin espacios —'INTERNAL', 'UNAVAILABLE',
/// 'DEADLINE_EXCEEDED'—, que no significa nada fuera de una consola.
///
/// Los dos servicios que llaman a un callable ([AiService] y
/// [AccountService]) necesitan la misma decisión, así que vive aquí y no
/// duplicada: el mensaje del servidor manda siempre que sea legible, y solo
/// si no lo es entra el respaldo local de cada servicio.
library;

/// `true` si [message] parece un texto redactado para una persona.
///
/// El criterio es el que separa un mensaje del backend de un marcador del
/// SDK: un texto redactado tiene espacios y minúsculas, y los marcadores no.
bool isHumanCallableMessage(final String? message) {
  final text = message?.trim();
  if (text == null || text.length < 12) return false;
  if (!text.contains(' ')) return false;
  return text != text.toUpperCase();
}
