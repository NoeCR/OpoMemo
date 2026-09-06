# Semilla archivada

No se carga al arrancar la app. Se conserva por si hace falta reactivarla:

- `opotest_decks.json` — extracto de tests de OpoTest (Constitución, LPACAP, Ley 40/2015, TREBEP).
- Los mazos Dart `lib/data/pilot_seed.dart` (Redes), `lpacap_plazos_seed.dart` y `ce_organos_seed.dart` tampoco se llaman desde `ContentSeed`.

Para reactivar: registrar de nuevo en `ContentSeed.ensure` y, si aplica, en `pubspec.yaml` (`flutter.assets`).
