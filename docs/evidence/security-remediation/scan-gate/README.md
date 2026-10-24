# Verificacion del gate de vulnerabilidades

La politica actual bloquea cualquier CRITICAL o HIGH, incluso sin version corregida. Las pruebas de esta carpeta son **pruebas unitarias offline con fixtures sinteticos**; no son resultados de un escaneo de imagen.

`policy-unit-tests/policy-test-results.json` registra una ejecucion real de ocho pruebas unitarias del evaluador: HIGH en un segundo resultado, CRITICAL sin correccion, severidades no bloqueantes, reporte vacio valido, fallo operativo, JSON invalido, reporte ausente y severidad invalida. Los fixtures usan identificadores `FIXTURE-*` y `source=unit-test-fixture`. Verifican que el gate rechace o acepte correctamente y que escriba JSON, resumen y log de politica antes de devolver un error. **No se ejecuto Trivy dentro de estas pruebas.**

`trivy-flags-result.json` registra una invocacion real de `image --help` sobre el binario fijado 0.76.1 para comprobar los flags utilizados. Los archivos `trivy-*-help.txt` conservan esa salida. `trivy-version-before-scan.json` y su variante del subcomando conservan consultas reales de version: solo contienen la version porque esa cache local aun no tiene una base de vulnerabilidades descargada. No se afirma una fecha de actualizacion de base a partir de estos archivos.

El script de escaneo real escribira `trivy-version.json` **despues** de Trivy, conservando la metadata de las bases disponibles en esa cache. Un fallo de la herramienta, de consulta de metadata o de lectura del reporte bloquea el flujo; no se informa un conteo falso de cero hallazgos.

`actionlint-result.json` y `actionlint.log` corresponden a validacion estatica real del workflow actualizado. El SHA256 permite identificar el archivo validado. Estas comprobaciones no sustituyen el nuevo escaneo de imagen ni una nueva ejecucion de GitHub Actions.
