# Etapa 2: contenedor y comprobaciones de salud

## Estado y alcance

La aplicación mantiene Java 17 y Spring Boot 3.0.5. Se incorporaron Actuator, una construcción Docker en dos etapas, ejecución sin privilegios y configuración Compose para conectar la API con PostgreSQL. La imagen se construyó localmente; **no está publicada en un registro**.

La compilación Windows y la construcción Linux ejecutaron **11 pruebas cada una, sin fallos ni errores**. Cinco corresponden a salud y exposición HTTP; las pruebas Maven utilizan el perfil `test` con H2 en memoria. Esto no convierte esos resultados en pruebas de PostgreSQL. La evidencia está en [docker-health](evidence/docker-health/), especialmente [test-summary.json](evidence/docker-health/test-summary.json), [maven-clean-verify.log](evidence/docker-health/maven-clean-verify.log) y [docker-build.log](evidence/docker-health/docker-build.log).

**La ejecución aislada del contenedor pasó las 39 comprobaciones del resumen**, con `passed=true` y `cleanupSucceeded=true` en [container/docker-results.json](evidence/docker-health/container/docker-results.json). Ese resumen contiene tres resultados agregados de salud, respaldados por **15 GET HTTP detallados**: cinco por fase UP, DOWN y recuperada. También se ejecutaron tres solicitudes de usuarios: creación, consulta y consulta posterior al reinicio de PostgreSQL.

Se comprobó UID efectivo 10001, raíz de solo lectura, `/tmp` escribible, capabilities eliminadas y `no-new-privileges`. Al detener PostgreSQL, liveness siguió UP y readiness devolvió 503/DOWN; el contenedor Java mantuvo su identificador y contador de reinicios en cero. Al arrancar de nuevo PostgreSQL sobre el mismo volumen, readiness volvió a UP y la API recuperó el usuario. El log confirmó `Graceful shutdown complete`; la salida final 143 es compatible con SIGTERM y no representó un cierre forzado por OOM. Se eliminaron exclusivamente los recursos efímeros de la prueba y se restauraron las variables de entorno. El [índice de evidencia](evidence/docker-health/README.md) conserva también los intentos fallidos y su resolución.

## Cómo se construye y qué ejecuta

```text
Código + POM + Maven Wrapper
             |
             v
  JDK 17: clean verify y JAR
             |
             v
  JRE 17: java -jar /app/app.jar
             |
             v
  API :8000 /api ---> PostgreSQL :5432 ---> volumen postgres-data
```

El [Dockerfile](../Dockerfile) usa Temurin **17.0.20.1+1** en Ubuntu Noble: JDK para compilar y JRE para ejecutar. Ambas imágenes están fijadas por etiqueta y digest SHA-256. PostgreSQL **15.19-bookworm** también está fijado por digest en [compose.yaml](../compose.yaml). El digest fija los bytes de la base seleccionada; actualizarla requiere revisar y cambiar explícitamente esa referencia.

La etapa de construcción copia el wrapper, POM y fuentes, normaliza los finales de línea de `mvnw`, y ejecuta `./mvnw -B -ntp clean verify -DargLine=-Xmx384m`. La caché BuildKit de Maven evita descargar de nuevo dependencias ya disponibles. Docker puede reutilizar una capa construida previamente si sus entradas no cambian; la segunda comprobación Linux se hizo con `--no-cache`, y volvió a ejecutar las 11 pruebas. Una prueba fallida detiene esa construcción.

La etapa final copia únicamente el JAR de la aplicación desde el constructor. No copia el JDK, fuentes ni repositorio Maven. La base JRE ya proporciona `curl`; no hay una instalación adicional con `apt` en el Dockerfile. El proceso Java es el proceso principal mediante `ENTRYPOINT` en formato de lista, para que reciba las señales de parada.

El usuario y grupo efectivos se configuran como **10001:10001**. [compose.app.yaml](../compose.app.yaml) añade las siguientes restricciones al ejecutar el contenedor:

| Opción | Motivo |
| --- | --- |
| `read_only: true` | El sistema de archivos de la imagen no se modifica durante la ejecución |
| `/tmp` en `tmpfs`, 64 MiB, `noexec,nosuid` | Java dispone de un directorio temporal escribible y efímero |
| `cap_drop: ALL` | El proceso no necesita capabilities Linux adicionales |
| `no-new-privileges:true` | Impide adquirir privilegios adicionales mediante ejecución de binarios |
| Memoria de 512 MiB y CPU de 1 | Límite inicial para el ejercicio; requiere observarse con carga real |

El usuario se define en el Dockerfile. Las restricciones de archivos, capabilities y recursos son **opciones de ejecución de Compose**: ejecutar la imagen con otro comando no las aplica automáticamente. Más adelante deberán expresarse también en los manifiestos Kubernetes.

`JAVA_TOOL_OPTIONS` configura el heap inicial como 20 % y el máximo como 60 % de la memoria que la JVM detecta disponible. Deja espacio para metaspace, hilos y memoria nativa; no garantiza por sí solo que sea imposible un OOM. Los límites elegidos no constituyen un dimensionamiento de producción.

## Construcción reproducible: lo que se midió

El wrapper se actualizó a **3.3.4**, manteniendo **Maven 3.8.7**. Son versiones de componentes diferentes. [.mvn/wrapper/maven-wrapper.properties](../.mvn/wrapper/maven-wrapper.properties) fija la distribución Maven y los SHA-256 de distribución y JAR del wrapper.

El POM fija `project.build.outputTimestamp=2026-10-21T00:00:00Z`. Es una fecha normalizada para las entradas del archivo, **no la fecha de un commit ni evidencia del momento de construcción**. `.gitattributes` normaliza texto a LF, conserva `mvnw.cmd` con CRLF y trata los JAR como binarios. `.dockerignore` permite únicamente los archivos necesarios para construir; quedan fuera `.git`, `target`, documentación y archivos locales de configuración.

| Comparación real | Resultado |
| --- | --- |
| Dos construcciones limpias Windows, mismo entorno | JAR idéntico: `ef6a2fb51d035776e88c7dffd068bb821e52e94a49ac132214121e9155645e59` |
| Dos construcciones limpias Linux con bases fijadas | JAR idéntico: `d98f0fd30931fff7d4215e793df30ef9b3a7d6968f49f4a2689a43a720f37251` |
| JAR Windows frente a JAR Linux | SHA-256 diferente; el único contenido de entrada diferente encontrado fue `META-INF/maven/devsu.devops/demo/pom.properties`, con CRLF frente a LF |

Los valores de `pom.properties` coinciden al normalizar CRLF a LF. Las pruebas están en [reproducibility.json](evidence/docker-health/reproducibility.json), [docker-reproducibility.json](evidence/docker-health/docker-reproducibility.json), [windows-linux-jar-comparison.json](evidence/docker-health/windows-linux-jar-comparison.json) y [windows-linux-metadata-difference.json](evidence/docker-health/windows-linux-metadata-difference.json). La comparación de entradas revisó contenido y fechas; no comparó todos los metadatos de compresión y directorio central. **No se demostró identidad de bytes entre sistemas operativos ni reproducibilidad de la imagen OCI completa**. Para esta entrega, el constructor Linux del Dockerfile será el camino común de empaquetado.

## Ejecutar API y PostgreSQL con Compose

Se necesita Docker Desktop con motor Linux operativo y PowerShell 7. Java instalado en Windows solo es necesario para ejecutar Maven o el JAR directamente; la construcción Docker ya incluye su JDK. Desde la raíz del repositorio:

```powershell
docker info --format '{{.OSType}}'
docker compose version

$env:PASSWORD_DB = Read-Host -MaskInput 'Contraseña de PostgreSQL local'
$env:PORT = '8000'
$env:APP_PORT = '8000'
$env:POSTGRES_PORT = '5432'

docker compose -f compose.yaml -f compose.app.yaml config --quiet
docker compose -f compose.yaml -f compose.app.yaml up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f compose.app.yaml ps
```

La contraseña se introduce sin incorporarla al historial del comando. Compose la inyecta al entorno de los contenedores; no es un secreto inaccesible para un administrador local de Docker. No se necesita crear un `.env` ni registrar una contraseña en GitHub. Conserva la contraseña elegida de manera privada si vas a reutilizar el volumen: `POSTGRES_PASSWORD` inicializa una base vacía y no cambia automáticamente la contraseña de una ya existente.

La API estará en `http://127.0.0.1:8000/api/users`. Ambos puertos se publican solamente en loopback. PostgreSQL dispone de un volumen nombrado; Flyway crea el esquema y Hibernate lo valida. El arranque espera que el servicio PostgreSQL esté saludable, pero esa dependencia inicial no garantiza su disponibilidad posterior.

| Variable | Uso |
| --- | --- |
| `PASSWORD_DB` | Credencial obligatoria para aplicación y PostgreSQL |
| `NAME_DB` | URL JDBC; Compose establece `jdbc:postgresql://postgres:5432/devsu` dentro de su red |
| `USERNAME_DB` | Usuario; Compose establece `devsu` |
| `PORT` | Puerto HTTP dentro del contenedor, 8000 por defecto |
| `APP_PORT` | Puerto publicado en Windows, 8000 por defecto; no cambia el puerto de Spring |
| `POSTGRES_PORT` | Puerto publicado de PostgreSQL en Windows; la API sigue usando `postgres:5432` en la red interna |

Por ejemplo, `APP_PORT=8003` y `PORT=8080` publican `127.0.0.1:8003` hacia el puerto 8080 del contenedor. `EXPOSE 8000` es metadato de la imagen; no publica un puerto ni cambia `server.port`. El healthcheck utiliza el puerto configurado mediante `PORT` y contempla la variable estándar `SERVER_PORT`; en el flujo Compose se usa `PORT` para mantener consistente el mapeo.

Para detener sin borrar datos:

```powershell
docker compose -f compose.yaml -f compose.app.yaml stop
Remove-Item Env:PASSWORD_DB -ErrorAction SilentlyContinue
```

`stop` conserva contenedores y volumen. Para volver a arrancar, define la contraseña correcta y repite `up`. El flujo normal no elimina volúmenes. La eliminación del volumen que contiene los datos del usuario requiere una decisión explícita.

## Liveness, readiness y parada

Solo se expone el endpoint Actuator `health` y sus grupos; no se exponen `env`, `configprops` ni `metrics`. Las respuestas de salud ocultan componentes y detalles internos.

| Ruta HTTP | Qué comprueba | Respuesta esperada |
| --- | --- | --- |
| `/api/actuator/health/liveness` | Estado interno `livenessState`, sin consultar PostgreSQL | 200 con `{"status":"UP"}` durante ejecución normal, también si cae la base |
| `/api/actuator/health/readiness` | `readinessState` y conectividad `db` | 200/UP con base disponible; 503/DOWN si falla PostgreSQL después del arranque |
| `/api/actuator/env`, `/api/actuator/configprops`, `/api/actuator/metrics` | Comprobación de exposición restringida | 404 |

Liveness permite evaluar si reiniciar el proceso puede resolver un fallo interno. Readiness indica si puede recibir tráfico útil. Excluir PostgreSQL de liveness evita provocar reinicios de todas las réplicas por una caída compartida de la base. Incluirlo en readiness permite retirar tráfico mientras esa dependencia está indisponible. Durante el arranque o la parada pueden aparecer estados de disponibilidad distintos; la tabla describe las fases estables verificables.

El `HEALTHCHECK` Docker consulta readiness cada 30 segundos, con timeout de 5 segundos, periodo inicial de 60 segundos y tres fallos consecutivos para marcar `unhealthy`. Cada solicitud `curl` tiene su propio máximo de 3 segundos. La instantánea inicial confirmó `healthy`; durante la caída breve de PostgreSQL, la instantánea del contenedor Java todavía decía `healthy`, aunque la petición HTTP directa ya devolvía 503/DOWN. El estado Docker se actualiza según su intervalo y umbrales; esta prueba no esperó a observar su transición a `unhealthy`. **Docker HEALTHCHECK no reinicia automáticamente el contenedor** ni configura las probes de Kubernetes. Estas se añadirán en su propia etapa.

Spring usa apagado ordenado con `server.shutdown=graceful` y 20 segundos por fase de cierre. Compose permite 25 segundos en total antes de forzar la terminación. Este margen permitió completar el cierre observado; varias fases lentas podrían requerir ampliarlo. La prueba aislada busca el mensaje `Graceful shutdown complete`; no equivale a una prueba de todas las peticiones posibles durante una terminación con carga.

## Repetir las comprobaciones

Para comprobar una API ya iniciada:

```powershell
.\scripts\Test-HealthApi.ps1 -BaseUrl 'http://127.0.0.1:8000/api' -ExpectedReadiness UP
```

El script no arranca ni detiene servicios. Hace cinco GET con `Accept: application/json`, timeout de 10 segundos, y guarda expectativas, respuestas, fechas, duración real y errores en `target/health-api-evidence/http-results.json`. Sale con error si alguna comprobación falla. Si un endpoint interno devuelve contenido inesperado, omite su cuerpo para evitar guardar datos sensibles.

Si se está verificando una caída de PostgreSQL en un entorno aislado y controlado, el mismo script admite `-ExpectedReadiness DOWN`. Ese parámetro **solo cambia la expectativa**; no provoca la caída. Usa diferentes `-EvidenceDirectory` para conservar las fases UP, DOWN y recuperada, en lugar de sobrescribir resultados.

La comprobación completa de contenedores utiliza una imagen ya construida:

```powershell
docker build --progress=plain -t devsu-demo-java:local .
.\scripts\Test-DockerApp.ps1
```

`Test-DockerApp.ps1` crea un proyecto Compose `devsu-verify-<identificador>` con contraseña aleatoria y volumen PostgreSQL efímero propios. Por defecto utiliza los puertos Windows 8003 y 55434 y el puerto HTTP interno 8080, comprobando también la configuración del puerto. Verifica usuario efectivo, restricciones de ejecución y healthcheck; crea y consulta un usuario; detiene únicamente su PostgreSQL para comprobar liveness UP/readiness DOWN; lo reinicia, vuelve a consultar el usuario y comprueba el apagado ordenado de Java.

El script valida los identificadores y etiquetas de sus recursos antes de administrarlos. Su limpieza elimina exclusivamente los contenedores y el volumen de ese proyecto efímero; no utiliza ni borra el volumen habitual del proyecto `devsu-java`. Restaura las variables de entorno que modifica y conserva resultados y logs en `target/docker-app-evidence`. Este procedimiento es una prueba de integración local, no evidencia de un pipeline remoto.

## Problemas reales y límites

| Hallazgo | Resolución o estado |
| --- | --- |
| El motor Docker Linux no era accesible al inicio | Se recuperó Docker Desktop aislando directorios de ejecución inactivos que contenían únicamente sockets obsoletos. El intento de renombrar un socket individual falló y quedó registrado. No hubo reinicio de fábrica ni eliminación de datos, contenedores, volúmenes o credenciales. Véanse los archivos `docker-*-recovery.json` de evidencia |
| La primera ejecución de las nuevas pruebas tuvo dos fallos de Content-Type | Actuator devolvía `application/vnd.spring-boot.actuator.v3+json`. Se añadió `Accept: application/json` a las solicitudes de prueba; la siguiente ejecución pasó las 11 pruebas. Se conserva [el log original](evidence/docker-health/maven-health-first-attempt.log) |
| Actualizar el wrapper desde el propio wrapper falló por bloqueo del JAR en Windows; el siguiente intento dividió incorrectamente un argumento PowerShell | Se utilizó Maven global y se corrigió el entrecomillado de los argumentos. [La actualización final](evidence/docker-health/wrapper-update-success.log) generó Wrapper 3.3.4 conservando Maven 3.8.7; se conservaron ambos logs fallidos |
| Los JAR Windows y Linux tienen hashes diferentes | Se compararon las entradas y se identificaron los finales de línea del `pom.properties` generado por Maven; se documenta el alcance sin afirmar identidad entre sistemas |
| Primeros dos intentos del verificador Docker fallaron leyendo `Tmpfs` | El primer `docker inspect` asumía que siempre existía esa clave; el segundo produjo un falso negativo en la comprobación. Se corrigió el acceso a la clave, se aceptó su representación en `HostConfig.Tmpfs` o `Mounts` y se verificó también escritura con `test -w /tmp`. Los [intentos 1](evidence/docker-health/container-attempt-1/docker-results.json) y [2](evidence/docker-health/container-attempt-2/docker-results.json) conservaron logs y limpiaron sus recursos |
| El tercer intento recibió HTTP 503 pero no pudo leer el estado de salud esperado | Se añadió `Accept: application/json` a la espera de readiness. El [intento 3](evidence/docker-health/container-attempt-3/docker-results.json) quedó preservado y limpió sus recursos; la ejecución final pasó las 39 comprobaciones |

Quedan pendientes cobertura, análisis estático, escaneo CVE, publicación de imagen, pipeline remoto y manifiestos Kubernetes con dos réplicas y HPA. No existe un endpoint público de esta etapa. Una instancia PostgreSQL con volumen local sigue siendo un punto único de fallo; no se verificaron backup/restauración, alta disponibilidad ni recuperación ante pérdida del disco. El usuario inicial `devsu` de PostgreSQL sigue compartido entre migración y consultas, tal como se documentó en [POSTGRESQL.md](POSTGRESQL.md).

## Referencias primarias

- [Spring Boot 3.0.5: endpoints, salud y probes Kubernetes](https://docs.spring.io/spring-boot/docs/3.0.5/reference/html/actuator.html#actuator.endpoints.kubernetes-probes).
- [Spring Boot 3.0.5: apagado ordenado](https://docs.spring.io/spring-boot/docs/3.0.5/reference/html/web.html#web.graceful-shutdown).
- [Docker: construcciones en varias etapas](https://docs.docker.com/build/building/multi-stage/) y [fijación de imágenes por digest](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions).
- [Dockerfile: HEALTHCHECK](https://docs.docker.com/reference/dockerfile/#healthcheck) y [opciones de servicios Compose](https://docs.docker.com/reference/compose-file/services/).
- [Maven: construcción reproducible](https://maven.apache.org/guides/mini/guide-reproducible-builds.html) y [Maven Wrapper](https://maven.apache.org/wrapper/).

## Preguntas de defensa

1. ¿Qué permanece en la imagen final y por qué separar JDK y JRE? ¿Qué fija un digest que no fija una etiqueta por sí sola?
2. ¿Qué restricciones define el Dockerfile y cuáles aplica Compose al ejecutar? ¿Por qué necesita `/tmp` escribible si la raíz es de solo lectura?
3. ¿Por qué PostgreSQL pertenece a readiness y no a liveness? ¿Qué hace Docker cuando el healthcheck cambia a `unhealthy`?
4. ¿Qué diferencia hay entre `PORT`, `APP_PORT` y `EXPOSE`? ¿Cómo llega la API al puerto de PostgreSQL dentro de la red Compose?
5. ¿Qué demuestran los hashes iguales de dos construcciones Linux y qué no demuestran? ¿Por qué se reservaron 25 segundos para detener una aplicación cuyo cierre tiene un plazo de 20 segundos por fase?
