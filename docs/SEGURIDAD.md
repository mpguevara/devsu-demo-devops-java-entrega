# Corrección de vulnerabilidades y verificación

## Punto de partida

El [pipeline anterior](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40044688944) terminó correctamente con una política de escaneo informativa. Trivy 0.76.1 registró **9 hallazgos críticos y 40 altos**, todos en librerías Java, además de 58 medios y 14 bajos. Son coincidencias entre paquete, versión y aviso; no representan 49 exploits demostrados. Se conserva íntegro el [informe anterior](evidence/pipeline/remote-run-40044688944/security/trivy-image.json), junto a sus prioridades y resultados.

La nueva etapa corrige las dependencias y añade una política que bloquea la publicación y el despliegue si se detecta cualquier hallazgo crítico o alto. Se conservan todas las severidades, incluidas vulnerabilidades sin versión corregida. No se añaden exclusiones de CVE ni se activa `--ignore-unfixed`.

## Actualización compatible

Se eligió Spring Boot **4.1.2**, estable y compatible con Java 17, para gestionar conjuntamente las versiones del framework, servidor HTTP, serialización, persistencia y pruebas. El informe anterior sitúa la corrección de `CVE-2026-47884` en Spring MVC 7.0.9; sustituir solamente Spring 6 por Spring 7 dentro de Boot 3 no sería una actualización coherente. Boot 4.1.2 gestiona Spring Framework 7.0.10.

La aplicación conserva sus endpoints, puerto y modelo de datos. La adaptación incluye los starters modulares de Boot 4, los imports de pruebas, Jackson 3 y el módulo PostgreSQL de Flyway. La migración SQL V1 existente permanece intacta. La [guía de migración Java](MIGRACION-SEGURIDAD-JAVA.md) detalla las versiones efectivas, cambios de compatibilidad y resultados nativos.

Referencias de selección: [requisitos oficiales de Spring Boot](https://docs.spring.io/spring-boot/system-requirements.html), [BOM 4.1.2 publicado en Maven Central](https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-dependencies/4.1.2/spring-boot-dependencies-4.1.2.pom) y [compatibilidad de springdoc](https://springdoc.org/). Las versiones concretas resueltas y los resultados de cada intento se guardan en [evidencia de esta etapa](evidence/security-remediation/).

Las bases Docker conservan Temurin 17.0.20.1+1 por digest. En la consulta del 23 de octubre a las 18:43 de El Salvador, Adoptium ya publicaba 17.0.21+9, pero sus imágenes Docker todavía no estaban disponibles: los tags consultados devolvieron 404 y los tags publicados resolvían a los pins existentes. Se conserva esa [comprobación de la base](evidence/security-remediation/container-base/README.md). Es un desfase pendiente de revisar cuando se publiquen imágenes; no se inventa un digest ni se sustituye la JVM con una descarga diferente durante el build.

## Resultado del nuevo escaneo

El [run 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) reconstruyó la revisión `81beb47ba4b03f98e407860d94d143a22f2d2771` y ejecutó Trivy 0.76.1 sobre la imagen y sobre el SBOM extraído de ella. El [reporte completo de imagen](evidence/pipeline/remote-run-40048321809/security/trivy-image.json), el [reporte SBOM](evidence/pipeline/remote-run-40048321809/sbom-security/trivy-sbom.json) y sus resúmenes confirman que ambos escaneos y gates terminaron correctamente.

| Hallazgos paquete-CVE | Antes | Después |
| --- | ---: | ---: |
| CRITICAL | 9 | **0** |
| HIGH | 40 | **0** |
| MEDIUM | 58 | 28 |
| LOW | 14 | 4 |
| Total | 121 | 32 |

Los 49 pares paquete-CVE críticos y altos anteriores ya no aparecen. El escaneo SBOM informa **cero hallazgos en todas las severidades** y comprueba las 14 coordenadas históricas afectadas; los 32 hallazgos de imagen restantes corresponden a paquetes Ubuntu. De ellos, 31 no tienen una versión corregida indicada por el reporte. Se conservan la [comparación final calculada](evidence/security-remediation/final-scan-comparison.json) y el [inventario pendiente](evidence/security-remediation/remaining-medium-low.csv), sin descartar las severidades no bloqueantes.

El restante con corrección indicada es **MEDIUM `CVE-2026-85091`**, en `zlib1g`: instalada `1:1.3.dfsg-3.1ubuntu2.2`, corregida `1:1.3.dfsg-3.1ubuntu2.3`. Permanece pendiente, visible y fuera del bloqueo CRITICAL/HIGH solicitado. Una actualización posterior de la base requiere fijar el nuevo digest y repetir escaneos y validaciones; no se introduce `apt upgrade` sin versiones en el Dockerfile.

La [primera ejecución de la actualización](evidence/pipeline/remote-run-40046900827/README.md) tenía una limitación: el análisis de imagen produjo 62 registros Java, pero solo identificó 59 de las 98 rutas JAR; los registros adicionales corresponden a componentes internos y la aplicación. Faltaban 39 JAR, entre otros Spring Framework, Spring Boot y Micrometer. La [comprobación inicial](evidence/security-remediation/image-java-inventory-verification.json) y el [diagnóstico por ruta y hash](evidence/security-remediation/container-base/jar-identification-diagnostic.json) conservan este resultado. Por ello se añadió el SBOM y su segundo gate, en lugar de interpretar la ausencia de hallazgos como cobertura completa.

El control final vinculó **97/97 JAR por SHA-256** al SBOM extraído de la misma imagen. Confirmó los PURL de los **110/110 componentes** del SBOM dentro de los 111 registros incorporados por Trivy, y las 14 coordenadas afectadas anteriormente. La diferencia de 98 a 97 JAR elimina únicamente el auxiliar de extracción no utilizado `jarmode-tools`. El SBOM conserva además componentes del grafo Maven, como starters y DevTools, que no están en el JAR; esa comprobación conservadora no sustituye verificar cada archivo realmente empaquetado. Véanse [inventario posterior al escaneo](evidence/pipeline/remote-run-40048321809/sbom-security/inventory-after-scan.json) y [comprobación de todos los componentes](evidence/pipeline/remote-run-40048321809/sbom-security/all-components-inventory-check.json).

La [metadata final de Trivy](evidence/pipeline/remote-run-40048321809/security/trivy-version.json) registra la base de vulnerabilidades actualizada el 23 de octubre a las 19:15:43 UTC y descargada el 24 de octubre a las 01:10:37 UTC; esta última hora equivale al 23 de octubre a las 19:10 en El Salvador. La base Java de identificación conserva sus propias fechas. Se registra la evidencia disponible, sin afirmar cobertura exhaustiva de avisos de seguridad.

La suite nativa y el job de calidad aprobaron **22 pruebas, PMD sin infracciones y gates JaCoCo intactos**. Ocho pruebas unitarias de política y cuatro de inventario comprueban rechazos y errores; están identificadas como fixtures y separadas de los escaneos reales. La [publicación](evidence/pipeline/remote-run-40048321809/publication.json) registra el digest `sha256:5186197365985f9249e005d82a47b6b7dc3abd7c88b89de6a2dbb45686d7b56e`. CI aprobó 30 comprobaciones Kubernetes, 21.354 GET exitosos/0 fallidos y HPA de dos a cuatro Ready. El [After del clúster local existente](evidence/security-remediation/postgres-upgrade/after.json) conservó los dos usuarios anteriores, el PVC y el historial Flyway/V1 al actualizar a esa misma imagen.

## Alcance y límites

El escaneo solicitado se aplica a la imagen Java construida. Su resultado depende del contenido de la imagen, la versión del escáner y la base de avisos consultada. Cero hallazgos críticos y altos, cuando se verifica, no significa ausencia de vulnerabilidades ni sustituye una revisión de autorización, infraestructura, credenciales o exposición de red.

Los informes y las mediciones anteriores permanecen como capturas históricas. No se modifican para aparentar que las versiones anteriores estaban corregidas. Los nuevos resultados se documentan después de ejecutar las herramientas.

## Preguntas de defensa

1. ¿Por qué se actualizó el BOM de Spring Boot en conjunto en lugar de sustituir únicamente un JAR vulnerable?
2. ¿Cómo distingue el pipeline un fallo operativo del escáner de un escaneo terminado que encuentra una vulnerabilidad alta?
3. ¿Qué demuestra el escaneo de la imagen que se publica y qué no demuestra un resultado de cero críticos y altos?
4. ¿Cómo comprobamos que actualizar Flyway y Hibernate conserva el esquema y los datos existentes?
5. ¿Por qué deben conservarse los reportes anteriores y las vulnerabilidades medias o bajas restantes?
