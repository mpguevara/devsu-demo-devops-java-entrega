# Construcción de la imagen con controles de calidad

Esta captura corresponde al 23 de octubre de 2026, hora de El Salvador. El [resultado](build-result.json) registra la ejecución real de `docker build --progress=plain --tag devsu-demo-java:local .` con salida 0.

El [log completo](docker-build.log) contiene las 22 pruebas aprobadas, los controles JaCoCo satisfechos y PMD 7.17.0 sin infracciones. La compilación y los controles se ejecutaron dentro de Linux con JDK 17; la imagen final utiliza JRE 17 y usuario 10001:10001. Los metadatos observados están en [image-summary.json](image-summary.json).

El [primer intento](build-attempt-1.json) fue interrumpido al coincidir con la descarga y descompresión del nodo kind y detectarse presión de memoria. Su [log separado](docker-build-attempt-1.log) se conserva. No se atribuye a ese intento un fallo de pruebas. Después de estabilizar el nodo con un límite de 4 GiB, la construcción se repitió satisfactoriamente.

Esta captura demuestra construcción local; la publicación y el despliegue se acreditan mediante sus evidencias específicas. La identidad que devuelve Docker se conserva como observación; no se afirma reproducibilidad integral de todos los metadatos de una imagen OCI.
