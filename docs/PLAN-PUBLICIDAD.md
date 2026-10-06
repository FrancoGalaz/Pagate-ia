# Plan de difusión — Págate-IA

Plan para una persona sola, sin presupuesto de medios y sin equipo. Escrito el
**6 de octubre de 2026**.

Todo lo que hay aquí lo puede ejecutar el dueño con su teléfono, un cuaderno y
menos de 100.000 pesos al mes. No hay agencia, no hay community manager y no hay
«estrategia de contenidos omnicanal». Hay cuatro canales, un calendario de seis
semanas y cinco números que mirar.

> ### Cómo leer las cifras de este documento
>
> Hay dos clases de número aquí dentro y **no valen lo mismo**:
>
> - **Hechos verificados.** Llevan su enlace al lado, en el párrafo donde
>   aparecen: la normativa del SII, las fechas de la Muestra UC, el curso de
>   Sercotec, las postulaciones al Sello de Excelencia y todas las cifras de los
>   competidores (que están en `docs/COMPETENCIA.md`, con el método y la fecha
>   de lectura).
> - **Estimaciones de trabajo.** Todo lo que este documento llama «cuesta» y
>   «rinde» por canal, lo que cuesta imprimir las tarjetas y la expectativa de
>   correos del §5 van marcados **(estimación sin fuente)**. No salen de ningún
>   estudio, de ninguna medición propia y de ningún dato del sector: son
>   órdenes de magnitud para dimensionar el esfuerzo y decidir qué probar.
>   **No se publican, no se le dicen a nadie y no se usan para prometer nada.**
>   En cuanto haya tres semanas de datos reales en la hoja del §5, se sustituyen
>   por lo que de verdad pase.
>
> Si un número no está en ninguno de los dos grupos, es que sobra y hay que
> quitarlo.

---

## 0. El bloqueo que va primero que todo

**Hoy la lista de espera no funciona.** El formulario de la landing hace `POST` a
`https://southamerica-west1-pagate-17211.cloudfunctions.net/waitlist`
(`landing/.env.production`), y esa función **no está desplegada**: el proyecto de
Firebase `pagate-17211` está vacío, con la API de Firestore deshabilitada y sin
funciones (verificado en `docs/AUDITORIA-2026-09-29.md` §1). Cualquiera que entre
hoy y deje su correo recibe un error.

Consecuencia práctica: **no gastes ni un peso ni una hora en traer tráfico hasta
que el formulario guarde de verdad un registro y lo hayas comprobado tú mismo
desde el teléfono.** Traer 200 visitas a un formulario roto no es un comienzo
lento, es quemar el único intento que tienes con esas 200 personas.

Lo que hay que cerrar antes de la Semana 1, y que no es trabajo de este
documento:

1. Habilitar Firestore y desplegar las funciones (consola de Firebase, es del
   dueño).
2. ~~Regenerar y publicar la landing con las páginas legales y sin las métricas
   inventadas.~~ **La carpeta ya está reconstruida; falta publicarla.**
   `landing-page/` se reconstruyó desde `landing/` y hoy contiene las tres
   páginas legales, la URL real de la función `waitlist` y ninguna de las cifras
   ni los testimonios inventados. Lo que falta no es técnico: que GitHub Pages
   sirva esa carpeta requiere que el commit llegue a `main`, y **el dueño es el
   único que puede hacer ese push**. Comprobado hoy, 6 de octubre de 2026: la
   portada responde `200` y las tres páginas legales responden **`404`**. Los
   pasos exactos —qué rama, qué comando y cómo comprobar las cuatro URLs
   después— están en **`docs/FICHA-PLAY.md` §0 bis**. Sin esto Play no acepta
   la ficha, porque exige que la URL de política de privacidad responda.
3. Rellenar los **cinco** marcadores de `landing/src/content/legal-meta.ts`. La
   lista exacta, con línea y constante, está en `docs/FICHA-PLAY.md §8`.
   Las páginas ya **no muestran corchetes** al visitante, pero eso no rellena el
   dato: sin él, la política identifica al responsable por descripción y no por
   nombre. Un correo de contacto real es además el canal por el que te van a
   escribir los primeros usuarios.
4. Probar el formulario de punta a punta y confirmar que el registro aparece en
   `waitlist/`.

### Y un plazo que condiciona el calendario entero

Si la cuenta de desarrollador de Google Play es una **cuenta personal creada
después del 13 de noviembre de 2023**, Play exige, antes de poder publicar en
abierto, haber corrido una **prueba cerrada con al menos 12 probadores
inscritos de forma continua durante 14 días**
([requisitos de prueba para cuentas personales nuevas](https://support.google.com/googleplay/android-developer/answer/14151465),
transcrito con sus términos exactos en `docs/FICHA-PLAY.md §7`). Los 14 días
tienen que ser **continuos y los más recientes**: si en algún momento bajas de 12
probadores inscritos, la cuenta empieza otra vez. Y **inscribirse no basta**: los
probadores tienen que instalar y usar la app, o la solicitud de acceso a
producción se puede rechazar por falta de participación. Las cuentas de
organización y las personales anteriores a esa fecha están exentas.

Esto cambia el orden del plan por completo: **conseguir 12 personas reales
dispuestas a instalar y usar la app no es marketing, es un requisito de
publicación**. Es la razón más fuerte para llenar la lista de espera antes de
tener la app lista, y no después.

Lo primero que debe hacer el dueño: entrar a Play Console y comprobar qué tipo
de cuenta tiene. Si es personal y nueva, hay que sumar 14 días como mínimo a
cualquier fecha de lanzamiento, más el tiempo de reclutar a los 12.

---

## 0 bis. El gancho y el hueco: las dos cosas que cambian el plan

Este plan se escribió sin dos piezas de información que ahora están verificadas.
Las dos van primero porque cambian **qué se dice** y **contra quién se dice**.

### El gancho: por qué ahora, en Chile

Tres hechos de la normativa chilena vigente, verificados en fuentes oficiales.
Las citas textuales y los enlaces están en **`docs/FICHA-PLAY.md §3`**; aquí va
solo lo que se usa para hablar:

1. Los bancos informan al SII el **número de abonos** de una cuenta cuando pasa
   de **50 abonos de 50 personas o entidades distintas en un día, una semana o un
   mes** (o 100 de 100 distintas en un semestre). Se informa el monto agregado, y
   **no se identifica a quién transfirió**.
2. Desde el **1 de octubre de 2025**, las plataformas de intermediación y los
   medios de pago electrónico tienen que **exigir inicio de actividades** antes de
   intermediar un cobro. Este es el más concreto de los tres: toca un trámite.
3. **No hay impuesto nuevo.** Lo dice el propio Gobierno. Lo que cambió es la
   información que cruza el SII, no lo que se paga.

**Por qué esto importa para el plan.** El plan tenía un «qué» muy claro
—«sabrás cuánto vale tu hora»— y ningún «por qué ahora». Un «por qué ahora» real
es lo que convierte una conversación de feria en un correo: la persona pasa de
«qué interesante» a «esto me pasa a mí este mes».

**Cómo se usa, y cómo NO se usa.** Tres reglas que no se negocian:

- **Nada de alarmismo.** No se habla de multas, no se dice «te van a
  fiscalizar», no se pone una cuenta atrás y no se insinúa que haya un impuesto
  nuevo. Quien lo haga pierde la confianza del público en una frase, y además
  dice algo falso.
- **Nada de asesoría.** La app **no** declara, **no** emite boletas, **no**
  calcula impuestos y **no** dice cuánto declarar. Decir cualquiera de esas cuatro
  cosas es asesoría tributaria, es responsabilidad legal del dueño y endurece la
  clasificación de la app en Google Play. La frase correcta es **«te deja
  ordenado lo que vendiste, para que la conversación con tu contador dure diez
  minutos»**.
- **Nada de fechas sin comprobar.** En particular, **no** se dice «entró en vigor
  el 2 de enero de 2026»: esa fecha circula en blogs y no la respalda ninguna
  fuente oficial (el detalle está en `docs/FICHA-PLAY.md §3`). El gancho no la
  necesita.

**La frase lista para usar, en los tres largos del §2:**

> Corto: «En Chile ya te piden tener las cuentas claras. Esta app te las deja
> ordenadas; no declara nada por ti.»
>
> Medio: «Los bancos ahora informan al SII cuántas transferencias recibe una
> cuenta, y las plataformas de pago piden inicio de actividades. Si vendes por
> Instagram, conviene tener anotado lo que vendiste. La app hace eso: anota,
> ordena por mes y te dice cuánto vale tu hora. No declara ni emite boletas.»
>
> Largo, para la feria: ver el guion del vídeo del §3, canal 2.

### El hueco: hay siete calculadoras, y ninguna lleva las cuentas

En la tienda chilena de Google Play hay **al menos siete calculadoras de precio
para artesanía**. Una tiene 100.000 instalaciones. Tres están publicadas en
español con ficha propia. Y una de ellas, **CraftCost**, ya descuenta la comisión
de Mercado Libre, Etsy, Shopify, eBay y Amazon Handmade, y soporta el peso
chileno. El inventario completo, con instalaciones y fechas de actualización
releídas el 6 de octubre de 2026, está en **`docs/COMPETENCIA.md §1.9`**.

**Y ninguna está abandonada.** Al releer las siete fichas, seis de las siete
fechas de actualización resultaron ser más recientes de lo que decía la versión
anterior del documento de competencia: dos se actualizaron esta misma semana y
la más antigua es de enero de 2026. La *Calculadora Artesanía — Tecydo*, que
figuraba como «sin tocar desde 2023», se actualizó el **29 de agosto de 2026**.
Conviene saberlo antes de escribir una línea: el argumento «son calculadoras
viejas que nadie mantiene» es falso y se desmonta en treinta segundos.

**Qué significa esto para el mensaje:**

- **No se dice «no hay nada igual».** Es falso y se comprueba en treinta
  segundos buscando en Play. Quien lo diga queda como vendedor.
- **No se dice que descontar la comisión del medio de pago sea novedad.** Ya está
  hecho y mejor documentado por un competidor.
- **No se dice que estén abandonadas.** Seis de las siete se actualizaron en
  2026 y dos esta semana.
- **Lo que sí es verdad, y es el eje:** ninguna de las siete **lleva las cuentas
  del mes**, ninguna tiene **inventario con stock mínimo**, ninguna tiene un
  **asistente con el que conversar sobre tus propios números** y ninguna calcula
  el valor hora **a partir de cuánto quieres ganar al mes**. Y ninguna de las
  cuatro apps de gestión del mercado (Treinta, Yimi, Mi Negocio Simple, Control
  de Mi Negocio) calcula precios. Esto sale de **lo que declara cada ficha**
  —descripción, capturas y novedades—, que es lo que se puede comprobar sin
  instalar las once apps; es «no lo anuncia», no «lo probé y no lo tiene».

> **La frase del posicionamiento, entonces, es:** «Una calculadora te da el
> precio y después cierras la app. Esta se queda con el mes.»

**Y un movimiento táctico que sale gratis.** Las reseñas de los competidores son
el mejor guion de contenido disponible: *Calculadora Artesanía Tecydo* tiene
reseñas de una estrella porque no respeta la moneda elegida, y *Treinta* las tiene
porque cobró por el acceso a datos que sus usuarios ya habían metido. Los dos
problemas están resueltos o decididos en Págate-IA (ver `docs/COMPETENCIA.md` §3,
huecos 2 y 3). Eso no se anuncia: se demuestra en un vídeo de 30 segundos.

---

## 1. A quién se le habla

No «emprendedores». Una persona concreta. **Es un retrato de trabajo, no un
dato demográfico**: sirve para decidir qué se dice y dónde, y no está sacado de
ninguna encuesta. Lo que sí está verificado va justo debajo, en «Por qué este
público».

> **Una mujer de entre 28 y 45 años que hace cerámica, telar, joyería o
> repostería en su casa o en un taller compartido. Vende en dos o tres ferias al
> mes y por mensaje directo de Instagram. Lleva las cuentas en un cuaderno o en
> una nota del teléfono. Sabe cuánto le costó el material y cuánto cobró, pero no
> sabe cuánto le quedó, y sobre todo no sabe si su hora de trabajo vale algo.
> Cuando alguien le dice «qué caro», baja el precio.**

Lo que le duele, en su orden, no en el nuestro:

1. «No sé si estoy ganando o perdiendo plata.»
2. «No sé cuánto cobrar y me da vergüenza pedir más.»
3. «Se me acaba el material a mitad de un pedido.»
4. «Odio los números y las planillas.»
5. «Me dijeron que ahora el banco informa las transferencias y no sé si tengo
   que hacer algo.» — Este es nuevo, y es el que abre la conversación. Ojo: la
   respuesta honesta es «no te puedo decir qué tienes que hacer, eso lo ve un
   contador; lo que sí puedo es que tengas anotado y ordenado lo que vendiste».
   Esa frase hay que decirla tal cual, no improvisarla.

**Lo que NO le duele:** la contabilidad formal, la facturación electrónica, el
inventario multibodega. Si le hablas de eso, se va.

### Por qué este público, con lo que se puede verificar

No hay un censo de artesanos chilenos. Lo que sí se puede comprobar:

- El **Sello de Excelencia a la Artesanía Chile** recibió **228 postulaciones en
  2024, desde las 16 regiones del país**, el máximo de su historia
  ([Ministerio de las Culturas](https://www.cultura.gob.cl/actualidad/ministerio-de-las-culturas-reconoce-ocho-obras-con-el-sello-de-excelencia-a-la-artesania-chile-2024/)).
  Esas son solo las personas con obra lo bastante terminada para postular a una
  convocatoria nacional: el universo real es mucho mayor.
- La **Muestra Internacional de Artesanía UC** reúne cada año a **más de 100
  artesanos de Chile y Latinoamérica** y lleva **más de 50 ediciones**
  ([Programa de Artesanía UC](https://artesania.uc.cl/extension/muestra/)).
- **Sercotec dicta un curso específico** titulado «Cómo definir precios a partir
  de análisis de costos»
  ([capacitacion.sercotec.cl](https://capacitacion.sercotec.cl/portal/curso-sincronico/como-definir-precios-a-partir-de-analisis-de-costos-ciclo-basico/)).
  Que el Estado dedique un curso a esto es la mejor señal pública de que el
  problema existe y es masivo.

**No encontré** ningún estudio que cuantifique cuántos artesanos no saben
calcular su precio por hora. No lo voy a inventar, y tú tampoco lo pongas en una
publicación.

---

## 2. La propuesta de valor, en una frase

> **Págate-IA te dice cuánto tiene que valer tu hora y te muestra si el mes
> cerró bien.**

Variantes para usar según el canal, todas con el mismo contenido:

- Para un comentario en un grupo: «Es una app para saber cuánto cobrar y llevar
  las cuentas del taller, sin planillas.»
- Para alguien en una feria: «Le pones cuánto quieres ganar al mes y cuántas
  horas puedes trabajar, y te dice cuánto vale tu hora. Después anotas ventas y
  gastos y ves si te cuadró el mes.»
- **Cuando sale el tema del SII o de las transferencias**, que va a salir: «Los
  bancos ahora informan cuántas transferencias recibe una cuenta. La app no
  declara nada ni emite boletas: lo que hace es que tengas ordenado lo que
  vendiste, para que hablar con tu contador dure diez minutos.»
- **Frente a quien ya usa una calculadora de precios**, que hay siete en Play:
  «Una calculadora te da el precio y después cierras la app. Esta se queda con el
  mes.»
- Para la ficha de Play: ver `docs/FICHA-PLAY.md` §4.

**Lo que NUNCA se dice**, porque es mentira y además arrastra la app a
regulaciones que no cumple: que recibe pagos, que se conecta al banco, que emite
boletas, que calcula lo que hay que declarar o que «te pone al día con el SII».
Tampoco «no hay nada igual»: hay siete calculadoras de precio para artesanía en
Play y se comprueba en treinta segundos (`docs/COMPETENCIA.md` §1.9).

---

## 3. Los cuatro canales

Ordenados por lo que rinden dividido por lo que cuestan, no por lo que se ve
bien en una presentación.

### Canal 1 — Ferias y encuentros de artesanía (el que más rinde)

**Cuesta:** la entrada o el pasaje, más una tarde. Entre 0 y 20.000 pesos por
salida *(estimación sin fuente)*. Es el canal más barato y el único donde hablas
con la persona exacta.

**Rinde** *(estimación sin fuente: ninguna de estas cifras está medida, son el
orden de magnitud con el que se dimensiona la tarde)*: entre 5 y 15
conversaciones reales por tarde, de las cuales 2 a 5 dejan su correo. Son pocos
números, pero cada uno trae una frase textual sobre el problema que no vas a
conseguir de ninguna otra forma. En esta etapa, **entender vale más que
convertir**.

**Cómo se hace, concretamente:**

- Vas como visitante, no como vendedor. Compras algo pequeño. Preguntas por la
  pieza. Después preguntas: «¿Y cómo le pones precio a esto?». Escuchas y
  anotas la respuesta literal.
- Solo si la conversación lo pide, cuentas qué estás haciendo. No abres con la
  app.
- **No lleves folletos.** Lleva el teléfono con la app, muestra la pantalla del
  valor hora y, si hay interés, le pides el correo ahí mismo y lo anotas tú. Un
  folleto se tira; un cálculo hecho con sus números delante, no se olvida.

**Dos fechas reales que conviene conocer:**

- **53ª Muestra Internacional de Artesanía UC**, del **16 al 20 de diciembre de
  2026**, en el Centro de Extensión del Campus Oriente UC, Providencia
  ([artesania.uc.cl](https://artesania.uc.cl/extension/muestra/)). Es el evento
  de referencia del sector en Chile. **Las postulaciones para expositores de esta
  edición cerraron el 25 de septiembre**, así que este año solo se puede ir como
  visitante. Y está perfecto: en cinco días hay más de cien artesanos de Chile y
  Latinoamérica en un mismo lugar y con tiempo para conversar. Es el mejor día
  de trabajo del año para este plan.
- **Feria de Invierno Artesanía UC**, en mayo, mucho más pequeña. Útil si se
  quiere postular como expositor más adelante: se postula con mucha antelación.
  *(El número de expositores de la edición de 2026 no lo pude verificar en
  [artesania.uc.cl](https://artesania.uc.cl/extension/muestra/); la versión
  anterior de este documento decía «37 artesanos» sin fuente y se ha quitado.)*

Entre medio, ferias locales: las de barrio, las municipales de fin de semana y
las de Navidad de noviembre y diciembre. Se encuentran en el Instagram de cada
municipalidad.

### Canal 2 — Instagram y TikTok orgánicos

**Cuesta:** cero en dinero. Entre 3 y 5 horas a la semana *(estimación sin
fuente)*.

**Rinde** *(estimación sin fuente)*: poco al principio y de golpe cuando un vídeo
pega. Lo realista en seis semanas, empezando de cero y sin pauta: entre 300 y
2.000 reproducciones por pieza, y entre 20 y 80 seguidores. Si un vídeo se sale,
puede llegar a decenas de miles; no se puede planificar, solo se puede estar
publicando cuando pase. **Ninguno de estos rangos está medido**: son la
expectativa con la que no desmoralizarse, no una promesa.

**El formato que funciona, y es uno solo:** el cálculo en vivo.

> Una pieza real. «Esta taza. 40 minutos de torno, 15 de esmalte, 2 horas de
> horno compartido. El material me costó 1.200 pesos. La vendo a 8.000. ¿Me
> está yendo bien?» Y haces el cálculo en pantalla con la app.

Por qué funciona: el espectador tiene exactamente esa duda sobre su propia pieza
y necesita saber el final. No es publicidad; es el problema resuelto en 40
segundos, con la app como herramienta y no como protagonista.

**El segundo formato, que es nuevo y es el que trae gente de fuera del nicho:**
*lo que cambió en Chile*, en 40 segundos y sin asustar a nadie.

> «Si vendes por Instagram y te pagan por transferencia, esto te interesa. Los
> bancos ahora le informan al SII cuántas transferencias recibe una cuenta
> cuando pasan de 50 de 50 personas distintas en un mes. **No hay impuesto
> nuevo**: lo que cambió es la información. Yo no te puedo decir qué declarar
> —eso lo ve un contador—, pero sí te puedo mostrar cómo tener anotado y
> ordenado lo que vendiste.» Y muestras la pantalla del mes.

Tres cosas que este vídeo **no** puede hacer, y si las hace es peor no
publicarlo: inventar una multa, poner una fecha límite, o insinuar que la app
arregla algo con el SII. El guion de arriba está escrito para que no haga ninguna
de las tres; úsalo tal cual.

**Reglas operativas:**

- 3 publicaciones por semana. Reel vertical de 30 a 50 segundos. El mismo vídeo
  sirve para Instagram y TikTok. Rota los dos formatos: dos de «cálculo en vivo»
  por cada uno de «lo que cambió en Chile».
- Rota entre tres rubros: cerámica, textil y repostería. No te quedes en uno.
- **Usa tus propios números o los de alguien que te dio permiso.** Nada de casos
  inventados. Si no tienes una pieza real, pide a un artesano que te preste sus
  datos y dale crédito.
- Responde todos los comentarios. Cada respuesta es una conversación que puede
  terminar en un correo.
- Nada de carruseles de «5 tips para emprendedores». Eso lo publica todo el
  mundo y no lo lee nadie.

### Canal 3 — Tiendas de insumos

**Cuesta:** entre 0 y 30.000 pesos, si se imprime algo *(estimación sin
fuente)*.

**Rinde:** es el canal de mayor apalancamiento del plan, porque la tienda **ya
tiene la confianza** del artesano y una recomendación de quien atiende vale
mucho más que un anuncio. *(Cuánta gente pasa al mes por una tienda de insumos
es una estimación sin fuente: la versión anterior decía «entre 50 y 300
artesanos al mes» y no hay dato público que lo respalde. Pregúntalo en la
primera visita: es una de las cosas que la tienda sí sabe.)*

**Cómo se hace:**

- Lista de 10 a 15 tiendas: arcilla y esmaltes, lanas y telar, insumos de
  joyería, insumos de repostería. Santiago primero, y las que venden por
  Instagram a regiones después.
- Vas en persona, compras algo y hablas con quien atiende. La propuesta es
  simple y no le cuesta nada: «Tengo una app que calcula cuánto tiene que
  cobrar un artesano por su hora y le lleva las cuentas del mes. ¿Te sirve
  recomendarla a tus clientes? Te dejo esto por si alguien pregunta.» Si quien
  atiende saca el tema del SII —en una tienda de insumos sale—, la respuesta es
  la frase media del §0 bis, sin adornarla.
- Lo que dejas es **una tarjeta tamaño bolsillo con un código QR** a la landing,
  no un folleto. *(El precio de 100 tarjetas es una estimación sin fuente: pide
  dos cotizaciones antes de presupuestarlo.)*
- **Usa un `source` distinto por tienda** en la URL del QR. El backend ya guarda
  ese campo (`functions/src/waitlist.ts` acepta `source`), así que sabrás qué
  tienda trae gente y cuál no. Es la medición más barata de todo el plan.

### Canal 4 — Grupos de emprendimiento y artesanía

**Cuesta:** cero. Entre 2 y 3 horas a la semana.

**Rinde** *(estimación sin fuente)*: entre 1 y 5 correos por grupo bien
trabajado. Y, mal hecho, cero más una expulsión.

**Cómo se hace, y esto importa:** no publicas la app. Buscas las preguntas sobre
precios, que aparecen todas las semanas en cualquier grupo de artesanía, y las
**contestas bien**, con el cálculo hecho. Solo si alguien pregunta «¿y con qué lo
calculas?», mencionas la app.

Hay un segundo tipo de pregunta que ahora aparece igual de seguido que la de
precios: **«¿es verdad que el banco informa mis transferencias?»**. Contéstala
con los tres hechos del §0 bis, incluido el de que no hay impuesto nuevo, y **di
explícitamente que no eres contador**. Es la respuesta más útil que vas a poder
dar en un grupo, y la que más credibilidad deja. La app se menciona solo si
alguien pregunta con qué se lleva la cuenta.

Dónde: grupos de Facebook de artesanía y emprendimiento chileno, grupos de
WhatsApp de ferias locales (se entra preguntándole a un expositor en la feria),
Reddit en r/chile y r/Emprendimiento. Elige **tres o cuatro grupos y sé
constante**; estar en veinte sin aportar es ser spam.

### Lo que NO se hace en estas seis semanas

- **Pauta pagada en Meta o Google.** Sin la app publicada y sin saber qué mensaje
  convierte, cada peso es un peso tirado. El momento de pautar es cuando sepas,
  con datos de la lista de espera, qué frase trae gente.
- **Influencers.** Caros, y su audiencia no coincide con la tuya.
- **Notas de prensa y medios.** Una app sin publicar no es noticia.
- **Blog y SEO.** Rinden a seis meses. Hoy no hay nada que posicionar.

---

## 4. Calendario de las primeras seis semanas

La Semana 1 empieza cuando los cuatro puntos del §0 estén cerrados, no antes.

### Semana 1 — Preparar y comprobar

- Probar el formulario de la lista de espera desde un teléfono y confirmar el
  registro en `waitlist/`.
- Escribir las 3 variantes de la propuesta de valor del §2 en una nota del
  teléfono, para no improvisar.
- Grabar los 3 primeros vídeos del cálculo en vivo. Publicar el primero.
- Hacer la lista de 15 tiendas de insumos con dirección y horario.
- Entrar a 4 grupos. No publicar nada todavía: leer una semana.

### Semana 2 — Primer contacto en persona

- Publicar 3 vídeos.
- Visitar **3 tiendas** de la lista. Sin tarjetas aún: el objetivo es ver si la
  conversación funciona y qué objeción aparece.
- Ir a **1 feria** de fin de semana. Meta: 5 conversaciones, 2 correos.
- Contestar 2 preguntas de precios en los grupos, sin mencionar la app.
- Encargar las 100 tarjetas con QR, una vez sepas qué frase funciona en la
  tienda.

### Semana 3 — Repartir

- Publicar 3 vídeos, uno de ellos sobre la objeción más repetida en la Semana 2.
- Visitar **5 tiendas más** y dejar tarjetas con un `source` por tienda.
- Ir a **1 feria**. Meta: 8 conversaciones, 3 correos.
- Contestar 3 preguntas en los grupos.

### Semana 4 — Primera revisión

- Publicar 3 vídeos.
- **Sentarse con los números** (§5). Mirar: qué `source` trae correos, qué vídeo
  tuvo más retención, qué frase se repite en las conversaciones.
- Reescribir la descripción breve de la ficha de Play si lo que la gente dice no
  coincide con lo que tú escribiste.
- Visitar las tiendas de la Semana 2 que no se cerraron, ahora con tarjetas.
- Escribir el **primer correo a la lista de espera** (§6).

### Semana 5 — Doblar lo que funciona

- Publicar 4 vídeos del formato que mejor rindió. Dejar de hacer el que no
  rindió.
- Ir a **2 ferias**. Meta: 15 conversaciones, 6 correos.
- Pedir a las 3 tiendas más receptivas que mencionen la app en **su** Instagram.
  Es gratis para ellas y multiplica el alcance.
- Preguntar a los 5 primeros inscritos si te dan 15 minutos por teléfono.

### Semana 6 — Cerrar el ciclo y preparar el lanzamiento

- Publicar 3 vídeos.
- Hacer las 5 llamadas. Anotar textualmente lo que digan: ese texto es el que va
  en la ficha de Play y en las capturas.
- Visitar las últimas 5 tiendas.
- **Reclutar los 12 probadores de la prueba cerrada** entre los inscritos más
  activos, si la cuenta es personal y nueva (ver el aviso del §0). Hacen falta
  12 que se inscriban y se queden 14 días seguidos, así que conviene invitar a
  18 o 20 para tener margen. Esto no es opcional: sin ello no hay acceso a
  producción.
- Si la app está publicada: escribir a toda la lista de espera, de una vez, con
  el enlace.

**Y la fecha fija del trimestre:** del **16 al 20 de diciembre**, la Muestra
Internacional de Artesanía UC. Reserva los cinco días. Si el calendario de arriba
empieza en octubre, esa semana cae justo después de la Semana 6 y es el mejor
momento para probar el mensaje ya afinado con más de cien artesanos.

---

## 5. Qué medir (cinco números, no un panel)

Una hoja de cálculo, una fila por semana. Nada más.

| Número | Cómo se obtiene | Para qué sirve |
|---|---|---|
| **Correos nuevos en la lista** | Contar documentos en `waitlist/` desde la consola de Firebase | Es el único número que mide si el plan avanza |
| **Correos por `source`** | Agrupar `waitlist/{id}.source` | Dice qué canal y qué tienda funcionan. Es la decisión más importante de cada semana |
| **Conversaciones cara a cara** | Un palito en el cuaderno por cada una | Mide tu esfuerzo. Si baja, el resto baja dos semanas después |
| **Retención del vídeo** | El dato nativo de Instagram y TikTok | Dice si el formato engancha, mucho antes que los seguidores |
| **Objeción más repetida** | Una frase anotada por semana | Es el guion del vídeo de la semana siguiente y el texto de la ficha |

**Lo que NO se mide:** seguidores, «me gusta», impresiones y alcance. Suben solos
y no predicen nada.

**Una expectativa honesta para no desmoralizarse** *(estimación sin fuente)*:
entre 30 y 120 correos en seis semanas, trabajando constante y sin pauta. **Ese
rango no está medido ni sale de ningún estudio**; es el orden de magnitud con el
que se decide si el plan va o no va, y se sustituye por datos reales en cuanto
haya tres semanas en la hoja. Si alguien te promete miles, está vendiendo algo.
Con 50 personas reales que tienen el problema se puede lanzar y aprender; con
5.000 correos comprados, no.

**Y un recordatorio que vale para todo el documento:** estas estimaciones son
para tu cuaderno. No van en la landing, no van en la ficha de Play y no se le
dicen a un posible socio como si fueran una proyección.

---

## 6. La lista de espera: qué hay, qué falta y cómo usarla

### Qué hay, exactamente

El mecanismo está construido y probado: la función `waitlist`
(`functions/src/waitlist.ts`) valida nombre y correo, normaliza el correo a
minúsculas, limita a 5 inscripciones por IP por hora y guarda en `waitlist/{id}`
el **nombre**, el **correo** y el **origen** (`source`). El formulario de la
landing (`WaitlistForm.tsx`) lo consume y tiene tests.

**Y está vacía.** El proyecto de Firebase no tiene Firestore habilitado, así que
hoy no hay ni un registro. La tubería existe; no ha pasado agua por ella.

Dos limitaciones del código que conviene conocer antes de confiar en el número:

- ~~**No hay deduplicación.**~~ **Ya la hay.** El id del documento es el
  `sha256` del correo normalizado (`functions/src/waitlist.ts`, `waitlistDocId`),
  así que la misma persona inscrita diez veces ocupa **un** documento. Contar
  documentos ya es contar personas.
- Los documentos **no son accesibles desde ningún cliente**
  (`firestore.rules:188-190`). Se leen desde la consola de Firebase o con el SDK
  de administrador. Para contar 50 correos eso sobra.

### Cómo usarla

**Primer correo, en la Semana 4.** No esperes al lanzamiento: una lista a la que
nunca escribes está muerta cuando por fin la necesitas. Corto, de persona a
persona:

- Quién eres y por qué estás haciendo esto.
- En qué está la app, de verdad, sin adornos.
- **Una pregunta concreta**, que es lo que de verdad te importa: «¿Cómo le pones
  precio hoy a lo que haces?» Pide responder al correo. Las respuestas son el
  mejor material que vas a tener.

**Segundo correo, con la prueba cerrada.** A los que respondieron el primero,
antes que al resto. Son los que van a reportar fallos en lugar de dejar una
estrella.

**Tercer correo, en el lanzamiento.** Con el enlace de Play y una línea
agradeciendo la espera.

**Tres cosas que no debes hacer:** comprar correos, meter a nadie sin que lo
pida, y escribir más de una vez al mes. El formulario promete «sin spam, solo te
escribiremos cuando lancemos», y esa promesa es parte de la política de
privacidad.

---

## 7. Decisiones que necesita tomar el dueño

No son tareas de código. Nadie puede decidirlas por él y el plan depende de ellas.

1. ~~**El nombre público.**~~ **Resuelto en la landing:** se unificó a
   **`Págate-IA`**, que es el nombre que ya usaban la app y las tres páginas
   legales, y el que lleva la ficha de Play del `docs/FICHA-PLAY.md §1`. Si el
   dueño prefiere `Pagate`, se cambia, pero en los dos sitios a la vez.
2. **Un correo de contacto real y atendido.** Es el de la política de privacidad,
   el de la ficha de Play y el que recibirá las solicitudes de borrado. Sin él no
   arranca ni el §0.
3. **Las cuentas sociales.** No existe ninguna verificada en el repo; por eso se
   quitaron los tres iconos del pie de la landing, que apuntaban a `#`. Hay que
   crear Instagram y TikTok, o decidir que no habrá redes y quitar el canal 2 del
   plan.
4. **La promesa sobre los datos.** El hueco más grande que dejó Treinta es la
   desconfianza: sus usuarios perdieron el acceso a su propia información cuando
   la app se volvió de pago (reseñas citadas en `docs/COMPETENCIA.md`).
   Comprometerse a que lo que anotas siempre se puede ver y exportar, aunque no
   pagues, es una decisión de producto con consecuencias de ingeniería. Si se
   toma, es el mejor argumento del plan; si no se toma, no se dice.
5. **Qué pasa con el plan Pro.** La interfaz ya lo menciona en tres sitios y no
   existe ninguna forma de comprarlo. O se construye con Google Play Billing, o
   se quitan las menciones antes de publicar.

**Y una decisión más, que el gancho nuevo introduce:**

6. **Hasta dónde se habla del SII.** El §0 bis fija el límite con el que está
   escrito todo este plan: describir la norma, nunca aconsejar. Si el dueño
   quiere ir más allá —por ejemplo, explicar en un vídeo cómo hacer el inicio de
   actividades—, eso ya es contenido de orientación tributaria y tiene
   consecuencias: deja de ser «la app ordena» y empieza a ser «esta persona me
   asesoró». Es una decisión suya, y hoy el plan dice que no.
