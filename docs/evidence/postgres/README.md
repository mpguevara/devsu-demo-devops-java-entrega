# Evidencia de PostgreSQL compartido

Resultados locales obtenidos el **20 de octubre de 2026**, hora de El Salvador. Esta captura corresponde a la aplicación con perfiles `postgres`, `local` y `test`, PostgreSQL JDBC 42.7.14 y Flyway 9.5.1. La [línea base original](../baseline/README.md) permanece separada.

## Resultados observados

| Control | Resultado real |
| --- | --- |
| Maven `clean verify` | BUILD SUCCESS; 6 pruebas, 0 fallos/errores/omitidas |
| Smoke H2 del JAR, perfil local | 9 comprobaciones HTTP satisfactorias |
| PostgreSQL compartido, dos JVM | 36 comprobaciones de disponibilidad, HTTP, SQL y valores; resultado satisfactorio |
| Arranque concurrente | Dos JVM perfil postgres; historial Flyway con una única V1 exitosa |
| Lectura compartida | Usuario creado en A y leído por ID desde B, con los mismos campos |
| Peticiones concurrentes por el mismo DNI | Un 201, un 400 y un único registro para ese DNI |
| Reinicio A | B siguió respondiendo; A volvió a leer el usuario original; dos usuarios e historial V1 conservados |
| Limpieza de procesos | Las tres JVM iniciadas (A inicial, B, A reiniciada) y PostgreSQL nativo detenidos |
| Compose | `docker compose config --quiet` satisfactorio; ejecución del contenedor pendiente |

La base del ensayo era nueva y vacía. No se alteró el archivo H2 heredado ni se importaron sus datos. Los dos usuarios del ensayo son sintéticos. El esquema PostgreSQL no incluye la siembra original.

## Archivos

| Archivo | Contenido |
| --- | --- |
| [build-result.json](build-result.json), [maven-clean-verify.log](maven-clean-verify.log) | Comando, fechas, código de salida y salida real de la construcción |
| [test-summary.json](test-summary.json), [surefire/](surefire/) | Resumen extraído de los XML Surefire y reportes reales por clase; tamaño/hash del JAR |
| [source.sha256.json](source.sha256.json) | Hashes del POM y fuentes/configuración que produjeron ese JAR |
| [dependency-tree.txt](dependency-tree.txt), [maven-dependency-tree.log](maven-dependency-tree.log) | Dependencias efectivas y resultado del comando |
| [h2-http/http-results.json](h2-http/http-results.json) | Respuestas y comprobación del cierre del smoke local H2; logs en la misma carpeta |
| [shared-api/http-results.json](shared-api/http-results.json) | Las 36 comprobaciones SQL/HTTP/valores/disponibilidad, resultados y cierre de procesos |
| [shared-api/](shared-api/) | stdout/stderr separados de ambas JVM iniciales y de A reiniciada |
| [toolchain.json](toolchain.json) | Procedencia/hash de PostgreSQL portable y referencia de imagen Compose fijada por digest |
| [native-postgres-result.json](native-postgres-result.json) | Resultado del arranque/parada real de PostgreSQL nativo y tratamiento de credenciales |
| [postgres-initdb.log](postgres-initdb.log), [postgres-start.log](postgres-start.log), [postgres-server.log](postgres-server.log), [postgres-stop.log](postgres-stop.log) | Inicialización, arranque, servidor y parada de la ejecución satisfactoria |
| [compose-config-result.json](compose-config-result.json) | Validación sintáctica Compose, sin afirmar que el contenedor se ejecutó |
| [attempt-1/](attempt-1/) | Primer intento nativo fallido, conservado sin sustituirlo por resultados del intento posterior |

El primer intento logró iniciar PostgreSQL pero PowerShell se quedó esperando en la invocación directa de `pg_ctl`. Se detuvo esa instancia desde otro proceso y `createdb` falló con conexión rechazada. Su JSON registra `stopped=false` porque esa primera automatización no ejecutó la parada; la instancia sí fue detenida externamente antes del siguiente intento. No se llegaron a iniciar JVM de aplicación en ese intento. El segundo utilizó `Start-Process` oculto y espera acotada al proceso de control, con arranque, aplicación y parada satisfactorios.

Los archivos de datos PostgreSQL y las descargas están fuera del repositorio. La contraseña aleatoria de prueba se transmitió mediante variables de proceso y un archivo temporal protegido para initdb; este archivo se eliminó y las variables se restauraron. No se guardó su valor en evidencia.

## Qué no acredita esta captura

No acredita contenedores, Kubernetes, balanceo por Service, volumen Docker, reinicio de PostgreSQL, backup/restauración, HPA, escaneo de vulnerabilidades, publicación de imágenes o pipeline remoto. La verificación de persistencia corresponde al reinicio de una JVM sobre la misma base activa.

Los dos POST fueron lanzados concurrentemente, pero la prueba no fuerza que ambos pasen `existsByDni` antes del primer INSERT. La unicidad también está declarada en V1 y en el mapeo de la entidad; no se atribuye a esta captura la ejecución forzada de una carrera específica dentro del servicio.
