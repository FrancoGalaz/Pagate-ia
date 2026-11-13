// PROPÓSITO: fijar los dos requisitos de la política de Google Play para apps
// con IA generativa, que la pestaña de IA no cumplía (P-12).
//
//  (a) El usuario tiene que poder saber que el contenido lo genera una IA sin
//      tener que investigarlo. Por eso el aviso vive fijo bajo la cabecera del
//      chat y es un literal comprobable.
//  (b) Tiene que haber un mecanismo DENTRO de la app para reportar o marcar
//      contenido ofensivo, sin salir de ella. Los motivos de reporte son la
//      parte comprobable sin montar Firestore.
//
// Lo que no se prueba aquí y por qué: montar `IaTab` exige un `AiProvider`
// vivo, que abre un stream de Firestore en su constructor. La pestaña
// completa se verificó a mano contra los emuladores (aviso visible, acción de
// reporte solo bajo las respuestas del asistente, reporte guardado).

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/tabs/ia_tab.dart';
import 'package:pagate_ia/features/dashboard/presentation/providers/ai_provider.dart';

void main() {
  group('aviso de IA generativa', () {
    test('dice que responde una IA y que puede equivocarse', () {
      final texto = kAiDisclosureText.toLowerCase();
      // Las dos mitades del requisito, por separado: un aviso que solo diga
      // "esto es una IA" no advierte de nada, y uno que solo diga "puede
      // fallar" no identifica quién responde.
      expect(texto, contains('ia'));
      expect(texto, anyOf(contains('error'), contains('equivoc')));
      expect(kAiDisclosureText.trim(), isNotEmpty);
    });
  });

  group('motivos de reporte', () {
    test('hay una opción explícita para contenido ofensivo', () {
      // Es la que Play nombra. Si desaparece, el mecanismo deja de cubrir el
      // caso por el que existe.
      expect(
        AiReportReason.values.map((final r) => r.id),
        contains('ofensivo'),
      );
      expect(
        AiReportReason.ofensivo.label.toLowerCase(),
        contains('ofensivo'),
      );
    });

    test('cada motivo tiene id estable y etiqueta legible', () {
      final ids = <String>{};
      for (final motivo in AiReportReason.values) {
        expect(motivo.id.trim(), isNotEmpty, reason: motivo.name);
        expect(motivo.label.trim(), isNotEmpty, reason: motivo.name);
        // El id es lo que se persiste: no puede repetirse entre dos motivos.
        expect(ids.add(motivo.id), isTrue, reason: 'id repetido: ${motivo.id}');
      }
      expect(AiReportReason.values.length, greaterThanOrEqualTo(2));
    });
  });

  group('topes del reporte', () {
    test('el comentario y el fragmento citado están acotados', () {
      // Sin tope, un reporte podría llevarse una respuesta entera de varios
      // miles de caracteres a un documento que paga el dueño.
      expect(AiProvider.maxReportCommentChars, greaterThan(0));
      expect(AiProvider.maxReportedTextChars, greaterThan(0));
      expect(AiProvider.aiReportsCollection, isNotEmpty);
    });
  });
}
