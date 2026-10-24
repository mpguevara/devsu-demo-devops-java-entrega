# Demo Devops Java

This is a simple application to be used in the technical test of DevOps.

## Prueba DevOps: estado verificable

**Etapa 1 completada el 20 de octubre de 2026, hora de El Salvador.** Se revisaron la aplicación y el entorno, se seleccionó Java 17 y se ejecutaron la compilación, las seis pruebas originales, el empaquetado y nueve comprobaciones HTTP del JAR. La captura de esa etapa conserva los hashes y resultados de la aplicación original.

**Persistencia compartida implementada y verificada:** PostgreSQL es el perfil predeterminado, con Flyway y `ddl-auto=validate`. En esa etapa, dos JVM conectadas a PostgreSQL 15.19 real aprobaron **36 comprobaciones de integración**, incluida lectura compartida, peticiones concurrentes y conservación de datos tras reiniciar A. Las JVM y PostgreSQL nativo quedaron detenidos.

**Etapa 2 completada el 21 de octubre de 2026:** imagen Docker multietapa, usuario 10001 y Actuator implementados. Pasaron **11 pruebas Maven** tanto en Windows como dentro de Docker Linux, nueve comprobaciones HTTP H2 del JAR y **39 comprobaciones del contenedor con PostgreSQL**. Se verificaron caída y recuperación de la BD sin reiniciar Java, persistencia tras reiniciar PostgreSQL y apagado ordenado. Dos construcciones limpias Linux produjeron el mismo JAR. El motor Docker ya funciona; los recursos de las pruebas quedaron eliminados y la imagen permanece local.

**Calidad verificada tras actualizar dependencias, el 23 de octubre de 2026:** 22 pruebas aprobadas, PMD sin infracciones y cobertura JaCoCo de **87,93 % de líneas**, con 100 % de líneas y ramas del servicio. La nueva versión de Lombok marca código generado que JaCoCo filtra automáticamente; por eso los contadores difieren del resultado histórico de 90,28 %. Se mantienen los gates de 85 % global y 100 % del servicio, sin exclusiones añadidas. Véase [la explicación de la medición](docs/CALIDAD.md).

**Kubernetes local actualizado y verificado:** 30 comprobaciones aprobadas sobre la imagen final, con lectura entre pods, Ingress y persistencia al reemplazar Java y PostgreSQL. El HPA aumentó su objetivo de dos a cuatro réplicas con carga HTTP real: tres Ready durante la carga y cuatro en la observación posterior. Los 16 trabajadores registraron **7.104 GET exitosos y cero fallidos** en ese ensayo acotado. Antes del ensayo, otras 19 comprobaciones conservaron los dos usuarios anteriores, el PVC y el historial Flyway/V1 al actualizar. Véase [evidencia local](docs/evidence/security-remediation/local-kubernetes/README.md). Estos resultados no representan un SLA ni un dimensionamiento de producción.

El [repositorio público](https://github.com/mpguevara/devsu-demo-devops-java) y el [pipeline final aprobado](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) están disponibles. El run validó la revisión `81beb47ba4b03f98e407860d94d143a22f2d2771`: calidad, construcción, escaneos de imagen y SBOM, publicación GHCR y Kubernetes. La validación remota aprobó 30 comprobaciones, con HPA de dos a cuatro Ready y 21.354 GET exitosos y cero fallidos durante su carga acotada. Los resultados anteriores, incluidos fallos y correcciones, permanecen como evidencia histórica. **No existe ni se requiere un endpoint público**; el acceso de la API queda en localhost.

**Vulnerabilidades críticas y altas corregidas y verificadas:** el escaneo final pasó de **9 críticos y 40 altos a 0 críticos y 0 altos**. Se actualizó el stack a Spring Boot 4.1.2 y dependencias compatibles. Además del escaneo de imagen, el pipeline vinculó **97/97 JAR por SHA-256** al SBOM y confirmó sus **110/110 componentes** en el inventario de Trivy. El escaneo SBOM reportó cero hallazgos; quedan **28 medios y 4 bajos en Ubuntu**, sin ocultarlos. La publicación y el despliegue bloquean ante cualquier crítico o alto, errores o inventario incompleto. Véanse la [corrección y sus límites](docs/SEGURIDAD.md) y la [comparación final](docs/evidence/security-remediation/final-scan-comparison.json).

- [Diagnóstico, resultados y problemas encontrados](docs/DIAGNOSTICO.md).
- [Plan guiado para los siete días y preguntas de defensa](docs/PLAN-DE-TRABAJO.md).
- [Evidencia de la línea base](docs/evidence/baseline/README.md).
- [Guía de PostgreSQL compartido, perfiles y migraciones](docs/POSTGRESQL.md).
- [Evidencia de PostgreSQL con dos instancias](docs/evidence/postgres/README.md).
- [Guía de Docker, salud y ejecución con Compose](docs/DOCKER-Y-SALUD.md).
- [Evidencia de construcción y ejecución del contenedor](docs/evidence/docker-health/README.md).
- [Pruebas, PMD, cobertura y controles de calidad](docs/CALIDAD.md).
- [Evidencia de calidad y medición inicial](docs/evidence/quality/README.md).
- [Pipeline como código y ejecución local](docs/PIPELINE.md).
- [Corrección de vulnerabilidades, compatibilidad y límites del escaneo](docs/SEGURIDAD.md).
- [Kubernetes privado, acceso local y verificación](docs/KUBERNETES.md).
- [Evidencia del pipeline final aprobado](docs/evidence/pipeline/remote-run-40048321809/README.md).
- [Evidencia de corrección y problemas reales encontrados](docs/evidence/security-remediation/README.md).
- [Consolidación final de implementación y evidencias](docs/evidence/final-verification.json).
- [README original sin modificaciones](docs/evidence/baseline/README-original.md).

### Entorno identificado

| Componente | Resultado observado |
| --- | --- |
| Sistema | Windows 11 Home Single Language, x64, versión 10.0.26200; PowerShell 7.6.5 |
| CPU y memoria | Intel Core i7-13620H, 16 procesadores lógicos; 15,63 GiB RAM total y aproximadamente 1,2–1,3 GiB libres durante el diagnóstico |
| Disco C: | Aproximadamente 693 GiB libres |
| Java inicial | Oracle JDK 26; `JAVA_HOME` no definido |
| Java utilizado | Temurin JDK 17.0.20.1+1 portable; ZIP verificado por SHA-256 |
| Maven | Global 3.9.15; construcción con Maven 3.8.7 mediante Wrapper 3.3.4 y checksums fijados |
| Docker | Cliente y motor Linux 29.6.1; Docker Desktop 4.80.0 y Compose 5.1.4 comprobados en la etapa 2 |
| Kubernetes | kubectl 1.36.1 inicial; kind 0.33.0 y Kubernetes 1.36.4 instalados el 23 de octubre; kubeconfig dedicado fuera del repositorio |
| Otros | Git 2.54.0; WSL2 docker-desktop; CLI GitHub 2.103.2 portable; instaladores fijados para kind, kubectl y Trivy |
| GitHub | Repositorio público `mpguevara/devsu-demo-devops-java`; Actions, GHCR y validación Kubernetes aprobados |

La copia inicial procede de un ZIP. El 23 de octubre se inicializó Git para registrar el trabajo real. Docker volvió a presentar sockets obsoletos; se recuperó conservando esos directorios como respaldo, sin restablecerlo ni borrar volúmenes. La memoria disponible del diagnóstico es una captura histórica; las validaciones actuales se ejecutan por separado y el nodo kind se limita a 4 GiB y cuatro CPU.

### Versiones y dependencias confirmadas

La versión actual mantiene Java **17** y ModelMapper **2.4.5**, y actualiza Spring Boot a **4.1.2** y springdoc a **3.1.1** para corregir las vulnerabilidades identificadas. El BOM gestiona Spring Framework **7.0.10**, Tomcat **11.0.27**, Jackson **3.1.7**, H2 **2.4.240**, Flyway **12.4.0** y PostgreSQL JDBC **42.7.14**. Flyway incorpora ahora su módulo PostgreSQL. La [guía de seguridad](docs/SEGURIDAD.md) explica la migración y su validación.

La base original utilizaba Spring Boot **3.0.5**, Spring **6.0.7**, Hibernate **6.1.7.Final**, H2 **2.1.214**, Lombok **1.18.26**, JUnit **5.9.2** y Mockito **4.8.1**. Se conservan el [árbol inicial](docs/evidence/baseline/dependency-tree.txt) y el [árbol de la etapa PostgreSQL](docs/evidence/postgres/dependency-tree.txt). Java 17 era compatible con la base y sigue siendo compatible con [Spring Boot 4.1.2](https://docs.spring.io/spring-boot/system-requirements.html); no se usa el Java 26 global para las verificaciones.

### Preparación en Windows y ejecución local

Desde la raíz del proyecto, en PowerShell 7:

```powershell
# Descarga portable fuera del repositorio; no cambia la configuración global.
.\scripts\Install-Java17.ps1
. .\scripts\Use-Java17.ps1
.\mvnw.cmd -v

# Límite de heap usado en esta máquina durante la línea base.
$env:MAVEN_OPTS = '-Xmx384m -Dfile.encoding=UTF-8'
.\mvnw.cmd -B -ntp clean verify '-DargLine=-Xmx384m'
```

Si ya tienes otro JDK 17, selecciona su directorio mediante `Use-Java17.ps1 -JdkHome 'C:\ruta\al\jdk-17'`. El script valida que sea un JDK 17 completo. La selección afecta a la terminal actual y a sus procesos hijos. `MAVEN_OPTS` limita el heap de Maven y `argLine` el heap del proceso de pruebas; no representan el consumo total de memoria.

Para ejecutar el JAR con el perfil PostgreSQL predeterminado, prepara las tres variables de conexión y arranca solo PostgreSQL con el archivo Compose base:

```powershell
$env:USERNAME_DB = 'devsu'
$env:NAME_DB = 'jdbc:postgresql://127.0.0.1:5432/devsu'
$env:PASSWORD_DB = Read-Host -MaskInput 'Contraseña de PostgreSQL local'
docker compose up -d --wait
java -Xms64m -Xmx256m -jar .\target\demo-0.0.1.jar --server.address=127.0.0.1
```

También puedes usar `.\mvnw.cmd spring-boot:run` con esas variables y PostgreSQL accesible. La API queda en `http://127.0.0.1:8000/api/users` y Swagger en `http://127.0.0.1:8000/api/swagger-ui.html`. Flyway crea el esquema y PostgreSQL inicia sin los tres usuarios de demostración. No se importan automáticamente los datos del archivo H2. La [guía PostgreSQL](docs/POSTGRESQL.md) explica los perfiles, credenciales, volumen y alternativa nativa comprobada.

Para una comprobación aislada del JAR:

```powershell
.\scripts\Test-LocalApi.ps1
# Reporte: target/local-api-evidence/http-results.json
```

El script selecciona `local` explícitamente, inicia el JAR en loopback, usa H2 en memoria, comprueba GET/POST, errores esperados, Swagger y OpenAPI, y detiene exclusivamente el proceso que inició. Los datos de esta comprobación se descartan al terminar. Para probar dos JVM contra una BD PostgreSQL de prueba vacía, usa `scripts/Test-PostgresApi.ps1` siguiendo la [guía](docs/POSTGRESQL.md#repetir-la-verificación-entre-dos-instancias).

En Linux/macOS con JDK 17, los comandos equivalentes son `sh ./mvnw clean verify` y `sh ./mvnw spring-boot:run`. El Dockerfile ejecutó `./mvnw clean verify` sobre Linux; no se ha verificado la ejecución directa en macOS.

### Configuración actual

| Variable | Valor en perfil PostgreSQL | Función |
| --- | --- | --- |
| `PORT` | 8000 | Puerto HTTP; contexto fijo `/api` |
| `NAME_DB` | Obligatoria | URL JDBC PostgreSQL; no es solamente el nombre de la BD |
| `USERNAME_DB` | Obligatoria | Usuario PostgreSQL |
| `PASSWORD_DB` | Obligatoria | Contraseña inyectada; no se guarda en Git |

`postgres` es el perfil predeterminado: driver PostgreSQL, Flyway habilitado, inicialización SQL desactivada y Hibernate en `validate`. El perfil `local` conserva el modo H2 heredado, que recrea tablas y siembra ejemplos; se activa explícitamente y no es el modo para réplicas. Las pruebas Maven usan `test`, con H2 en memoria y sin semillas. El script Kubernetes genera la contraseña en memoria y crea un Secret por entrada estándar, sin guardarla en manifiestos, argumentos ni evidencias.

### Pruebas, calidad y pipeline

La ejecución actual `clean verify` terminó con **22 pruebas, 0 fallos, 0 errores y 0 omitidas**, y generó `target/demo-0.0.1.jar`. Hay seis pruebas unitarias de servicio aisladas con Mockito, nueve casos de controlador con Spring/MockMvc/H2, una prueba JPA, una de contexto y cinco casos de salud. Las pruebas Spring activan `test`, sin semillas ni PostgreSQL. No se presentan todos estos casos como pruebas unitarias aisladas.

Las verificaciones anteriores de 39 comprobaciones Docker y 36 comprobaciones PostgreSQL con dos JVM conservan sus artefactos y alcance históricos; véanse [persistencia](docs/evidence/postgres/README.md) y [contenedor](docs/evidence/docker-health/README.md). La [evidencia de la actualización](docs/evidence/security-remediation/native/README.md) conserva los dos nuevos `clean verify`, las nueve comprobaciones HTTP del JAR y el test del ID de solo lectura con Jackson 3. La [medición anterior](docs/evidence/quality/README.md) permanece disponible.

JaCoCo **0.8.15** mide cobertura; Maven PMD Plugin **3.28.0**, con PMD **7.17.0**, aplica nueve reglas explícitas. Los controles requieren al menos 85 % de líneas globales y 100 % de líneas/ramas del pequeño servicio. Tras el filtrado automático de código generado, JaCoCo observa dos ramas del servicio y ambas se ejecutan; esto no significa que estén probadas todas las condiciones posibles de la aplicación. La [guía de calidad](docs/CALIDAD.md) explica los contadores y sus límites.

[GitHub Actions](.github/workflows/ci.yml) define calidad → construcción/escaneo de imagen y SBOM → publicación GHCR → despliegue y validación kind. El SBOM CycloneDX se genera en el mismo build Maven y se copia junto al JAR en la imagen; sus hashes deben cubrir todas las librerías empaquetadas. Trivy bloquea el flujo ante cualquier hallazgo crítico o alto, fallos operativos, reportes inválidos o inventario incompleto; conserva todas las severidades. Completar el pipeline no demuestra ausencia de todo riesgo. Las acciones y herramientas están fijadas a versiones y hashes. En pull requests no se publica ni se utilizan credenciales de publicación. El clúster del runner es efímero y desaparece al terminar; no proporciona un servicio permanente ni un endpoint público.

### Construcción de imagen y despliegue

El [Dockerfile](Dockerfile) compila y prueba con JDK 17 y ejecuta el JAR con JRE 17 y usuario **10001:10001**. Las bases Temurin y PostgreSQL están fijadas por digest. [compose.app.yaml](compose.app.yaml) aplica raíz de solo lectura, `/tmp` temporal, capabilities eliminadas, límites de memoria/CPU y acceso por loopback. `.dockerignore` limita el contexto a las entradas de construcción.

Para construir y ejecutar todo con Docker Desktop Linux y PowerShell 7, sin instalar Java en Windows:

```powershell
$env:PASSWORD_DB = Read-Host -MaskInput 'Contraseña de PostgreSQL local'
docker compose -f compose.yaml -f compose.app.yaml up -d --build --wait --wait-timeout 180
Invoke-RestMethod 'http://127.0.0.1:8000/api/actuator/health/readiness'
Invoke-RestMethod 'http://127.0.0.1:8000/api/users'
docker compose -f compose.yaml -f compose.app.yaml stop
Remove-Item Env:PASSWORD_DB -ErrorAction SilentlyContinue
```

Este flujo conserva el volumen de datos; reutilizarlo requiere la contraseña con que se inicializó. Los puertos por defecto son 8000 para la API y 5432 para PostgreSQL en Windows. Para otra asignación, consulta `PORT`, `APP_PORT` y `POSTGRES_PORT` en la [guía de Docker](docs/DOCKER-Y-SALUD.md). Liveness no consulta la BD; readiness incluye su conectividad. El healthcheck Docker usa readiness, pero no reinicia el contenedor ni sustituye las probes Kubernetes.

En la etapa Docker del 21 de octubre, dos construcciones limpias Linux generaron el mismo SHA-256 del JAR. El JAR Windows difería por los finales de línea de `pom.properties` generado por Maven. No se afirma identidad entre sistemas operativos ni de la imagen OCI completa. La [evidencia histórica](docs/evidence/docker-health/README.md) conserva hashes, logs e intentos fallidos. El pipeline publica una imagen identificada por commit, registra su digest y despliega los mismos bytes construidos, transferidos por archivo con checksum.

La [publicación final](docs/evidence/pipeline/remote-run-40048321809/publication.json) corresponde a `ghcr.io/mpguevara/devsu-demo-devops-java:81beb47ba4b03f98e407860d94d143a22f2d2771`, con digest `sha256:5186197365985f9249e005d82a47b6b7dc3abd7c88b89de6a2dbb45686d7b56e`. El workflow publica mediante su `GITHUB_TOKEN` temporal, limitado a `packages: write` en ese job. Las instrucciones para publicar desde terminal con una credencial propia están en la guía de pipeline.

Los [manifiestos Kubernetes](k8s/) definen dos réplicas Java como mínimo, Service, requests/limits, probes, ConfigMap y HPA de dos a cuatro réplicas. PostgreSQL usa StatefulSet, PVC y credenciales inyectadas desde un Secret generado fuera del repositorio. Traefik implementa Ingress con el host local `devsu.local`; un port-forward limitado a loopback permite probarlo sin DNS ni servidor público. metrics-server proporciona CPU al HPA. Su configuración se distingue de la observación real del escalamiento, que debe quedar en los resultados de verificación.

Una instancia PostgreSQL con PVC es proporcionada al ejercicio, pero no tiene alta disponibilidad. En Kubernetes se verificaron lectura compartida, conservación del usuario al reemplazar ambos tipos de pod y mantenimiento del mismo PVC. La carga HTTP y las métricas de CPU acreditan el escalamiento observado; no son un dimensionamiento de producción. Backup/restauración y recuperación ante pérdida del disco siguen sin verificarse.

El primer ensayo de recuperación encontró un HTTP 500 transitorio con PostgreSQL headless. Se conservó ese resultado y se separó el Service headless de identidad (`postgres`) del Service ClusterIP de cliente (`postgres-client`). El verificador espera tres respuestas consecutivas de readiness antes de consultar los datos, sin repetir escrituras. La [evidencia Kubernetes](docs/evidence/kubernetes/README.md) registra ambos intentos y el resultado final.

### Desplegar y validar Kubernetes sin endpoint público

En PowerShell 7, con Docker Linux funcionando:

```powershell
.\scripts\ci\Install-Kubectl.ps1
.\scripts\Install-Kind.ps1
docker build -t devsu-demo-java:local .
.\scripts\Deploy-Kubernetes.ps1 -Image devsu-demo-java:local -LoadImage
.\scripts\Test-Kubernetes.ps1
```

El despliegue utiliza el contexto dedicado `kind-devsu` y un kubeconfig fuera del repositorio. No modifica el contexto predeterminado del usuario. En Windows el preflight solicita 3 GiB de memoria libre; en la ejecución de esta máquina se utilizó `-AllowLowMemory` conscientemente, con el nodo limitado a 4 GiB y cuatro CPU. La [guía Kubernetes](docs/KUBERNETES.md) explica ese recurso y sus límites.

El verificador crea datos sintéticos, reemplaza pods y genera carga HTTP en ese clúster aislado. Conserva el PVC y los usuarios, y retira sus Jobs y port-forwards al terminar. Para acceder manualmente, deja este comando en una terminal:

```powershell
kubectl --kubeconfig "$HOME/.kube/devsu-kind.config" --context kind-devsu -n devsu port-forward --address 127.0.0.1 service/traefik 18080:80
```

En otra terminal:

```powershell
Invoke-RestMethod 'http://127.0.0.1:18080/api/users' -Headers @{ Host = 'devsu.local'; Accept = 'application/json' }
kubectl --kubeconfig "$HOME/.kube/devsu-kind.config" --context kind-devsu -n devsu get pods,hpa,pvc,ingress
```

El host de Ingress se envía en la cabecera HTTP; no requiere editar DNS ni publicar un dominio. Para repetir la automatización completa desde una máquina con recursos suficientes, selecciona JDK 17 y ejecuta `scripts/ci/Invoke-LocalPipeline.ps1`. La [guía de pipeline](docs/PIPELINE.md) describe sus etapas, la publicación opcional desde terminal y los artefactos de GitHub Actions.

### Diagramas

Línea base **ejecutada**:

```mermaid
flowchart LR
    Test[Pruebas HTTP locales] --> Jar[JAR Java 17 - puerto 8000/api]
    Jar --> H2[H2 en memoria para smoke test]
    Maven[Maven Wrapper 3.8.7] --> Pruebas[6 pruebas originales]
    Pruebas --> Jar
```

Persistencia compartida **ejecutada con procesos nativos y detenida al finalizar**:

```mermaid
flowchart LR
    A[JVM A - puerto 8001] --> PG[PostgreSQL 15.19 - puerto 55432]
    B[JVM B - puerto 8002] --> PG
    V1[Flyway - migracion V1] --> PG
```

Contenedores **ejecutados y retirados tras la prueba aislada**:

```mermaid
flowchart LR
    Cliente[Windows - loopback 8003] --> API[Contenedor Java - puerto 8080]
    API --> PG[Contenedor PostgreSQL - puerto 5432]
    PG --> Volumen[Volumen de prueba postgres-data]
    Salud[Healthcheck readiness] --> API
```

Arquitectura Kubernetes **implementada y verificada localmente**; el workflow valida el mismo procedimiento en su clúster efímero:

```mermaid
flowchart LR
    GitHub[GitHub Actions] --> Calidad[Compilar, probar, analizar y medir cobertura]
    Calidad --> Imagen[Construir imagen y escanear todas las severidades]
    Imagen --> SBOM[Verificar hashes del SBOM y escanear dependencias Maven]
    SBOM --> Gate{Cero CRITICAL y HIGH en ambos escaneos}
    Gate -->|No| Bloqueo[Bloquear publicacion y despliegue; conservar reporte]
    Gate -->|Si| GHCR[GHCR - publicacion y digest registrado]
    Gate -->|Si| Archivo[Archivo de la imagen con checksum]
    Archivo --> Kind[kind en CI - misma imagen construida]
    Kind --> Deployment[Deployment Java - 2 a 4 replicas]
    Cliente[Cliente local] --> Ingress[Port-forward e Ingress Traefik]
    Ingress --> Servicio[Service Java]
    Servicio --> Pod1[Replica Java 1]
    Servicio --> Pod2[Replica Java 2]
    Deployment --> Pod1
    Deployment --> Pod2
    Pod1 --> DB[PostgreSQL con PVC]
    Pod2 --> DB
    Config[ConfigMap y Secret] --> Pod1
    Config --> Pod2
    Metrics[metrics-server] --> HPA[HPA]
    HPA --> Deployment
```

### Entregables y siguiente etapa

| Entregable | Estado |
| --- | --- |
| Diagnóstico, logs locales, guía y plan | Disponibles en este proyecto |
| PostgreSQL compartido y Flyway | Verificados con JVM, Docker y Kubernetes; datos conservados al reemplazar pods |
| Docker y Actuator | Implementados y verificados localmente con PostgreSQL |
| Análisis estático y cobertura | Implementados y verificados; 22 pruebas, PMD y gates JaCoCo aprobados |
| Kubernetes | 30 comprobaciones locales aprobadas; Ingress, dos réplicas mínimas y escalamiento observado |
| Repositorio público GitHub y publicación GHCR | Publicados; URL del repositorio al inicio y metadatos en las evidencias |
| URL y artefactos de un pipeline real | Run 40044688944 aprobado; reportes y logs copiados al repositorio, junto al primer intento fallido |
| ZIP del proyecto versionado | Generación y verificación mediante `scripts/New-Delivery.ps1`; instrucciones a continuación |
| Endpoint público | No existe; es opcional en el ejercicio |

Para producir el archivo desde un commit real y un árbol Git limpio:

```powershell
.\scripts\New-Delivery.ps1
```

El script genera `devsu-demo-devops-java-entrega.zip` en el directorio padre y un manifiesto con commit, SHA-256 del ZIP y hashes de cada archivo. Utiliza `git archive HEAD`, comprueba archivos necesarios y rechaza datos de BD, configuraciones locales, credenciales y cachés. El ZIP contiene las fuentes, infraestructura, pipeline, documentación y evidencias versionadas. También puede descargarse el [ZIP del repositorio público](https://github.com/mpguevara/devsu-demo-devops-java/archive/refs/heads/main.zip).

Las preguntas de defensa se incluyen en las guías de [Docker](docs/DOCKER-Y-SALUD.md#preguntas-de-defensa), [calidad](docs/CALIDAD.md), [Kubernetes](docs/KUBERNETES.md) y [pipeline](docs/PIPELINE.md), además del [plan guiado](docs/PLAN-DE-TRABAJO.md#preguntas-de-defensa-por-etapa).

## Referencia de la API

Se conserva el contrato de la aplicación entregada: listar, consultar y crear usuarios. El POST devuelve **201** y los ejemplos cumplen las validaciones. Los IDs son ilustrativos y los asigna la base de datos. Las instrucciones actuales de ejecución y perfiles están arriba; el README inicial completo está archivado en la evidencia de línea base.

#### Create User

To create a user, the endpoint **/api/users** must be consumed with the following parameters:

```bash
  Method: POST
```

```json
{
    "dni": "9999999901",
    "name": "Prueba DevOps"
}
```

If the response is successful, the service will return an HTTP Status 201 and a message with the following structure:

```json
{
    "id": 1,
    "dni": "9999999901",
    "name": "Prueba DevOps"
}
```

If the response is unsuccessful, we will receive status 400 and the following message:

```json
{
    "errors": [
        "error"
    ]
}
```

#### Get Users

To get all users, the endpoint **/api/users** must be consumed with the following parameters:

```bash
  Method: GET
```

If the response is successful, the service will return an HTTP Status 200 and a message with the following structure:

```json
[
    {
        "id": 1,
        "dni": "0123456789",
        "name": "devsuvian 1"
    }
]
```

#### Get User

To get an user, the endpoint **/api/users/<id>** must be consumed with the following parameters:

```bash
  Method: GET
```

If the response is successful, the service will return an HTTP Status 200 and a message with the following structure:

```json
{
    "id": 1,
    "dni": "0123456789",
    "name": "devsuvian 1"
}
```

If the user id does not exist, we will receive status 404 and the following message:

```json
{
    "errors": [
        "User not found: <id>"
    ]
}
```

If the response is unsuccessful, we will receive status 400 and the following message:

```json
{
    "errors": [
        "error"
    ]
}
```

## License

Copyright © 2023 Devsu. All rights reserved.
