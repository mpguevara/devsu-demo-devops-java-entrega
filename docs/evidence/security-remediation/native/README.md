# Evidencia nativa de la remediación Java

Validación ejecutada el **23 de octubre de 2026**, hora de El Salvador, con Temurin 17.0.20.1+1 y Maven 3.8.7. Se mantuvieron los heaps máximos de 384 MiB para Maven y el proceso de pruebas. Durante las dos suites completas y el smoke HTTP, el clúster propio estaba detenido para evitar competir por memoria; no se ejecutó Docker como parte de esas comprobaciones. La generación aislada posterior del SBOM se realizó con Docker y el nodo activos, sin compilar ni lanzar pruebas.

Las copias XML de Surefire tienen saneado únicamente el valor de `java.library.path`. El [manifiesto de saneamiento](../../report-metadata-sanitization/README.md) verifica resultados y contenido restantes idénticos, con hashes antes/después y la referencia Git original de aquella operación. La [reescritura posterior de `main`](../../history-metadata-sanitization/README.md) conserva su correspondencia de revisiones. Estas operaciones no repiten ni modifican la ejecución de pruebas.

## Resultados

| Verificación | Resultado | Evidencia |
| --- | --- | --- |
| Primera migración a Boot 4.1.2 | 22 pruebas aprobadas, PMD 0, todos los gates JaCoCo aprobados | [comando](attempt-1/build-result.json), [log](attempt-1/maven-clean-verify.log), [resumen](attempt-1/summary.json) |
| Segundo `clean verify`, tras extender el test existente con un ID enviado por el cliente | 22 pruebas aprobadas, PMD 0, todos los gates aprobados | [comando y motivo](attempt-2/build-result.json), [log](attempt-2/maven-clean-verify.log), [resumen](attempt-2/summary.json) |
| HTTP real sobre el JAR con H2 aislado | Nueve comprobaciones aprobadas; proceso detenido | [resultado HTTP](http-smoke/http-results.json), [stdout](http-smoke/application.stdout.log), [stderr](http-smoke/application.stderr.log) |
| Identidad del JAR de ambos builds y del smoke test | SHA-256 idéntico | [jar-identity.json](jar-identity.json) |
| Dependencias que originaron 49 hallazgos CRITICAL/HIGH | Versiones actualizadas presentes; versiones anteriores ausentes en el JAR | [matriz](resolved-dependency-mapping.json), [librerías efectivas](attempt-2/packaged-libraries.json) |
| Generación aislada de SBOM | Exit code 0; 110 componentes, 14 coordenadas presentes y hashes coincidentes de 97/98 JAR del artefacto anterior | [índice y límite del auxiliar jarmode](sbom-generation/README.md) |

El JAR comprobado tiene SHA-256 `7a31462fbc2709e493d7bc0658c464f9eebeaee89a7a6f39ccb0689b6d02632c`. La segunda compilación solo añadió una aserción de contrato a una prueba y produjo los mismos bytes de aplicación. Se conservaron los dos resultados, sin presentar la segunda ejecución como una corrección de un fallo inexistente del primer build.

## Archivos y trazabilidad

- [proposal/bom-selected-versions.json](proposal/bom-selected-versions.json): versiones consultadas en el BOM publicado antes de implementar.
- [proposal/official-sources.json](proposal/official-sources.json): fuentes primarias utilizadas y propósito de cada consulta.
- [proposal/fix-plan.json](proposal/fix-plan.json): los 49 hallazgos originales y la propuesta previa; sus estados de planificación se conservaron como tales.
- [attempt-1/source.sha256.json](attempt-1/source.sha256.json) y [attempt-2/source.sha256.json](attempt-2/source.sha256.json): hashes de los 25 archivos de entrada de cada verificación.
- [attempt-2/jacoco.xml](attempt-2/jacoco.xml), [CSV](attempt-2/jacoco.csv) y [PMD XML](attempt-2/pmd.xml): reportes originales de herramientas.
- [attempt-2/surefire-reports](attempt-2/surefire-reports/): casos individuales en XML y texto; la prueba de alta y consulta comprueba el ID asignado por servidor aunque el cliente envíe `2147483647`.

## Lectura correcta de las métricas

La suite conserva seis casos unitarios del servicio, nueve casos de contrato con MockMvc/H2, cinco de salud, uno de repositorio y uno de contexto: **22**, sin omisiones. Las comprobaciones HTTP del JAR son otra verificación, no nueve pruebas unitarias adicionales.

Ambos builds de remediación registraron **51/58 líneas, 87,93 %**, y **2/2 ramas, 100 %**. El servicio tiene catorce líneas y dos ramas, todas cubiertas. Los límites no cambiaron: 85 % global de líneas y 100 % en líneas y ramas del servicio.

El BOM actualiza Lombok a 1.18.48, que marca código generado por defecto. JaCoCo lo filtra automáticamente. La medición histórica con Lombok 1.18.26, de **65/72 líneas y 8/62 ramas**, permanece en [quality](../../quality/README.md). No se añadieron exclusiones ni se modificaron los contadores históricos; comparar únicamente los porcentajes sin sus denominadores daría una conclusión engañosa. El saneamiento posterior de rutas locales no cambia estas mediciones.

PMD solo emitió la advertencia de navegación por falta de URL del proyecto padre. No hubo fallos de compilación o pruebas nativas que ocultar o corregir. Esta carpeta no prueba ausencia de CVE ni sustituye el nuevo escaneo de imagen y pipeline remoto. La [guía de migración](../../../MIGRACION-SEGURIDAD-JAVA.md) explica las decisiones y los límites.
