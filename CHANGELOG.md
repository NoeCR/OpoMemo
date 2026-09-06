# Changelog

Todas las mejoras relevantes de OpoMemo se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/). En esta fase previa a 1.0, el primer número se queda en **0** y subimos el parche o el menor según el alcance.

## [Unreleased]

---

## [0.3.0] - 2026-09-06

Hechos con aclaración y un catálogo propio, sin tests de OpoTest.

### Added
- Modelo de hecho: tipo (término / pregunta / hueco), texto con hueco `{{dato}}` y distractores.
- Aclaración en el dorso de cada carta: contexto extra al voltear (campo opcional al editar).
- Negrita y cursiva en la respuesta y en la aclaración (`**texto**` / `*texto*`, o los botones al editar).
- Catálogo semilla de **Ley 19/2013**, **TREBEP** (RDL 5/2015), **Ley 30/1984** y **Ley 53/1984**, importados desde markdown (pregunta → respuesta → truco).
- Mazos atómicos **LPACAP · Plazos** y **CE · Órganos** (código listo; no se siembran).

### Changed
- Al arrancar se siembran esos markdown. OpoTest, plazos LPACAP, órganos CE y Redes quedan archivados y los mazos semilla antiguos se retiran.

---

## [0.2.0] - 2026-09-05

Listado usable: ver el mazo, encontrarlo y organizarlo.

### Added
- Distribución Leitner (cartas nuevas y cajas 1–5) en el listado y el detalle de mazo.
- Búsqueda en mazos y en las cartas de un mazo; filtro de cartas marcadas.
- Sesión al revés: ver la respuesta y producir el término (R o ajustes de inicio).
- Marcar una carta para editarla después (bandera en el mazo y en la sesión; atajo B).
- Crear un mazo en una sección existente o nueva, y moverlo al editar. Reabrir la app no devuelve los mazos semilla a su grupo original.

---

## [0.1.0] - 2026-09-05

Sesión diaria usable: una cola, teclado y deshacer.

### Added
- Repaso del día: una cola con cartas pendientes de todos los mazos.
- Atajos en escritorio: espacio voltea; 1 No, 2 Casi, 3 Sí; S salta; Z deshace; Esc sale.
- Deshacer y saltar en la sesión de tarjetas. Un No o Casi vuelve una vez más al final del lote.
- Tamaño de sesión (10 / 15 / 20 / 30 cartas) desde el icono de ajustes del inicio.

---

## [0.0.1] - 2026-09-05

Primera entrega usable: app hermana de OpoTest para memorizar, no para examinarse.

### Added
- Hub de modos (Tarjetas listo; Relacionar, Huecos y Verdadero/falso anunciados).
- Mazos de tarjetas con volteo, autoevaluación No / Casi / Sí y Leitner de 5 cajas (1 / 3 / 7 / 16 / 30 días).
- Alta y edición de mazos y cartas; persistencia local SQLite (Android y Windows).
- 31 mazos semilla desde el temario de OpoTest (Constitución, LPACAP, Ley 40/2015, TREBEP) más un mazo de Redes · Transporte.
- Hoja de ruta en `docs/roadmap.md`.

### Fixed
- El botón Repasar del listado de mazos usaba texto verde sobre fondo verde.

---
