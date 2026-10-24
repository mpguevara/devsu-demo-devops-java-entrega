# Evidencia real: Docker y salud

Las ejecuciones de esta etapa se realizaron el **21 de octubre de 2026**, en Windows con Docker Desktop y motor Linux. Los JSON registran fechas con zona horaria; algunos logs internos Java usan UTC. Los archivos conservan resultados observados, incluidos los intentos que fallaron. Esta carpeta documenta ejecuciones locales; **no es evidencia de un pipeline remoto**.

## Resultado final

| Verificación | Resultado observado | Evidencia |
| --- | --- | --- |
| Maven nativo Windows | 11 pruebas, cero fallos, cero errores y cero omitidas; construcción exitosa | [resumen](test-summary.json), [log](maven-clean-verify.log), [comando y salida](build-result.json) |
| Construcción Docker Linux | 11 pruebas aprobadas y JAR empaquetado dentro del constructor | [log](docker-build.log), [comando y salida](docker-build-result.json) |
| Segunda construcción Linux sin caché de capas | Las mismas 11 pruebas aprobadas y el mismo SHA-256 del JAR | [log](docker-rebuild.log), [comparación](docker-reproducibility.json) |
| API H2 local | Nueve comprobaciones HTTP aprobadas; proceso detenido al finalizar | [resultado](h2-http/http-results.json) |
| Aplicación y PostgreSQL en contenedores | 39 comprobaciones de nivel superior aprobadas; limpieza aprobada | [resultado completo](container/docker-results.json), [arranque Compose](container/compose-up.log), [limpieza Compose](container/compose-down.log) |

Los 39 elementos del resumen Docker contienen tres resultados agregados de fases de salud. Cada fase tiene cinco comprobaciones HTTP detalladas, **15 GET de salud/exposición en total**; no son 15 entradas individuales adicionales dentro del array de 39. También se registraron tres solicitudes de usuarios y comprobaciones sobre sus campos. Estos controles no son 39 pruebas unitarias distintas.

## Salud y continuidad de datos en Docker

La ejecución final utilizó el proyecto efímero `devsu-verify-4cb91622`, la imagen local `devsu-demo-java:local`, la API publicada en `127.0.0.1:8003` y puerto HTTP interno 8080. PostgreSQL usó su propio volumen y el puerto publicado 55434. El script terminó con `passed=true`, `cleanupSucceeded=true` y ninguna incidencia pendiente en ese resultado.

| Fase | Liveness | Readiness | Endpoints `env`, `configprops` y `metrics` | Evidencia |
| --- | --- | --- | --- | --- |
| Base disponible | 200/UP | 200/UP | 404, 404, 404 | [cinco respuestas](container/health-up/http-results.json) |
| PostgreSQL detenido | 200/UP | 503/DOWN | 404, 404, 404 | [cinco respuestas](container/health-down/http-results.json) |
| PostgreSQL iniciado de nuevo | 200/UP | 200/UP | 404, 404, 404 | [cinco respuestas](container/health-recovered/http-results.json) |

Las respuestas de salud no expusieron `components` ni `details`. El contenedor Java siguió ejecutándose durante la caída de PostgreSQL, mantuvo su identificador y su contador de reinicios en cero. La instantánea inicial confirmó el healthcheck Docker `healthy`. La instantánea `database-down` todavía mostraba `healthy`: el fallo fue breve frente al intervalo de 30 segundos y el umbral de tres fallos. **No se observó ni se afirma una transición inmediata del healthcheck Docker a `unhealthy`**; la degradación se comprobó mediante HTTP directo.

El [POST de creación](container/create-user.json) devolvió 201. El [GET inicial](container/read-user.json) y el [GET posterior al reinicio de PostgreSQL](container/recovered-user.json) devolvieron 200 con el mismo ID, DNI y nombre. Esto prueba conservación del usuario al detener y arrancar ese PostgreSQL usando el mismo volumen. No prueba backup/restauración, pérdida del volumen ni alta disponibilidad.

El [resultado Docker](container/docker-results.json) confirma UID efectivo 10001, raíz de solo lectura, capabilities eliminadas, `no-new-privileges` y `/tmp` escribible. `test -w /tmp` comprobó el permiso de escritura desde el contenedor; [runtime-uid.log](container/runtime-uid.log) conserva el UID. El [log de aplicación](container/app.log) incluye `Graceful shutdown complete`. La instantánea final registra salida **143**, compatible con SIGTERM, sin OOM; junto con ese log respalda el apagado ordenado observado. No se realizó una prueba de drenaje con carga sostenida.

La limpieza se limitó a contenedores y volumen del proyecto efímero, tras comprobar su pertenencia. Los checks finales confirman ausencia de sus contenedores y volúmenes. El volumen de uso habitual `devsu-java` no formó parte de esa limpieza.

## Construcción y reproducibilidad

- [toolchain.json](toolchain.json) y [maven-version.log](maven-version.log): Maven 3.8.7, Wrapper 3.3.4 y referencias por digest de JDK/JRE Temurin 17.0.20.1+1. El archivo Maven se contrastó con el checksum Apache indicado en el JSON.
- [image-summary.json](image-summary.json): imagen Linux amd64, usuario 10001:10001, entrypoint Java, healthcheck y versión de `curl` presente en la base JRE. `publishedToRegistry=false`.
- [source.sha256.json](source.sha256.json): huellas de archivos registradas para la etapa.
- [verification-summary.json](verification-summary.json): consolidación final de resultados, coincidencia de las 33 huellas de entrada, análisis sintáctico de seis scripts y comprobación posterior de ausencia de contenedores/volúmenes del proyecto efímero. No representa otra ejecución de las suites.
- [reproducibility.json](reproducibility.json): dos construcciones Windows produjeron el JAR `ef6a2fb51d035776e88c7dffd068bb821e52e94a49ac132214121e9155645e59`.
- [docker-reproducibility.json](docker-reproducibility.json): dos construcciones Linux produjeron el JAR `d98f0fd30931fff7d4215e793df30ef9b3a7d6968f49f4a2689a43a720f37251`.
- [windows-linux-jar-comparison.json](windows-linux-jar-comparison.json) y [windows-linux-metadata-difference.json](windows-linux-metadata-difference.json): el único contenido de entrada diferente encontrado fue `META-INF/maven/devsu.devops/demo/pom.properties`, generado con CRLF en Windows y LF en Linux. Al normalizar esos finales de línea su contenido coincide.
- [compose-config-result.json](compose-config-result.json): resultado de validación de configuración Compose.

`project.build.outputTimestamp` fija una fecha normalizada del archivo; no representa la fecha de un commit ni el momento real de compilación. Se comprobó igualdad de bytes del JAR dentro de cada entorno. La comparación entre sistemas revisó contenido y fechas de entradas; no revisó todos los metadatos de compresión y directorio central. No se afirma identidad entre el JAR Windows y Linux ni identidad reproducible de la imagen OCI completa.

## Intentos fallidos y resolución

| Incidencia real | Evidencia preservada | Resolución comprobada |
| --- | --- | --- |
| Actualizar el wrapper desde su propia JVM en Windows bloqueó `maven-wrapper.jar` | [wrapper-update.log](wrapper-update.log) | Se ejecutó el generador con Maven global |
| El primer intento con Maven global separó incorrectamente un argumento de versión en PowerShell | [wrapper-update-global-maven.log](wrapper-update-global-maven.log) | Se corrigieron las comillas; [wrapper-update-success.log](wrapper-update-success.log) confirma Wrapper 3.3.4 y Maven 3.8.7 |
| Las dos pruebas nuevas de probes esperaban `application/json`, pero Actuator devolvió su tipo JSON v3 | [maven-health-first-attempt.log](maven-health-first-attempt.log), [resultado inicial](health-first-attempt-result.json) | Se solicitó `Accept: application/json`; la siguiente ejecución aprobó las 11 pruebas |
| Docker Desktop tenía sockets de ejecución obsoletos; el renombrado de un socket individual falló | [docker-recovery.json](docker-recovery.json), [docker-runtime-recovery.json](docker-runtime-recovery.json), [docker-secrets-socket-recovery.json](docker-secrets-socket-recovery.json), [docker-combined-runtime-recovery.json](docker-combined-runtime-recovery.json) | Se aislaron directorios inactivos que contenían únicamente sockets, conservándolos con nombres de respaldo. No hubo reinicio de fábrica ni cambios en datos, contenedores, volúmenes o credenciales; el motor Linux quedó disponible |
| Intento Docker 1: `inspect` falló al asumir presente `HostConfig.Tmpfs` | [container-attempt-1/docker-results.json](container-attempt-1/docker-results.json) | Se cambió el acceso a esa clave para tolerar su ausencia |
| Intento Docker 2: falso negativo del verificador de montaje `/tmp` | [container-attempt-2/docker-results.json](container-attempt-2/docker-results.json) | Se corrigió la lectura de `Tmpfs`/`Mounts` y se añadió comprobación efectiva de escritura |
| Intento Docker 3: la espera obtuvo HTTP 503 pero no pudo leer el estado esperado del cuerpo | [container-attempt-3/docker-results.json](container-attempt-3/docker-results.json) | Se añadió `Accept: application/json` a la espera; la ejecución final verificó DOWN y recuperación |

Los tres intentos fallidos Docker registran `cleanupSucceeded=true`. Sus resultados permanecen separados de la ejecución final; no se reescribieron como exitosos.

## Límites de la evidencia

La imagen sigue local, sin publicación en registro. No se ha ejecutado un pipeline CI/CD remoto ni un despliegue Kubernetes; tampoco se han medido cobertura, análisis estático o vulnerabilidades CVE en esta etapa. No existe endpoint público. Las pruebas de datos usan valores de demostración y una base aislada, sin reproducir toda la carga de producción. La guía de ejecución y decisiones está en [DOCKER-Y-SALUD.md](../../DOCKER-Y-SALUD.md).
