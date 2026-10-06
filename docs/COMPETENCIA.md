# Competencia — Págate-IA

Investigación de las apps que compiten o se solapan con Págate-IA para artesanos
y microemprendedores, con foco en Chile y Latinoamérica. Fecha del relevamiento:
**6 de octubre de 2026**.

## Cómo se obtuvieron los datos, y qué no se pudo obtener

Las valoraciones, el número de valoraciones y el número de instalaciones de cada
app se leyeron de los datos estructurados (`application/ld+json`) y del bloque de
detalle de su propia ficha de Google Play, en la tienda de Chile (`gl=CL`,
`hl=es_CL`). Las reseñas que se citan son las que la ficha muestra públicamente.

**La fecha de actualización sale de un sitio concreto y conviene decir cuál**,
porque la primera versión de este documento la tomó mal en seis de las siete
calculadoras. Es el valor del bloque visible de detalles de la ficha, el
rotulado **«Actualización»**, que en el HTML es
`<div class="lXlx5">Actualización</div><div class="xg1aie">29 ago 2026</div>`.
No es el `datePublished` del `ld+json` ni la fecha de la primera publicación,
que son otras y van por su cuenta. **Todas las fechas de este documento se
volvieron a leer así el 6 de octubre de 2026**, una por una, y el apartado
«Qué se corrigió» del §1.9 dice cuáles cambiaron.

**Lo que no pude verificar, y por tanto no afirmo:**

- Los precios de los planes de Treinta y Yimi: sus páginas publican cifras sin
  moneda explícita y localizan el precio por país, así que **no puedo afirmar el
  precio en pesos chilenos**. Doy el nombre de los planes y la fuente; el precio
  exacto en CLP hay que comprobarlo desde un dispositivo en Chile.
- La valoración de las dos calculadoras de artesanía: sus fichas no publican
  `aggregateRating`, probablemente por tener pocas valoraciones.
- Las cifras de ingresos, usuarios activos o retención de cualquiera de ellas.
  Nadie las publica y no las voy a estimar.
- No encontré ningún estudio que cuantifique **cuántos** artesanos chilenos no
  saben calcular su precio por hora. Que Sercotec dicte un curso específico
  sobre el tema es una señal, no un dato.
- **Las valoraciones de las siete calculadoras de §1.9**: ninguna de las siete
  publica `aggregateRating` —comprobado clave por clave en el `ld+json` de las
  siete fichas el 6 de octubre de 2026—, así que la columna dice «no la publica»
  y no un número inventado. Lo más probable es que tengan pocas valoraciones,
  pero eso es una conjetura y va dicha como tal.
- **Por qué cada app hace lo que hace.** Todo lo que este documento dice sobre
  las funciones de un competidor sale de **lo que declara su propia ficha**
  (descripción, capturas, novedades), no de haber usado la app. Es la diferencia
  entre «no lo anuncia» y «no lo tiene», y aquí solo se puede afirmar lo
  primero.
- **Los idiomas reales de la app**, por dentro. Lo que se puede comprobar es si
  el desarrollador publicó una ficha en español (ver el método en §1.9), no en
  qué idiomas está la interfaz.

---

## 1. Los competidores, uno por uno

### 1.1 Treinta — el gigante del segmento

- **Ficha:** <https://play.google.com/store/apps/details?id=com.treintaapp>
- **Sitio:** <https://treinta.co/>
- **Verificado en la ficha:** categoría Finanzas · **10.000.000+ instalaciones** ·
  **4,1 estrellas sobre 105.669 valoraciones** · descarga gratuita ·
  actualizada el **15 sept 2026**.
- **Modelo de negocio:** gratis con suscripción. Los planes publicados son
  **Esencial** (solo app) y **Pro** (app + web, con facturación electrónica
  ilimitada), con descuento trimestral y anual
  (<https://treinta.co/planes-y-precios>). El precio en CLP no lo pude
  confirmar; ver la advertencia de arriba.
- **Qué hace mejor:** cobertura (21 países, según su propio sitio), ventas,
  inventario, deudas y créditos de clientes, estadísticas, catálogo virtual y
  facturación electrónica. Es un sistema de gestión completo, no una app de
  anotar.
- **Qué hace peor — y aquí está lo interesante.** Las reseñas públicas de su
  ficha están dominadas por una misma queja: funciones que eran gratis pasaron a
  ser de pago y la gente perdió acceso a su propia información. Citas textuales
  de la ficha:
  - «*ahorita prácticamente tienes que pagar para utilizar la app, pues es
    inservible con esta última actualización*»
  - «*ahora no puedo acceder a nada de esa información, todo está perdido […]
    hasta eso están cobrando, la información que les proporcioné desde años
    atrás*»
  - «*ya ni siquiera se puede agregar un cliente sin tener que pagar […] sin
    esto la opción gratis es inservible*»
  - «*si tienes más de un comercio debes de pagar por cada comercio, yo tengo 3*»

  Hay además reseñas sobre cobros de suscripción no esperados y sobre que la app
  se cuelga.
- **Lectura:** Treinta ganó el mercado y después apretó el monetizador. Dejó una
  base de usuarios enfadados que ya aprendieron a usar una app para su negocio y
  hoy desconfían. Es el competidor más fuerte y, al mismo tiempo, el que más
  terreno descontento deja.

### 1.2 Yimi POS — punto de venta para emprendimientos

- **Ficha:** <https://play.google.com/store/apps/details?id=com.kio.yimitpv>
- **Sitio:** <https://yimiglobal.com/>
- **Verificado en la ficha:** categoría Negocios · **100.000+ instalaciones** ·
  **4,2 estrellas sobre 2.663 valoraciones** · descarga gratuita · actualizada el
  **2 oct 2026**.
- **Modelo de negocio:** gratis con suscripciones **Plus** y **Premium**, mensual
  o anual, con 7 días de prueba (planes recogidos en
  <https://www.capterra.com/p/253827/Yimi-POS/>; precios localizados, no
  verificados en CLP).
- **Qué hace mejor:** caja registradora de verdad, inventario, gastos y tienda en
  línea. Pensado para quien vende de forma continua en un local o un puesto.
- **Qué hace peor:** es un punto de venta. Asume que vendes muchas unidades de
  cosas que ya tienen precio. No ayuda a decidir ese precio, que es justo el
  problema de un artesano con producción por pieza.

### 1.3 Mi Negocio Simple — el competidor chileno directo

- **Ficha:** <https://play.google.com/store/apps/details?id=cl.minegociosimple.app>
- **Sitio:** <https://www.minegociosimple.cl>
- **Verificado en la ficha:** categoría Negocios · **100+ instalaciones** ·
  **5,0 estrellas sobre 6 valoraciones** · descarga gratuita · actualizada el
  **27 jul 2026**.
- **Modelo de negocio:** la ficha no declara compras dentro de la aplicación ni
  anuncios. Aparentemente gratis; no hay información pública de monetización.
- **Qué hace mejor:** el posicionamiento. Su propia descripción dice «ideal para
  feriantes, negocios familiares, ventas por redes sociales, emprendedores
  independientes y pequeños comercios» y «no necesitas experiencia en
  administración ni contabilidad». Es exactamente el mismo público que
  Págate-IA, descrito con las mismas palabras. Y una reseña destaca que tiene
  **contacto directo con los desarrolladores por WhatsApp**, que para este
  público vale más que cualquier función.
- **Qué hace peor:** cubre ventas, gastos, ganancias y reportes. **No calcula el
  valor hora** ni ayuda a fijar precios, y no tiene asistente. Y con 100
  instalaciones, todavía no ocupó el espacio.
- **Lectura:** es el aviso de que el nicho chileno está identificado por alguien
  más, y a la vez la prueba de que está libre. Hay que mirarlo de cerca.

### 1.4 Control de Mi Negocio — gestión con anuncios

- **Ficha:** <https://play.google.com/store/apps/details?id=com.lehreer.store>
- **Verificado en la ficha:** categoría Negocios · **100.000+ instalaciones** ·
  **4,19 estrellas sobre 1.427 valoraciones** · descarga gratuita ·
  **actualizada el 22 de septiembre de 2026**.
- **Modelo de negocio:** gratuito con publicidad, según las reseñas.
- **Qué hace mejor:** mucha función por cero peso: alerta de stock, fecha de
  vencimiento, clientes, deudores, proveedores, descuentos, cálculo de
  ganancias, exportación de la lista de productos a PDF. Una reseña lo resume:
  «*lo que le resta son los anuncios, pero no son tan invasivos*».
- **Qué hace peor:** los anuncios, y que las peticiones de sus usuarios revelan
  un modelo de costos rígido —piden costo promedio ponderado cuando cambia el
  precio del proveedor, y poder cerrar la jornada después de medianoche—. Tampoco
  calcula valor hora.

### 1.5 Calculadora Artesanía — Tecydo — la calculadora en español con más recorrido

> Esta y la de §1.6 son dos de **siete** calculadoras de precio para artesanía
> que hay en la tienda chilena. Las otras cinco, con sus cifras verificadas,
> están en **§1.9**, y la más seria de todas —CraftCost— también.

- **Ficha:** <https://play.google.com/store/apps/details?id=com.akynoapps.craftcalculator>
- **Sitio:** <https://tecydo.com>
- **Verificado en la ficha:** categoría Herramientas · **10.000+ instalaciones** ·
  **contiene anuncios** · descarga gratuita con compra «pro». Su ficha no
  publica valoración y su **última actualización es del 29 de agosto de 2026**.
  **Corregido:** la primera versión de este documento decía «12 de noviembre de
  2023, casi tres años sin tocarla», y es falso. El bloque «Actualización» de su
  ficha, releído el 6 de octubre de 2026, dice `29 ago 2026`. Está viva y es la
  calculadora en español con ficha propia más veterana del grupo.
- **Qué hace mejor:** está hecha exactamente para esto. Su descripción breve es
  «calculadora de costos y precios para crochet, costura y manualidades»:
  calcula tela, hilo, cintas y relleno, incluye mano de obra y gastos
  adicionales, y guarda proyectos para reutilizarlos.
- **Qué hace peor:** es solo una calculadora. No lleva cuentas del mes, no tiene
  inventario con stock y no tiene nada que conteste preguntas. Y sus propias
  reseñas señalan fallos básicos; cita textual de la ficha:
  «*compre la opción pro […] selecciono la moneda de mi país y no me aparece el
  valor de acuerdo a la moneda que indique […] no puedo ingresar detalle a
  detalle del material*». El desarrollador responde que ya ajustó ambas cosas.
- **Lectura:** el problema de «la moneda que elijo no se respeta» es el **mismo
  bug** que la auditoría había encontrado en Págate-IA (cinco formateadores
  distintos, símbolo `$` fijo y `profile.currency` ignorado). Que a un
  competidor le cueste reseñas de una estrella es la mejor confirmación de que
  valía la pena cerrar el hallazgo R-0, que ya está corregido en
  `arquitectura-segura` (commit `adc11e5`). Conviene no volver a abrirlo: es un
  fallo que el usuario ve en la primera pantalla y por el que deja una
  estrella.

### 1.6 Craft Pricing Calculator — la referencia en inglés

- **Ficha:** <https://play.google.com/store/apps/details?id=co.uk.handmadeaberdeenshire.craftpricingcalculator>
- **Verificado en la ficha:** categoría Productividad · **100.000+
  instalaciones** · **contiene anuncios** · descarga gratuita · **actualizada el
  28 de septiembre de 2026**. Su ficha no publica valoración. Es la calculadora
  de artesanía con **más instalaciones** de las siete. No es la más reciente:
  CraftCost (5 oct 2026) y *Handmade Pricing Calculator* (4 oct 2026) la
  adelantaron.
- **Qué hace mejor:** una sola cosa, muy bien: materiales, unidades producidas y
  tiempo empleado, y devuelve el costo por unidad y el precio para no perder
  dinero o para un margen dado. Permite **tarifas horarias distintas según el
  proceso**, que es un detalle que los artesanos piden y casi nadie tiene.
- **Qué hace peor:** está en inglés, no guarda nada del negocio y tiene
  anuncios. Sus 100.000 instalaciones prueban que existe demanda mundial para
  esto, aunque la app sea mínima.

### 1.7 y 1.8 Control de gastos personal — el sustituto real

Mucha gente que debería usar una app de negocio usa una de finanzas personales,
porque es la que conoce. Son competencia por sustitución, no por función.

| App | Ficha | Verificado |
|---|---|---|
| **Monefy** | <https://play.google.com/store/apps/details?id=com.monefy.app.lite> | Finanzas · **4,5 sobre 194.559 valoraciones** · gratis · act. 16 ago 2026 |
| **Controlar Gastos** | <https://play.google.com/store/apps/details?id=com.smartexpenditure> | Finanzas · **4,7 sobre 110.114 valoraciones** · gratis · act. 25 sept 2025 |
| **Bluecoins** | <https://play.google.com/store/apps/details?id=com.rammigsoftware.bluecoins> | Finanzas · **4,3 sobre 40.900 valoraciones** · gratis · act. 2 oct 2026 |

Releídas el 6 de octubre de 2026. Las dos primeras subieron una décima respecto
de la versión anterior de este documento (Monefy iba como 4,4 sobre 194.554 y
Controlar Gastos como 4,6): son cifras vivas y hay que fecharlas siempre.

- **Qué hacen mejor:** entrada de datos rapidísima, categorías, gráficos y años
  de pulido. Las valoraciones altas con volúmenes de seis cifras marcan el nivel
  de calidad de interacción al que la gente está acostumbrada.
- **Qué hacen peor:** no distinguen el dinero del negocio del dinero de la casa,
  no tienen inventario, no tienen costo de producción y no tienen idea de lo que
  vale una hora de trabajo.

### 1.9 El pelotón de calculadoras de precio para artesanía

Las dos de §1.5 y §1.6 no son un caso aislado: **en la tienda chilena de Google
Play hay al menos siete calculadoras de precio para artesanía**. Las encontré
buscando `calculadora precios artesania`, `calculadora costos manualidades` y
`craft pricing calculator` con `hl=es_CL&gl=CL`, y leí la ficha de cada una.
Todos los datos de la tabla salen de los datos estructurados
(`application/ld+json`) y del bloque de detalle de su propia ficha, el 6 de
octubre de 2026.

Fechas, instalaciones y valoraciones **releídas el 6 de octubre de 2026** del
bloque «Actualización» y del bloque de descargas de cada ficha:

| App | Paquete | Categoría | Instalaciones | Valoración | Actualizada | Anuncios | Ficha en español |
|---|---|---|---|---|---|---|---|
| **CraftCost: Precios Artesanía** | `com.codeensis.craftcost` | Negocios | 100+ | no la publica | **5 oct 2026** | No declara | **Sí, con título propio** |
| Handmade Pricing Calculator | `dev.mdwalid.craft_pricing` | Productividad | 10+ | no la publica | **4 oct 2026** | No declara | Traducida; título en inglés |
| Craft Pricing Calculator | `co.uk.handmadeaberdeenshire.craftpricingcalculator` | Productividad | **100 k+** | no la publica | **28 sept 2026** | Sí | Traducida; el título sigue en inglés |
| Product Maker: Calcular Costos | `com.domene.productmaker` | Productividad | 500+ | no la publica | **14 sept 2026** | No declara | **Sí, con título propio** |
| Calculadora Artesanía — Tecydo | `com.akynoapps.craftcalculator` | Herramientas | 10 k+ | no la publica | **29 ago 2026** | Sí | **Sí, con título propio** |
| CostoPro | `com.susucrea.costopro` | Productividad | 100+ | no la publica | **13 abr 2026** | No declara | No se puede saber: el título es el mismo en los dos idiomas |
| Craft Pricing Calculator (Subbarao) | `com.subbarao.craftpricingcalculator` | Productividad | 1 k+ | no la publica | **6 ene 2026** | Sí | Traducida; título en inglés |

**Ninguna de las siete publica `aggregateRating`**, y eso no es una suposición:
en el `ld+json` de las siete fichas no existe la clave. Lo más probable es que
tengan pocas valoraciones, pero eso sigue siendo conjetura y va dicha como tal.
**Las siete siguen vivas**: la más antigua de las siete actualizaciones es de
enero de 2026.

**Cómo distinguí «ficha en español» de «ficha traducida».** Google traduce
automáticamente la descripción breve de cualquier app al idioma de la tienda, así
que leer español no prueba nada. Lo que sí lo prueba es que el **título** cambie
entre `hl=es_CL` y `hl=en`: eso solo ocurre cuando el desarrollador publicó una
ficha en español. Comprobado par a par el 6 de octubre de 2026:

| Paquete | `hl=es_CL` | `hl=en` | ¿Ficha propia? |
|---|---|---|---|
| `com.akynoapps.craftcalculator` | Calculadora Artesanía - Tecydo | Craft Calculator - Tecydo | **Sí** |
| `com.codeensis.craftcost` | CraftCost: Precios Artesanía | CraftCost: Handmade Pricing | **Sí** |
| `com.domene.productmaker` | Product Maker: Calcular Costos | Product Maker: Cost Calculator | **Sí** |
| `com.susucrea.costopro` | CostoPro | CostoPro | No se puede saber |
| `dev.mdwalid.craft_pricing` | Handmade Pricing Calculator | (igual) | No |
| `com.subbarao.craftpricingcalculator` | Craft Pricing Calculator | (igual) | No |
| `co.uk.handmadeaberdeenshire.craftpricingcalculator` | Craft Pricing Calculator | (igual) | No |

Son **tres**, no dos: la versión anterior de este documento contaba dos porque
dejaba fuera a Tecydo, que sí tiene título propio en español. Y de CostoPro no se
puede afirmar nada por este método: su nombre es el mismo en los dos idiomas.

### Qué se corrigió, y el dato de partida que resultó ser cierto

El encargo decía que en Google Play había **al menos seis** calculadoras de
precio para artesanía y que **una estaba en español y actualizada en agosto de
2026**. Una versión anterior de este documento respondió que «ninguna lo está».
**Esa respuesta era la equivocada, y el dato de partida era correcto:**

> **Calculadora Artesanía — Tecydo** (`com.akynoapps.craftcalculator`) tiene
> ficha propia en español —su título cambia entre `hl=es_CL` y `hl=en`— y su
> bloque «Actualización» dice **29 ago 2026**.

De paso, al releer las siete fichas el 6 de octubre de 2026 cambiaron **seis de
las siete fechas** de la tabla:

| App | Decía | Dice su ficha hoy |
|---|---|---|
| Calculadora Artesanía — Tecydo | 12 nov 2023 | **29 ago 2026** |
| CraftCost | 8 jun 2026 | **5 oct 2026** |
| Handmade Pricing Calculator | 14 sept 2026 | **4 oct 2026** |
| Product Maker | 10 may 2026 | **14 sept 2026** |
| CostoPro | 3 feb 2026 | **13 abr 2026** |
| Craft Pricing Calculator (Subbarao) | 1 dic 2025 | **6 ene 2026** |
| Craft Pricing Calculator | 28 sept 2026 | 28 sept 2026 (sin cambio) |

Y una conclusión que sí cambia con esto: el pelotón **no está abandonado**. La
idea de que eran calculadoras viejas que nadie mantiene era un consuelo falso.
Dos se actualizaron esta semana. Lo que las separa de Págate-IA no es que estén
muertas, es lo que no hacen, y eso está en el apartado siguiente.

Queda escrito porque una cifra mal citada en un documento de estrategia se
convierte en una cifra mal citada en una publicación.

### Las dos que hay que mirar de cerca

**CraftCost (`com.codeensis.craftcost`)** es el competidor nuevo más serio para la
mitad «precio» de Págate-IA, y conviene leer su propia descripción antes de
escribir una línea de posicionamiento. Lo que declara:

- Biblioteca de materiales reutilizable, con precio por gramo, metro o unidad.
- Costo por pieza combinando materiales, mano de obra y gastos fijos.
- **Perfiles de comisión editables para Mercado Libre, Etsy, Shopify, eBay y
  Amazon Handmade**, y explícitamente «*¿Vendes por Instagram o WhatsApp?
  También está contemplado: sin comisión de plataforma*».
- **Peso chileno entre las monedas soportadas**, «*con el formato correcto de
  cada una*».
- Exportación de listas de precios y cotizaciones a PDF o imagen.
- Suscripción Pro mensual, anual o compra única *Lifetime*.
- Y una frase que vale la pena leer dos veces: «*Sobre los números: CraftCost te
  da estimaciones para que tomes mejores decisiones de precio. Cuánto cobras
  siempre lo decides tú*». Es exactamente el límite que el contrato C-3 impone a
  Págate-IA, escrito por un competidor.

**Consecuencia directa para el contrato C-3:** descontar la comisión del medio de
pago **no es un diferenciador**. Ya está hecho, en español, con perfiles por
plataforma y con el peso chileno soportado. Es una casilla que hay que tener, no
una bandera que agitar.

**Product Maker (`com.domene.productmaker`)** es la única de las siete que usa
IA, y conviene saber exactamente cómo: fotografías el producto terminado y el
modelo «deduce» los insumos para armar una estructura de costos. Su propia ficha
aclara que eso «*requiere tu propia API Key*». **No es un asistente
conversacional sobre tus números**: es visión por computador aplicada a rellenar
una lista de materiales. Tampoco lleva cuentas del mes.

### Qué les falta a las siete, sin excepción

Ninguna de las siete registra **ingresos y gastos mes a mes**, ninguna lleva
**inventario con stock y stock mínimo**, y ninguna tiene un **asistente con el
que conversar sobre tus propios números**. Y ninguna calcula el **valor hora**
como lo hace Págate-IA —a partir de cuánto quieres ganar al mes y cuántas horas
puedes trabajar—: todas trabajan al revés, metiendo la mano de obra como un costo
por pieza.

---

## 2. El cuadro completo

Las valoraciones son las de `aggregateRating` de cada ficha, leídas el 6 de
octubre de 2026. «Precio por pieza» es calcular el costo y el precio de un
producto; «Valor hora» es el cálculo inverso de Págate-IA, que parte de la meta
mensual y las horas disponibles. No son lo mismo y la diferencia es el producto.

| App | Instalaciones | Valoración | Modelo | Precio por pieza | Valor hora | Cuentas del mes | Inventario con stock | Asistente | Chile |
|---|---|---|---|---|---|---|---|---|---|
| Treinta | 10 M+ | 4,1 (105.669) | Freemium agresivo | No | No | Sí | Sí | No | Sí |
| Yimi POS | 100 K+ | 4,2 (2.663) | Freemium | No | No | Sí | Sí | No | Sí |
| Mi Negocio Simple | 100+ | 5,0 (6) | Gratis | No | No | Sí | Parcial | No | **Chileno** |
| Control de Mi Negocio | 100 K+ | 4,2 (1.427) | Gratis con anuncios | No | No | Sí | Sí | No | Sí |
| Calculadora Artesanía Tecydo | 10 K+ | no la publica | Anuncios + pro | **Sí** | No | No | No | No | Sí |
| Craft Pricing Calculator | 100 K+ | no la publica | Anuncios | **Sí** | No | No | No | No | Solo inglés |
| CraftCost | 100+ | no la publica | Pro por suscripción | **Sí**, con comisiones | No | No | No | No | Soporta CLP |
| Product Maker | 500+ | no la publica | Gratis / Pro | **Sí**, con IA de visión | No | No | No | No | Sí |
| CostoPro · Handmade Pricing · Craft Pricing (Subbarao) | 10 a 1 K+ | no la publican | Gratis | **Sí** | No | No | No | No | Mixto |
| Monefy / Controlar Gastos / Bluecoins | 100 K+ a 10 M+ | 4,3–4,7 | Gratis / freemium | No | No | Personal | No | No | Sí |
| **Págate-IA** | — | — | Gratis hoy | No (todavía) | **Sí** | **Sí** | **Sí** | **Sí** | **Chileno** |

Dos casillas de la fila de Págate-IA merecen una nota, porque son las que la
hacen honesta:

- **«Precio por pieza: No (todavía)».** La app calcula el valor hora, no el costo
  de una pieza a partir de su receta de materiales. Es justo lo que hacen las
  siete calculadoras de §1.9, y es el hueco que ellas tienen cubierto.
- **Instalaciones y valoración vacías.** No está publicada. No hay número que
  poner y no se va a estimar.

---

## 3. Dónde está el hueco

**Nadie junta las dos mitades del problema.** Las apps de gestión (Treinta, Yimi,
Mi Negocio Simple, Control de Mi Negocio) te dejan anotar lo que ya vendiste,
pero ninguna te ayuda a decidir el precio. Las **siete** calculadoras de §1.9 te
ayudan a decidir el precio y después se olvidan de ti: cierras la app y no queda
nada del mes. El artesano necesita las dos cosas y hoy tiene que usar dos apps, o
una app y una libreta.

Y conviene decir el hueco con precisión, porque dicho a lo bruto es falso. **No**
es cierto que «nadie calcula precios para artesanía»: hay siete apps haciéndolo,
una con 100.000 instalaciones. **No** es cierto que «nadie descuenta la comisión
del medio de pago»: CraftCost tiene perfiles por plataforma. **No** es cierto que
«nadie usa IA»: Product Maker usa visión por computador. Lo que sí es cierto, y
lo comprobé app por app:

> **Ninguna de las siete calculadoras lleva las cuentas del mes, ninguna tiene
> inventario con stock mínimo, ninguna tiene un asistente con el que conversar
> sobre tus propios números, y ninguna calcula el valor hora desde la meta
> mensual. Y ninguna de las cuatro apps de gestión calcula precios.**
>
> Son dos pelotones que no se tocan. Esa frontera es el producto.

**Cinco huecos concretos, cada uno con su evidencia:**

1. **Valor hora + cuentas del mes en la misma app.** Es la única casilla del
   cuadro de §2 que solo tiene una marca, y es la de Págate-IA. No es una ventaja
   de marketing: es que el valor hora deja de ser un número de una vez y se
   convierte en la referencia contra la que comparas el mes. Las calculadoras no
   pueden hacerlo porque no guardan el mes; las apps de gestión no pueden
   hacerlo porque no saben cuánto quieres ganar.

2. **La desconfianza que dejó Treinta.** «*Todo está perdido*», «*hasta eso están
   cobrando*», «*la información que les proporcioné desde años atrás*». Hay una
   base de microemprendedores latinoamericanos que ya sabe usar una app para su
   negocio y que hoy se siente estafada. Prometer y cumplir que lo que anotas
   siempre se puede ver y exportar, aunque no pagues, vale más que cualquier
   función nueva. **Esto es una promesa de producto que hay que decidir y
   sostener**, no una frase de la landing.

3. **La moneda y el formato chileno hechos bien.** Un competidor directo recibe
   reseñas negativas porque no respeta la moneda elegida. Págate-IA tenía
   exactamente el mismo fallo (hallazgo R-0) y ya está corregido en
   `arquitectura-segura` (commit `adc11e5`). Es una ventaja pequeña y real:
   miles con punto, sin decimales en CLP y negativos legibles se notan en la
   primera pantalla, y al competidor le cuestan valoraciones.

4. **Soporte con cara.** La única reseña sustantiva de Mi Negocio Simple destaca
   el WhatsApp directo con los desarrolladores. Para este público, poder
   escribirle a una persona pesa más que un roadmap. Una persona sola puede
   competir en eso contra una empresa de 21 países; en funciones, no.

5. **El ángulo chileno, que ninguna usa.** Ninguna de las once fichas revisadas
   menciona el reporte de abonos al SII ni la exigencia de inicio de actividades
   a los medios de pago (los dos hechos verificados en
   `docs/FICHA-PLAY.md §3`). Es el único argumento de «por qué ahora» disponible,
   está libre y es específico de Chile, que es donde las dos chilenas de la lista
   —Mi Negocio Simple, con 100 instalaciones— todavía no han ocupado el espacio.

**Dónde NO conviene competir:** facturación electrónica ante el SII, punto de
venta con caja y catálogo en línea. Treinta y Yimi ya los tienen, son caros de
construir y arrastran obligaciones regulatorias.

**Y un frente donde competir es caro y llegar segundo es seguro:** el costeo por
receta de materiales con perfiles de comisión por plataforma. CraftCost ya lo
tiene resuelto, en español y con CLP. Si Págate-IA entra ahí, entra a empatar.
El campo `platformFee` del contrato C-3 es una casilla necesaria para que el neto
de una venta sea verdad, no una ventaja que se pueda anunciar.

---

## 4. Cómo se posicionan: las palabras que usan

Extraídas de las descripciones breves y largas de sus propias fichas.

| Competidor | Cómo se describe (textual de su ficha) |
|---|---|
| Treinta | «Digitaliza y optimiza la gestión de tu negocio» |
| Yimi POS | «Gestiona tu Negocio: Inventario, Caja Registradora y Gastos desde celular PDV» |
| Mi Negocio Simple | «Controla ventas, gastos y ganancias de tu negocio de forma simple» |
| Control de Mi Negocio | «Ventas, gastos e inventario de tu negocio en una sola app» |
| Calculadora Artesanía Tecydo | «Calculadora de costos y precios para crochet, costura y manualidades» |
| Craft Pricing Calculator | «Calcule rápidamente el precio al por menor de productos hechos a mano basados en costos y tiempo» |
| CraftCost | «Calculadora de precios para artesanía: costos, comisiones y ganancia real» |
| Product Maker | «Calculadora de costos con IA y control de márgenes para emprendedores» |
| CostoPro | «Calcula costos, mano de obra y gastos para fijar precios a tus productos» |
| Handmade Pricing Calculator | «Consulta la lista de materiales para obtener precios reales para tus manualidades: sin suscripciones ni anuncios molestos» |

**Vocabulario que repiten:** `gestiona` · `controla` · `tu negocio` ·
`ventas` · `gastos` · `ganancias` · `inventario` · `simple` · `fácil` ·
`emprendedores` · `desde tu celular` · `sin planillas` · `sin conocimientos
contables` · `costos` · `precios` · `hechos a mano`.

**Vocabulario que casi nadie usa y que a Págate-IA le pertenece:**
`valor hora` · `cuánto cobrar` · `cuánto vale tu trabajo` · `taller` · `ferias`.
Mi Negocio Simple es el único que dice «feriantes».

**Corrección respecto de la versión anterior de este documento:** `artesanos` ya
**no** es vocabulario libre. Cinco de las once fichas lo usan, CraftCost lo usa
en el título de la ficha en español («Precios Artesanía») y Tecydo lo usa en el
nombre de la app. Sigue valiendo la pena incluirlo en la ficha de Play para no
perder esa búsqueda, pero **no diferencia**. Lo que diferencia es `valor hora`:
ninguna de las once fichas lo menciona.

**Y un término que hay que evitar en la ficha**, aunque la competencia lo use:
`comisiones`. CraftCost lo pone en su descripción breve y lo tiene implementado;
usarlo mientras `platformFee` no exista en `lib/` sería anunciar lo que la app no
hace.

Esto alimenta directamente `docs/FICHA-PLAY.md`: el nombre y la descripción
breve apuntan al vocabulario propio, y la descripción larga incluye también el
vocabulario común para no perder las búsquedas genéricas.

---

## 5. Fuentes

Fichas de Google Play (tienda de Chile, `hl=es_CL&gl=CL`), consultadas el 6 de
octubre de 2026:

- Treinta — <https://play.google.com/store/apps/details?id=com.treintaapp>
- Yimi POS — <https://play.google.com/store/apps/details?id=com.kio.yimitpv>
- Mi Negocio Simple — <https://play.google.com/store/apps/details?id=cl.minegociosimple.app>
- Control de Mi Negocio — <https://play.google.com/store/apps/details?id=com.lehreer.store>
- Calculadora Artesanía Tecydo — <https://play.google.com/store/apps/details?id=com.akynoapps.craftcalculator>
- Craft Pricing Calculator — <https://play.google.com/store/apps/details?id=co.uk.handmadeaberdeenshire.craftpricingcalculator>
- CraftCost: Precios Artesanía — <https://play.google.com/store/apps/details?id=com.codeensis.craftcost>
- Product Maker: Calcular Costos — <https://play.google.com/store/apps/details?id=com.domene.productmaker>
- CostoPro — <https://play.google.com/store/apps/details?id=com.susucrea.costopro>
- Handmade Pricing Calculator — <https://play.google.com/store/apps/details?id=dev.mdwalid.craft_pricing>
- Craft Pricing Calculator (Subbarao) — <https://play.google.com/store/apps/details?id=com.subbarao.craftpricingcalculator>
- Monefy — <https://play.google.com/store/apps/details?id=com.monefy.app.lite>
- Controlar Gastos — <https://play.google.com/store/apps/details?id=com.smartexpenditure>
- Bluecoins — <https://play.google.com/store/apps/details?id=com.rammigsoftware.bluecoins>

Sitios de los competidores:

- <https://treinta.co/> y <https://treinta.co/planes-y-precios>
- <https://yimiglobal.com/>
- <https://www.minegociosimple.cl>
- <https://tecydo.com>
- <https://codeensis.com/craftcost> (sitio de CraftCost)
- <https://productmaker-app.com/> (sitio de Product Maker)
- <https://www.capterra.com/p/253827/Yimi-POS/> (planes de Yimi)

Normativa chilena citada en §3 (el detalle y las citas textuales están en
`docs/FICHA-PLAY.md §3`):

- SII — *Ley de cumplimiento de las obligaciones tributarias* —
  <https://www.sii.cl/destacados/ley_cumplimiento_obligaciones_tributarias/combate_elusion_evasion_informalidad.html>
- SII — *Información bancaria: transferencias* —
  <https://www.sii.cl/destacados/ley_cumplimiento_obligaciones_tributarias/informacion_bancaria_tf.html>
- SII — Circular N° 2, de 2 de enero de 2025 —
  <https://www.sii.cl/normativa_legislacion/circulares/2025/circu2.pdf>
- SII — *Entrada en vigencia de la obligación de exigir inicio de actividades*,
  16 de septiembre de 2025 — <https://www.sii.cl/noticias/2025/160925noti01pcr.htm>

Contexto del sector artesanal y de ferias en Chile:

- INDAP, *Estudio de casos: modelos actuales de comercialización de las
  artesanías en Chile* —
  <https://www.indap.gob.cl/sites/default/files/2024-04/Estudio-de-casos-Modelos-actuales-de-comercializacion-de-las-artesanias-en-Chile.pdf>
- Sercotec, *Catastro Nacional de Ferias Libres 2025* —
  <https://www.catastroferiaslibres.cl/docs/Ferias_Libres_Catastro_Nacional_2025_.pdf>
  (1.455 ferias libres, 163 mil puestos, según la presentación oficial del
  catastro: <https://eligevivirsano.gob.cl/noticias/sercotec-presento-primer-catastro-de-ferias-libres/>)
- Sercotec, curso *Cómo definir precios a partir de análisis de costos* —
  <https://capacitacion.sercotec.cl/portal/curso-sincronico/como-definir-precios-a-partir-de-analisis-de-costos-ciclo-basico/>
