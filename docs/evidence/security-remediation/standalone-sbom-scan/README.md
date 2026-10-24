# Escaneo real del SBOM Maven independiente

El 24 de octubre de 2026 UTC se ejecuto realmente Trivy `0.76.1` sobre `target/bom.json`, generado previamente por CycloneDX Maven plugin `2.9.3`. Se guardo una copia exacta en [bom.json](bom.json); [execution.json](execution.json) conserva su SHA256, comando y tiempos. Esta prueba no uso Docker ni reconstruyo Java y **no valida la imagen final**: demuestra que el formato y las coordenadas del SBOM son aceptados por el escaner fijado.

Resultado: proceso Trivy exit `0`, gate aprobado, **0 CRITICAL, 0 HIGH, 0 MEDIUM, 0 LOW y 0 UNKNOWN**. [trivy-sbom.json](trivy-sbom.json) conserva el reporte completo y [scan-summary.json](scan-summary.json) identifica `source=trivy-real-sbom-scan`. La fecha de la base se conserva en [trivy-version.json](trivy-version.json).

El inventario devuelto contiene 111 registros, incluidos los 110 componentes del SBOM y la aplicacion. Se verificaron todos los PURL de esos 110 componentes: ninguno falta, segun [inventory-summary.json](inventory-summary.json). No se equipara el numero de componentes con el numero de JAR empaquetados: la validacion de cada JAR por SHA256 corresponde al siguiente CI, que extraera SBOM y JAR de la misma imagen.

[trivy.log](trivy.log) conserva tambien las advertencias reales de Trivy: informa las limitaciones de un SBOM externo y no acepta algunos algoritmos adicionales de hash generados por CycloneDX. El SBOM conserva SHA256, que el validador propio comprueba directamente; no se descartan los componentes ni los mensajes del escaner. Un resultado sin hallazgos representa el snapshot consultado y no garantiza ausencia de todo riesgo.
