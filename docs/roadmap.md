# Hoja de ruta — OpoMemo

Documento de trabajo. Criterio: **no abrir un modo nuevo hasta que el bucle de tarjetas se use varios días**. Relacionar y Huecos fallan si la carta es un enunciado de test largo. Un hecho alimenta todos los modos.

Versión actual: **0.1.0**. Detalle de releases: [CHANGELOG.md](../CHANGELOG.md).

## Orden de valor

1. Pulir **Tarjetas** (sesión diaria, atajos, deshacer).
2. Subir la **calidad del hecho** (término / hueco / distractores; un mazo atómico de plazos LPACAP).
3. Abrir **Huecos** y **escribir** en leyes; **Relacionar** sobre pares cortos (Redes ya vale).
4. **Verdadero/falso** cuando se reextraigan las opciones incorrectas de OpoTest.
5. Más adelante: ordenar pasos, sesión mixta, puente fallos de OpoTest → mazo.

Aparca ligas, IA legal, arcade y rehacer el test de 4 opciones (eso es OpoTest).

## Tarjetas

### P0 · que se use todos los días

Hecho en **0.1.0**: repaso del día, atajos, deshacer/saltar, tamaño de sesión y reaparición de No/Casi en el lote.

### P1 · listado y lectura

Distribución por caja Leitner, búsqueda en mazos y cartas, toggle anverso/reverso, marcar carta para editar luego.

### P2 · confort

Tema oscuro, recordar ventana en escritorio, chips de filtro cortos (CE, LPACAP, TREBEP).

## Modos anunciados (Próximamente)

| Modo | Orden | Listo cuando |
|---|---|---|
| Huecos | 2.º (leyes) | El hecho tiene un dato tapable (plazo, artículo). |
| Relacionar | 3.º | Hechos cortos término ↔ definición. Toque-toque, no flechas. |
| Verdadero / falso | 4.º | Distractores de OpoTest o trampas redactadas a mano. |

Contrato de datos a añadir en `Fact`: `kind` (termino / pregunta / hueco), `clozeText`, `distractors[]`, fuente con ley + artículo. Un `ReviewState` único: un fallo en Match adelanta el due en tarjetas.

## Contenido

Las 1.048 cartas actuales salen de tests de 4 opciones (enunciado → opción correcta). Sirven para probar el volteo; no son un mazo Anki. Tres capas:

- **A · Atómica** — 30–50 hechos a mano (plazos LPACAP, órganos CE, puertos). Oro para Huecos y Relacionar.
- **B · Importada limpia** — reextraer OpoTest con distractores y artículo; no borrar el SRS de ids `opotest.q.*`.
- **C · Volumen** — resto de leyes e importador JSON. Cuando el hábito diario exista.

## Otros modos (después)

Escribir dato corto (alta), ordenar pasos (media), sesión mixta 8 volteos + 4 huecos + 4 pares (el botón «Estudiar» de Inicio). Oclusión de esquemas más tarde. No: Gravity, ligas, multijugador.

## Cómo añadir un modo

Una entrada en `StudyModes.catalog`, una pantalla, y un filtro sobre `Fact.kind`. Si el modo no puede vivir de prompt/answer (o cloze/distractores), no es un modo: es otro producto.
