# Evidencia real de calidad Maven

Estas ejecuciones corresponden al **23 de octubre de 2026**, en Windows, con Temurin 17.0.20.1+1, Maven Wrapper 3.3.4 y Maven 3.8.7. Los comandos usan heap máximo de 384 MiB para Maven y para la JVM de pruebas. No se ejecutaron pruebas runtime Docker o Kubernetes como parte de esta medición.

## Resultados antes y después

| Medición | Pruebas | Líneas globales JaCoCo | Ramas globales JaCoCo | PMD |
| --- | --- | --- | --- | --- |
| Inicial, antes de cambiar fuentes Java | 11 aprobadas | 31/74: 41,89 % | 0/62: 0 % | El primer ruleset no pudo cargar; el análisis válido posterior encontró dos violaciones |
| Pruebas ampliadas y mapper corregido, antes de configurar límites de cobertura | 22 aprobadas | 65/72: 90,28 % | 8/62: 12,90 % | Cero violaciones |
| Verificación final con límites habilitados | 22 aprobadas | 65/72: 90,28 % | 8/62: 12,90 % | Cero violaciones |

El control final exige 85 % de líneas globales y 100 % de líneas y ramas de `UserServiceImpl`. El servicio obtuvo 14/14 líneas y 2/2 ramas. No se excluyeron clases del reporte o de su medición global. Las ramas globales incluyen métodos generados por Lombok; su porcentaje bajo permanece visible. No se añadieron pruebas de código generado para aparentar cobertura.

Los dos hallazgos PMD fueron `VariableCanBeInlined` en `UserMapper`, uno por cada retorno precedido de una variable local innecesaria. La corrección mantuvo el mapeo y eliminó dos líneas ejecutables, por lo que el denominador global pasó de 74 a 72. PMD es el único analizador de esta etapa; cero violaciones no representa un escaneo de vulnerabilidades.

## Índice de archivos

| Archivo | Qué demuestra |
| --- | --- |
| [baseline/build-result.json](baseline/build-result.json) | Primer `clean verify`, sin límites de cobertura, con exit code 1 por configuración inválida de PMD |
| [baseline/maven-clean-verify.log](baseline/maven-clean-verify.log) | Las once pruebas y reporte JaCoCo terminaron; PMD rechazó dos nombres de reglas antiguos |
| [baseline/jacoco.xml](baseline/jacoco.xml) y [baseline/jacoco.csv](baseline/jacoco.csv) | Contadores originales de cobertura |
| [baseline/pmd-result.json](baseline/pmd-result.json) y [baseline/pmd-check.log](baseline/pmd-check.log) | Segundo comando `pmd:check` con nombres válidos, mismo código Java, exit code 1 por dos hallazgos reales |
| [baseline/pmd.xml](baseline/pmd.xml) y [baseline/valid-ruleset.xml](baseline/valid-ruleset.xml) | Dos violaciones del mapper y conjunto válido utilizado para encontrarlas |
| [baseline/summary.json](baseline/summary.json) | Contadores de XML JaCoCo/Surefire y del análisis PMD válido, reunidos sin ocultar el fallo del primer comando |
| [baseline/source.sha256.json](baseline/source.sha256.json) | Huellas tomadas antes de modificar Java/tests; incluye el primer POM y ruleset, que aún tenía nombres de reglas inválidos |
| [improved-measurement/build-result.json](improved-measurement/build-result.json) y [log](improved-measurement/maven-clean-verify.log) | Pruebas ampliadas y análisis satisfactorios antes de seleccionar límites |
| [improved-measurement/summary.json](improved-measurement/summary.json) y [JaCoCo XML](improved-measurement/jacoco.xml) | Medición de 90,28 % que fundamentó el control de cobertura posterior |
| [final/build-result.json](final/build-result.json) y [log](final/maven-clean-verify.log) | `clean verify` satisfactorio, límites efectivos y SHA-256 real del JAR final |
| [final/summary.json](final/summary.json) | 22 pruebas, cero fallos/errores/omitidas, contadores globales y por clase, PMD sin violaciones ni errores de procesamiento |
| [final/jacoco.xml](final/jacoco.xml), [CSV](final/jacoco.csv) y [PMD XML](final/pmd.xml) | Reportes de herramientas que respaldan el resumen |
| [final/source.sha256.json](final/source.sha256.json) | Huellas de fuentes, pruebas, configuración y POM utilizados al iniciar el comando final |
| [final/surefire-reports](final/surefire-reports/) | XML y texto por suite, con casos y resultados individuales |

## Alcance de las pruebas finales

Las seis pruebas del servicio son unitarias con MockitoExtension y sin Spring ni base de datos. Los nueve casos del controlador usan MockMvc y la aplicación real con H2 y transacciones revertidas. Se conservan cinco casos de salud/exposición, uno de repositorio y uno de carga de contexto. Son 22 casos en total, no 22 pruebas unitarias aisladas.

Se verifican creación/lectura, duplicados sin nueva escritura, validación sin persistencia, 404, ID no numérico 400 y tipo de contenido no soportado 415. Los logs de aplicación pueden contener mensajes de error esperados para esas respuestas; el resultado de Surefire es la referencia para distinguirlos de pruebas fallidas.

## Problemas observados y resolución

1. El primer ruleset contenía nombres de reglas que PMD 7.17.0 no reconoce: `UnusedImports` y `EmptyFinallyBlock`. Se consultaron las reglas de la versión incluida, se corrigieron los nombres y se sustituyó una referencia obsoleta por `VariableCanBeInlined`. Se conservan el primer log y su código de salida.
2. El primer análisis válido encontró dos retornos simplificables en el mapper. Se corrigieron sin eliminar reglas, suprimir hallazgos ni cambiar el contrato HTTP.
3. PMD advierte que no puede añadir un enlace al proyecto padre en la navegación HTML porque no hay URL configurada. El reporte se genera y el análisis es satisfactorio.
4. Surefire 2.22.2 generó un [dump del comprobador de proceso padre en Windows](final/surefire-reports/2026-10-23T18-06-40_018-jvmRun1.dump), indicando que no pudo consultar el PPID y usaría eventos NOOP. No causó fallo de las pruebas ni impidió terminar Maven; se conserva como limitación de la herramienta, sin alterar los resultados.

La medición final se ejecutó con `-DargLine=-Xmx384m`, confirmando que la configuración conserva el agente JaCoCo junto al límite de heap. Los porcentajes se calcularon como `covered / (covered + missed)` a partir de los XML. Los resúmenes no sustituyen los reportes originales.

Esta carpeta no demuestra publicación de imagen, pipeline remoto, vulnerabilidades, PostgreSQL, Kubernetes, rendimiento ni recuperación de infraestructura. Sus evidencias deben evaluarse por separado. Las decisiones, comandos y preguntas de defensa están en [CALIDAD.md](../../CALIDAD.md).
