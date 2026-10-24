# PostgreSQL compartido y migraciones

## Resultado comprobado

La aplicación conserva Java 17, Spring Boot 3.0.5 y sus contratos HTTP. Se añadieron PostgreSQL JDBC **42.7.14**, Flyway **9.5.1**, perfiles separados y la migración `V1__create_users.sql`.

En la etapa de persistencia, la construcción pasó las **6 pruebas Maven**, y el JAR pasó **9 comprobaciones HTTP con H2 local** y **36 comprobaciones de integración con PostgreSQL 15.19 real**. Estas últimas combinan HTTP, SQL, disponibilidad y comprobación de resultados. No son 36 pruebas unitarias. La [evidencia](evidence/postgres/README.md) incluye logs y resultados verificables.

Se iniciaron dos JVM simultáneamente en `127.0.0.1:8001` y `:8002`, conectadas a la misma base PostgreSQL. Se creó un usuario en A y se leyó en B. Dos peticiones concurrentes con otro DNI produjeron 201 y 400, con un solo registro para ese DNI. Se detuvo A, B siguió respondiendo y A recuperó el usuario al reiniciarse. El historial mantuvo **una sola aplicación de V1** y los dos usuarios creados se conservaron.

PostgreSQL y las JVM de esa verificación quedaron detenidos. La prueba usó binarios portables de PostgreSQL en Windows porque el motor Docker no estaba disponible entonces.

**Avance posterior, 21 de octubre de 2026:** se recuperó Docker y se ejecutaron API y PostgreSQL en contenedores. La nueva etapa pasó 11 pruebas Maven y 39 comprobaciones Docker, incluida conservación del usuario tras reiniciar PostgreSQL y recuperación de readiness sin reiniciar Java. Véanse [Docker y salud](DOCKER-Y-SALUD.md) y [su evidencia](evidence/docker-health/README.md). Los resultados históricos de dos JVM se conservan con su alcance original; Kubernetes sigue pendiente.

## Qué cambió y por qué

| Perfil | Uso | Base de datos | Responsable del esquema |
| --- | --- | --- | --- |
| `postgres` (predeterminado) | Aplicación compartida y futuro Kubernetes | PostgreSQL externo; credenciales obligatorias | Flyway migra; Hibernate valida |
| `local` (explícito) | Demostración local heredada | H2 de archivo o URL H2 indicada | Hibernate recrea y `data.sql` carga los tres ejemplos |
| `test` | Pruebas Maven | H2 en memoria, sin usuarios sembrados | Hibernate crea/descarta; Flyway desactivado |

El perfil predeterminado evita utilizar H2 silenciosamente en un despliegue. `NAME_DB`, `USERNAME_DB` y `PASSWORD_DB` son obligatorias en `postgres`; no hay una contraseña PostgreSQL incorporada al proyecto. H2 permanece como dependencia runtime para que el JAR pueda ejecutar el modo `local` y su smoke test. No se usa en el perfil PostgreSQL.

Flyway lee `db/migration/postgresql/V1__create_users.sql` y registra su ejecución y checksum en `flyway_schema_history`. Hibernate usa `ddl-auto=validate`: comprueba el esquema y falla si no corresponde a la entidad, sin recrearlo. La inicialización SQL de Spring está desactivada en PostgreSQL, por lo que `data.sql` no vuelve a insertar fixtures en cada réplica.

La migración crea `users` con ID `BIGINT` identity, DNI de hasta 13 caracteres, nombre de hasta 30, campos obligatorios y DNI único. Las anotaciones `@Column` explicitan esas restricciones en la entidad. No se modificaron controladores ni servicios. Se desactivó `open-in-view` y se fijó el pool en un máximo de cinco conexiones por instancia como configuración inicial para este ejercicio, sin afirmar que esté dimensionado para producción.

Esta etapa prepara **el esquema de una base PostgreSQL nueva**. No importa automáticamente datos del archivo H2 existente ni elimina ese archivo. Si aparecieran datos reales que conservar, su exportación, transformación e importación requerirían una tarea explícita y verificaciones adicionales.

Una migración aplicada debe permanecer sin cambios: el siguiente cambio de esquema será otro archivo versionado, por ejemplo `V2__...sql`. No se habilitó `baseline-on-migrate`; una base preexistente desconocida debe revisarse antes de adoptarla. `clean` está deshabilitado.

## Ejecutar con PostgreSQL en Docker

El archivo Compose base inicia solo PostgreSQL. Se validó su ejecución junto a la API en contenedor durante la etapa Docker. El siguiente camino permite ejecutar la API como JAR en Windows; para ejecutar ambos en contenedores, utiliza la [guía de Docker](DOCKER-Y-SALUD.md#ejecutar-api-y-postgresql-con-compose).

En PowerShell 7, desde la raíz del proyecto:

```powershell
. .\scripts\Use-Java17.ps1
$env:USERNAME_DB = 'devsu'
$env:NAME_DB = 'jdbc:postgresql://127.0.0.1:5432/devsu'
$env:PASSWORD_DB = Read-Host -MaskInput 'Contraseña de PostgreSQL local'

docker compose config --quiet
docker compose up -d --wait

java -Xms64m -Xmx256m -jar .\target\demo-0.0.1.jar --server.address=127.0.0.1
```

La API usa `http://127.0.0.1:8000/api/users`. PostgreSQL empieza sin usuarios de demostración; Flyway crea el esquema al iniciar la aplicación. Para elegir otro puerto PostgreSQL, define `POSTGRES_PORT` antes de arrancar Compose y usa ese mismo puerto en `NAME_DB`.

`compose.yaml` fija PostgreSQL **15.19-bookworm por digest**, publica el puerto únicamente en loopback y monta un volumen nombrado. `docker compose stop` detiene la base y conserva su volumen. No uses opciones que eliminen volúmenes si necesitas conservar datos.

Conserva la contraseña del volumen si vas a reutilizarlo. `POSTGRES_PASSWORD` inicializa una base vacía; cambiar la variable posteriormente no cambia la contraseña de una base ya creada. El usuario `devsu` es el administrador inicial de esta instancia local y también ejecuta migraciones y consultas. Separar un rol de migración y otro de aplicación queda pendiente para un endurecimiento posterior. Una única instancia PostgreSQL no tiene alta disponibilidad.

## Repetir la verificación entre dos instancias

Se necesita una base de prueba **nueva y vacía**. No ejecutes el script contra una base de negocio: crea dos usuarios de prueba y los conserva. Comprueba la ausencia de tablas antes de iniciar aplicaciones y no borra ni reinicia datos.

Esta es una ruta alternativa al arranque manual anterior. Con Compose recién inicializado y las variables de conexión definidas, ejecuta la verificación **antes del primer arranque de cualquier aplicación sobre esa base**. Iniciar el JAR ya crea las tablas con Flyway, incluso sin usuarios, y hace que deje de cumplir la precondición de esta prueba:

```powershell
.\scripts\Test-PostgresApi.ps1
# Resultado por defecto: target/postgres-api-evidence/http-results.json
```

El script requiere puertos 8001 y 8002 libres. Consulta SQL mediante `docker compose exec postgres psql`, arranca ambas JVM con perfil `postgres`, usa un heap máximo de 256 MiB por JVM y las detiene al finalizar. Los argumentos `-PortA`, `-PortB`, `-JarPath` y `-EvidenceDirectory` permiten ajustar la ejecución. No registra contraseñas.

También puede verificar un PostgreSQL nativo ya iniciado usando `-PsqlPath 'C:\ruta\postgresql\bin\psql.exe'` y las tres variables de conexión. Ese fue el modo utilizado en esta máquina, con PostgreSQL portable 15.19, puerto 55432 y una base aislada fuera del repositorio. La descarga procede de [EDB](https://www.enterprisedb.com/download-postgresql-binaries); el hash del ZIP está registrado como identificación local, sin afirmar que se contrastó con un checksum independiente del editor.

Si ya ejecutaste el JAR o esta verificación, utiliza otra base de prueba vacía; no borres una base existente para satisfacer la precondición. El modo con `-PsqlPath` permite indicar otra base en `NAME_DB`. El camino Compose del script está limitado a la base `devsu` del servicio local y aún no se ha ejecutado aquí. La verificación SQL nativa y las JVM sí se ejecutaron. Un resultado satisfactorio deja dos usuarios y el historial V1; repetir sobre esa misma base falla de forma explícita.

## Pruebas locales y H2

Las pruebas Maven activan `test` mediante `@ActiveProfiles`, usan memoria y no necesitan PostgreSQL. El repositorio busca el ID generado por la entidad, evitando depender del ID 4 de la siembra original.

```powershell
$env:MAVEN_OPTS = '-Xmx384m -Dfile.encoding=UTF-8'
.\mvnw.cmd -B -ntp clean verify '-DargLine=-Xmx384m'
.\scripts\Test-LocalApi.ps1
```

Para ejecutar manualmente el modo heredado H2, usa una terminal sin variables de conexión PostgreSQL, selecciona Java 17 y activa `local` explícitamente:

```powershell
Remove-Item Env:NAME_DB, Env:USERNAME_DB, Env:PASSWORD_DB -ErrorAction SilentlyContinue
java -Xms64m -Xmx256m -jar .\target\demo-0.0.1.jar --spring.profiles.active=local --server.address=127.0.0.1
```

Ese modo sigue recreando tablas y sembrando datos al iniciar. Las pruebas H2 comprueban un camino rápido; la verificación real PostgreSQL comprueba la migración y el acceso compartido. Una no sustituye a la otra.

## Problemas reales y límites

| Observación | Resolución o estado |
| --- | --- |
| En la etapa de persistencia, Docker Desktop cerraba su backend y el pipe Linux seguía inaccesible | Se verificó con PostgreSQL nativo. Posteriormente se recuperó Docker aislando directorios con sockets obsoletos; véanse la guía y evidencias de la etapa Docker. No hubo reinicio de fábrica ni eliminación de datos |
| Primer intento nativo: PostgreSQL arrancó, pero la invocación directa de `pg_ctl` desde PowerShell se quedó esperando | Se detuvo esa instancia desde otro proceso; `createdb` falló después por conexión rechazada. Se conservaron los logs en `attempt-1`. El intento posterior lanzó `pg_ctl` con `Start-Process -WindowStyle Hidden` y esperó solo al proceso de control; finalizó correctamente |
| Memoria libre reducida; las JVM iniciales tardaron aproximadamente 49 y 52 segundos en arrancar | Se ejecutaron validaciones por separado y se usaron límites de heap. Son tiempos observados de esa máquina, no un benchmark ni un dimensionamiento Kubernetes |

La prueba concurrente demuestra dos respuestas 201/400 y un solo registro con ese DNI; no fuerza un intercalado particular dentro de `existsByDni` y `save`. En esa etapa se reinició A, manteniendo PostgreSQL y B activos. La etapa Docker posterior sí comprobó el reinicio de PostgreSQL y persistencia sobre su volumen. Siguen sin verificar backup/restauración, balanceador, HPA y alta disponibilidad.

## Compatibilidad y referencias

- Se mantuvo Flyway **9.5.1**, gestionado por el BOM de Spring Boot 3.0.5. Su [implementación PostgreSQL](https://github.com/flyway/flyway/blob/flyway-9.5.1/flyway-core/src/main/java/org/flywaydb/core/internal/database/postgresql/PostgreSQLDatabase.java) contempla PostgreSQL 15; por eso se eligió ese major sin actualizar el framework.
- Se fijó el nuevo JDBC en **42.7.14**, frente a 42.5.4 del BOM original, tras consultar la [distribución oficial de pgJDBC](https://jdbc.postgresql.org/download/) y comprobarlo en la ejecución real. El escaneo de vulnerabilidades completo sigue pendiente.
- Spring Boot documenta el uso de [Flyway para inicialización](https://docs.spring.io/spring-boot/docs/3.0.5/reference/html/howto.html#howto.data-initialization.migration-tool.flyway). La [imagen oficial PostgreSQL](https://hub.docker.com/_/postgres) documenta las variables y el comportamiento del directorio persistente.

## Preguntas de defensa

1. ¿Qué hace Flyway que no hace `ddl-auto=validate` y dónde registra qué migraciones ya ejecutó?
2. ¿Por qué ambas instancias Java ven el mismo usuario aunque tengan procesos y puertos distintos?
3. ¿Por qué la restricción única sigue siendo necesaria si el servicio ya ejecuta `existsByDni`?
4. ¿Qué demuestra reiniciar A y qué falta demostrar antes de afirmar persistencia o recuperación en Kubernetes?
