# Diagnóstico y cierre de la etapa 1

Fecha de ejecución: **20 de octubre de 2026**, zona `America/El_Salvador` (UTC-06:00). Alcance: únicamente el proyecto Java de esta carpeta. No se ha construido infraestructura ni se han publicado archivos en GitHub durante esta etapa.

Este documento conserva el diagnóstico de la entrega inicial. Después se implementaron perfiles PostgreSQL/H2 y Flyway; ese avance modifica POM, configuración, entidad y aislamiento de pruebas, y está documentado en [POSTGRESQL.md](POSTGRESQL.md). Las afirmaciones de fuentes intactas y configuración original siguientes corresponden al cierre de la etapa 1, no al estado posterior.

## Resultado

- Compilación, pruebas y empaquetado originales: **BUILD SUCCESS**, código de salida 0.
- Surefire: **6 pruebas, 0 fallos, 0 errores, 0 omitidas**.
- Artefacto: `target/demo-0.0.1.jar`, 55.096.121 bytes. Hash SHA-256 en [test-summary.json](evidence/baseline/test-summary.json).
- JAR ejecutado con Java 17: **9 comprobaciones HTTP satisfactorias**, más comprobación de los datos del usuario creado al volver a consultarlo.
- Swagger/OpenAPI accesibles durante la prueba. La aplicación se detuvo al finalizar; no queda un servicio publicado.
- POM, wrapper y archivos Java/resources/pruebas originales: sin cambios, comprobados contra [25 hashes de la entrega inicial](evidence/baseline/source-original.sha256.json). README y `.gitignore` sí se actualizaron para documentar y excluir archivos locales.

## Entorno observado

| Área | Resultado | Consecuencia |
| --- | --- | --- |
| Sistema | Windows 11 Home Single Language x64, 10.0.26200; PowerShell 7.6.5 | Usar scripts y sintaxis PowerShell 7 para la guía local |
| CPU | Core i7-13620H, 16 procesadores lógicos | Capacidad de CPU disponible para un ejercicio pequeño; sin prueba de carga todavía |
| Memoria | 15,63 GiB total; aproximadamente 1,2–1,3 GiB libres al diagnosticar | Ejecutar validaciones por separado; liberar memoria antes del clúster local |
| Disco | Aproximadamente 693 GiB libres en C: | Espacio suficiente para las descargas observadas; no es un benchmark de almacenamiento |
| Java | Inicialmente Oracle 26, sin `JAVA_HOME` | Seleccionar un JDK 17 en la terminal |
| Maven | Global 3.9.15; wrapper del proyecto 3.8.7 | Utilizar el wrapper para mantener la versión del proyecto |
| Docker | Cliente 29.6.1; falla la conexión al pipe dockerDesktopLinuxEngine | Construir/ejecutar imágenes está bloqueado localmente hasta arrancar el motor |
| Kubernetes | kubectl 1.36.1; lista de contextos vacía | No hay un clúster accesible mediante esa configuración |
| WSL | WSL2, distribución predeterminada docker-desktop | No acredita que el backend Docker esté corriendo |
| Git | 2.54.0; sin `.git` en esta copia | Crear el repositorio y su historia real en la etapa de publicación |
| GitHub | Conector autenticado como `mpguevara` | Identidad verificada; permisos de creación, push, paquetes y Actions pendientes |
| Herramientas ausentes de PATH | kind, minikube, Helm, gh, Trivy | kind y escáner pueden ejecutarse en CI; Helm no es necesario para este alcance |

Las métricas de memoria/disco son una instantánea, no recursos reservados. Datos estructurados: [environment.json](evidence/baseline/environment.json).

## Aplicación y configuración

Se revisaron README, POM, Maven Wrapper, configuración, SQL, controladores, servicios, entidad, DTO, mapper, repositorio y pruebas. Las versiones efectivas están en [dependency-tree.txt](evidence/baseline/dependency-tree.txt).

La API tiene `GET /api/users`, `GET /api/users/{id}` y `POST /api/users`, puerto predeterminado 8000. La creación devuelve **201**, verificado en código y por HTTP. Las validaciones exigen DNI de 10 a 13 caracteres y nombre de 5 a 30; no permiten valores vacíos.

`NAME_DB`, `USERNAME_DB`, `PASSWORD_DB` y `PORT` ya existen en la configuración. El nombre `NAME_DB` corresponde a una URL JDBC. El driver y el dialecto siguen fijados a H2. No existe Actuator ni un endpoint de salud específico.

### Persistencia y réplicas

El modo original usa `jdbc:h2:file:./test`, `ddl-auto=create` y `spring.sql.init.mode=always`. Por lo tanto, el archivo no garantiza conservar los usuarios entre arranques: Hibernate recrea el esquema y SQL inserta los tres usuarios de demostración.

Dos pods con ese modo almacenarían datos separados. H2 embebido abre la base dentro de una JVM; no se solucionará montando el mismo archivo en varios pods. La [documentación oficial de H2](https://h2database.com/html/features.html#connection_modes) explica sus modos de conexión. La propuesta es PostgreSQL compartido y una migración versionada para Kubernetes, manteniendo H2 para pruebas locales. El cambio de motor necesitará pruebas reales de SQL, concurrencia y conservación de datos.

### Pruebas originales

| Clase | Métodos | Alcance y límite |
| --- | --- | --- |
| UserServiceTest | 3 | Usa mocks pero carga Spring completo; prueba lista vacía, usuario encontrado y excepción lanzada por el repositorio mock |
| UserRepositoryTest | 1 | Prueba JPA en memoria; presupone el ID 4 tras la siembra |
| UserControllerTest | 1 | MockMvc con Spring; solo estado 200 del listado |
| DemoJavaApplicationTests | 1 | Carga del contexto |

No se atribuye cobertura a estas pruebas porque no se ha ejecutado JaCoCo. El caso de usuario inexistente del servicio no comprueba todavía `Optional.empty()`; el mock lanza la excepción directamente. Conviene aislar las pruebas del servicio, eliminar el ID fijo y añadir casos relevantes de comportamiento al preparar calidad.

## Ejecuciones y problemas reales

| Paso | Observación | Resolución o estado |
| --- | --- | --- |
| `java -version`, `mvn -v` | Java 26 y Maven global 3.9.15 | Se mantuvieron como instalaciones globales; no se usaron para validar la aplicación |
| `mvnw.cmd -v` inicial | `JAVA_HOME not found in your environment` | Se descargó Temurin 17.0.20.1+1 portable, verificó su SHA-256 y configuró `JAVA_HOME` solo en los procesos de trabajo |
| Consulta de checksum del wrapper | Maven Central devolvió 404 para el archivo `.jar.sha256` de wrapper 3.1.1 | Se descargó el JAR oficial por HTTPS y se comparó su SHA-256 con el JAR entregado: coinciden. No se omitió la comprobación |
| `clean verify` con Java 17 | BUILD SUCCESS; seis pruebas satisfactorias | Se conservaron logs, resumen Surefire y hash del JAR |
| `dependency:tree` | BUILD SUCCESS | Se guardó el árbol resuelto; no modifica las dependencias del POM |
| JAR y smoke HTTP | Nueve respuestas con estados esperados; consulta devuelve el usuario creado | Se usó H2 en memoria para aislar la prueba y se detuvo el proceso iniciado |
| README del POST | Documentaba 200, código y respuesta real devuelven 201 | Se corrigió el README; el original está conservado en evidencia |
| `docker version` | No se pudo conectar al motor Linux de Docker Desktop | Pendiente arrancar/verificar Docker, atendiendo a la memoria disponible |
| `kubectl config get-contexts` | No hay contextos | Pendiente crear un clúster local o usar kind en el runner |
| `git status`, `git remote -v` | La carpeta no es un repositorio Git | Pendiente inicializar/publicar en una etapa posterior; no se generaron commits |

Los mensajes `User already exists` y `User not found: 999999` en el log HTTP corresponden a comprobaciones de error esperadas. No son incidentes de despliegue ni errores introducidos en la aplicación. Se observó además la advertencia original de `spring.jpa.open-in-view` habilitado; se evaluará su configuración al preparar el perfil de despliegue.

El comando de construcción real fue:

```powershell
$env:MAVEN_OPTS = '-Xmx384m -Dfile.encoding=UTF-8'
.\mvnw.cmd -B -ntp clean verify '-DargLine=-Xmx384m'
```

Se ejecutó después de seleccionar el JDK portable mediante `JAVA_HOME` y `PATH`. El límite de heap no mide memoria total ni sustituye a los recursos de Kubernetes. Este `argLine` pertenece a la línea base; al introducir JaCoCo habrá que preservar sus argumentos de instrumentación.

## Siguiente etapa y criterios pendientes

Preparar Actuator y Docker multietapa, con ejecución sin privilegios, variables de entorno y rutas de salud verificadas. El diseño inicial propone liveness sin dependencia de BD y readiness que incluya BD. Hasta ejecutarlos no se darán por validados el contenedor ni sus probes.

Después: perfil PostgreSQL/migración, pruebas aisladas, JaCoCo, analizador, manifiestos Kubernetes y pipeline. Se usará una sola herramienta de análisis estático; no se requiere SonarQube, Terraform, Argo CD ni una plataforma completa de monitorización para justificar esta prueba.

No están disponibles todavía el repositorio público, una imagen publicada, una URL de pipeline, un despliegue Kubernetes ni el ZIP final. Las URLs y capturas se incorporarán únicamente cuando existan resultados reales.

## Preguntas para cerrar la etapa

1. ¿Qué diferencia hay entre el Java instalado en tu máquina, `JAVA_HOME` y el Java declarado en el POM? ¿Qué fija el Maven Wrapper y qué no fija?
2. ¿Qué demuestra `clean verify` en este proyecto y qué controles aún no ejecuta?
3. ¿Por qué dos réplicas con H2 de archivo no comparten sus datos y por qué `ddl-auto=create` afecta los reinicios?
4. ¿En qué se diferencian las seis pruebas originales y las nueve comprobaciones HTTP que acabamos de ejecutar?
