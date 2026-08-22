# Aphidex 1.3 — Auditoría inicial

Fecha: 2026-08-21

## Estado del proyecto

- Flutter/Dart, versión actual `1.2.0+21`.
- Datos de criaturas separados por idioma (`en`, `es`, `ru`), con índices ligeros y 212 detalles por idioma.
- Grounded 2 contiene 132 entradas visibles; 124 tienen `technicalId` y 122 coinciden exactamente con IDs del extractor.
- La persistencia usa Hive, caja `aphidex`, con claves independientes para perfiles, favoritos, eliminaciones, cartas, idioma, tema, tutorial, navegación y monetización.
- La app actual usa una única lista principal de criaturas; no existe navegación primaria para Equipo o Mapa.
- La ficha de criatura ya soporta carga diferida, variantes, ataques, loot, fases, afinidades e infusiones.

## Fuentes verificadas

- Extractor: `F:\ByteShark-Dev\Aphidex_extractor_v1\aphidex_extractor_v1`.
- Resultado final: `PASS_WITH_SOURCE_WARNINGS`.
- Dominio de criaturas: 145 IDs técnicos; 24 IDs ausentes del catálogo actual corresponden al bloque legacy/playground excluido.
- Mapa: 4,451 anclas naturales, 153 anclas de defensas, 118 criaturas de supervivencia y 2 exclusivas de evento.
- Equipo: 55 armas, 9 escudos, 29 sets, 97 piezas de armadura y 48 amuletos.
- Adquisición: 209 objetos, 198 con al menos un método resuelto y 11 `unresolved_acquisition`.
- MIX.R G2: Greenhouse (72 criaturas/32 grupos), Picnic (38/7) y Resting (61/28). La fuente demuestra grupos programados, no fronteras oficiales de oleadas.
- Texturas de mapa Surface y Abyss verificadas en la exportación local de FModel.
- Excel editorial: 38 criaturas, cuatro campos editoriales completos en ES-419, EN-US y RU-RU.
- Capturas: 494 archivos (aprox. 1.65 GB), con duplicados y contenido ajeno que requiere curación.

## Compatibilidad y riesgos

- Los IDs públicos actuales deben conservarse para no romper favoritos, eliminaciones ni progreso de cartas.
- `CrowDummy` y `SnakeDummy` son excepciones actuales que no coinciden literalmente con el dominio de criaturas del extractor.
- Seis nombres ingleses del Excel no coinciden literalmente con el nombre actual y requieren aliases explícitos; no se aplicará coincidencia difusa silenciosa.
- El extractor de equipo contiene IDs técnicos y datos, pero no nombres editoriales localizados completos. ES/RU requieren glosario versionado y estado de revisión.
- Los iconos técnicos están disponibles localmente (1,838 PNG), aunque varias rutas serializadas conservan una raíz antigua.
- Las dos capturas pendientes de variantes MIX.R se tratarán solo como `known_pending_assets`; no se buscarán ni generarán.
- El build iOS no puede validarse localmente desde Windows.

## Límites confirmados

- Sin recomendador, builds, scoring, mutaciones, Milk Molars ni Hazard Resolver avanzado.
- Sin cambios en bundle IDs, Firebase, monetización, hosting, Codemagic o Functions.
- Grounded 1 conserva su comportamiento y sus datos actuales.
