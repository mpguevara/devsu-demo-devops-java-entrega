# Hoja de ruta guiada de la prueba DevOps

## Objetivo y estado

Preparar únicamente la aplicación Java entregada para construirla, probarla, empaquetarla y desplegarla automáticamente en Kubernetes, con evidencias que permitan explicar cada decisión. El plazo orientativo es de siete días; las etapas se cierran por sus criterios de aceptación, no por el cambio de fecha.

**Estado al 23 de octubre:** implementación y validaciones completas, con repositorio público y [pipeline aprobado](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40044688944). La etapa 1 conserva su [diagnóstico](DIAGNOSTICO.md) y [evidencia original](evidence/baseline/README.md); las etapas siguientes conservan sus resultados por separado. La suite actual pasó 22 pruebas, PMD y gates JaCoCo; véase [calidad](CALIDAD.md). Kubernetes aprobó 30 comprobaciones tanto en Windows local como en el runner privado de CI, con persistencia, Ingress y HPA observado. El ZIP se genera desde Git HEAD mediante el script de entrega. Las vulnerabilidades encontradas y las mejoras de producción siguen explícitamente documentadas.

**Avance de persistencia:** se adelantó la parte de datos de la etapa 3. PostgreSQL, Flyway, perfiles y aislamiento de pruebas están implementados. En esa etapa pasaron seis pruebas Maven, nueve comprobaciones H2 y 36 comprobaciones con PostgreSQL real y dos JVM. Ver [guía y decisiones](POSTGRESQL.md) y [evidencia](evidence/postgres/README.md). La etapa 2 comprobó además persistencia al reiniciar la BD en Docker. El orden diario se adapta a lo que podemos verificar; el repositorio remoto se creó antes de ejecutar Actions, reservando el cierre para evidencias, documentación y paquete final.

La aplicación y su autoría original pertenecen a Devsu, conforme al aviso del README entregado. Se conservarán las atribuciones y los avisos originales. Los archivos de infraestructura y documentación explicarán los cambios realizados sobre esa base.

## Punto de partida confirmado por lectura

- `pom.xml`: Java 17, Spring Boot 3.0.5, Spring Web, JPA, Validation, H2, Lombok, ModelMapper 2.4.5 y springdoc 2.1.0. Las versiones transitivas requieren consultar las dependencias efectivas.
- `.mvn/wrapper/maven-wrapper.properties`: Maven 3.8.7 y Maven Wrapper 3.1.1. El proyecto incluye los scripts y el JAR del wrapper.
- El README original indica `mvn clean test` y `mvn spring-boot:run`. El wrapper permite invocar los mismos objetivos sin depender de una instalación global de Maven.
- `application.properties`: puerto 8000, contexto `/api`, H2 de archivo, `ddl-auto=create` y carga de `data.sql` en cada arranque. Las variables originales son `NAME_DB`, `USERNAME_DB`, `PASSWORD_DB` y `PORT`.
- La API permite listar, consultar y crear usuarios. El controlador devuelve HTTP 201 al crear; el README original mencionaba 200 y se corrigió tras comprobarlo por HTTP.
- Hay seis métodos de prueba distribuidos entre contexto Spring, servicio con mocks, repositorio JPA y controlador MockMvc. Su presencia no demuestra que pasen.
- No se encontró configuración inicial de Actuator, cobertura ni análisis estático en el POM.

**Implicación importante:** dos réplicas con H2 de archivo tendrían datos separados. Además, `ddl-auto=create` recrea el esquema al arrancar. El diseño propuesto para Kubernetes necesita una base de datos compartida y una inicialización controlada.

## Etapas y días orientativos

| Etapa | Día | Trabajo propuesto | Criterio de aceptación | Evidencia y estado |
| --- | --- | --- | --- | --- |
| 1. Diagnóstico y línea base | 1 | Verificar Windows, CPU, RAM, disco, WSL, Java, Maven Wrapper, Git, Docker, kubectl e identidad GitHub; leer README y código; ejecutar la línea base disponible. | Versiones y recursos registrados; herramientas presentes, ausentes y bloqueadas distinguidas; resultado original de compilación y pruebas documentado. | Completada: diagnóstico, seis pruebas aprobadas, JAR y nueve comprobaciones HTTP; logs y JSON enlazados al inicio. Docker se recuperó y la publicación se verificó posteriormente. |
| 2. Empaquetado y salud | 2 | Añadir Actuator y configuración de salud; preparar Docker multietapa, usuario sin privilegios, `.dockerignore` y variables de entorno. | Construir la imagen; iniciar el contenedor; comprobar API, puerto, identidad del usuario y endpoints de salud. | Completada: imagen local, 11 pruebas Maven, dos JAR Linux idénticos y 39 comprobaciones Docker; caída/recuperación de BD, persistencia y apagado ordenado verificados. |
| 3. Datos y controles de calidad | 3 | Aislar pruebas, preparar PostgreSQL/Flyway, medir JaCoCo y ejecutar PMD. | Pasar pruebas, reportes y gates; migrar sin recrear datos. | Completada: 22 pruebas, 90,28 % de líneas globales, 100 % de líneas/ramas del servicio y cero infracciones en las nueve reglas PMD. |
| 4. Kubernetes mínimo | 4 | PostgreSQL persistente, Deployment Java, Service, ConfigMap, Secret, recursos, probes, Ingress y HPA. | Dos pods Ready; servicio e Ingress; datos compartidos y persistencia. | Completada: 30 comprobaciones locales; HPA de dos a cuatro y retorno automático a dos. |
| 5. Automatización y registro | 5 | GitHub Actions para calidad, imagen, Trivy, GHCR y kind privado. | Run real con los cuatro jobs aprobados y la misma imagen construida/desplegada. | Completada: run 40044688944 aprobado, digest y artefactos conservados. Primer run fallido preservado con su resolución. |
| 6. Validación y resolución de problemas | 6 | Comprobar reinicios, datos, salud, Ingress y HPA con carga real. | Resultados observados y fallos explicados. | Completada: 7.382 GET locales y 18.770 en CI sin errores en esos ensayos; lectura compartida, reemplazo de pods y PVC comprobados. No constituyen SLA. |
| 7. Entrega y defensa | 7 | README, diagramas, revisión de archivos, repositorio y paquete; preguntas técnicas. | Fuentes reproducibles y evidencia accesible; ZIP de Git HEAD verificado. | Repositorio público, guías y evidencias disponibles; script New-Delivery.ps1 produce ZIP y manifiesto SHA-256. La API permanece privada. |

Si el diagnóstico local impide una etapa, se continuará con preparación de archivos y validación disponible, manteniendo visible el bloqueo. No se declarará una etapa ejecutada por haber escrito sus archivos.

## Decisiones y justificación

### Java y construcción

Mantener inicialmente Java 17 y Spring Boot 3.0.5 porque son las versiones declaradas por la aplicación. No incorporar una migración de framework sin una necesidad comprobada. Las vulnerabilidades encontradas podrían justificar actualizaciones acotadas, verificadas con pruebas y documentadas.

Usar Maven Wrapper para fijar Maven. Se actualizó el wrapper de 3.1.1 a 3.3.4 para verificar descargas por checksum, manteniendo Maven 3.8.7. Las bases Docker están fijadas por digest. Dos construcciones limpias Linux generaron el mismo JAR; el alcance y la diferencia de metadatos Windows/Linux están en la guía de Docker. No se afirma identidad de la imagen OCI completa.

### Contenedor y salud

El Dockerfile construye con JDK y ejecuta con JRE 17 y usuario 10001. Compose aplica raíz de solo lectura y `/tmp` en tmpfs; ambas condiciones y la escritura en `/tmp` se verificaron en ejecución. Los límites iniciales son 512 MiB y una CPU para Java; requieren medición con carga antes de considerarse dimensionamiento.

Actuator expone los grupos liveness y readiness bajo `/api/actuator/health`. Liveness comprueba el estado del proceso; readiness incluye PostgreSQL. Al detener la BD se observaron liveness 200/UP y readiness 503/DOWN; al recuperarla, readiness volvió a 200/UP sin reiniciar Java. Una futura startupProbe Kubernetes podrá consultar liveness durante el arranque; no se añadió un endpoint HTTP llamado startup.

### Datos compartidos entre réplicas

Se mantiene H2 para ejecución sencilla y pruebas aisladas. PostgreSQL es el perfil predeterminado; se añadió Flyway 9.5.1, una migración V1 y validación de esquema al iniciar. Dos JVM sobre PostgreSQL real comprobaron lectura compartida e historial con una única migración. Su despliegue y persistencia en Kubernetes se verificaron posteriormente en local y CI.

Una instancia PostgreSQL con volumen persistente es suficiente para esta prueba. Su disponibilidad sería una limitación explícita: tener dos réplicas Java no convierte la base de datos en altamente disponible. La propuesta conserva los contratos de la API y evita modificar funcionalidades ajenas al ejercicio.

### Cobertura y análisis estático

JaCoCo 0.8.15 midió primero 41,89 % de líneas globales y 0 % de ramas. Las pruebas ampliadas obtuvieron 90,28 % y 12,90 %, respectivamente; el servicio alcanzó 100 % de líneas y ramas. Se fijaron gates de 85 % de líneas globales y 100 % del servicio después de medir, sin excluir clases ni ocultar métodos generados por Lombok. Los resultados están en la guía de calidad.

Se eligió **PMD**, con nueve reglas de fuente explícitas, para mantener un control pequeño y explicable. Se corrigieron dos variables innecesarias del mapper; el resultado final fue cero infracciones. No se añadieron exclusiones ni un servidor SonarQube.

### Pipeline y publicación

GitHub Actions y GHCR reducen la cantidad de servicios externos y permiten enlazar la ejecución con el repositorio entregable. Las credenciales de publicación deben proceder del contexto autorizado de GitHub, con permisos mínimos; no deben quedar en archivos. Se fijarán versiones o commits de las acciones utilizadas.

El pipeline ejecuta compilación, pruebas, análisis estático y cobertura antes de construir, escanear y publicar la imagen. La etiqueta incluye el commit y la publicación registra su digest. Los jobs siguientes comprueban el SHA-256 del archivo de imagen para desplegar los mismos bytes, sin recompilar otra imagen.

Trivy 0.76.1 encontró 121 hallazgos en la imagen, incluidos nueve críticos y cuarenta altos. No se omiten severidades ni vulnerabilidades sin corrección. La política es informativa frente a hallazgos y bloqueante ante errores operativos; el reporte y las prioridades se conservan en la evidencia. La actualización compatible del stack heredado y una política de bloqueo para producción quedan pendientes.

### Kubernetes y acceso

Un clúster kind temporal en el runner permitirá validar un despliegue real incluso si la máquina local no dispone de Docker operativo o acceso a un clúster. Ese clúster desaparecerá al finalizar el job: prueba el procedimiento de despliegue, pero no constituye un servicio permanente ni proporciona un endpoint público para la entrega.

La aplicación tendrá al menos dos réplicas, requests y limits, probes y HPA. Para demostrar escalamiento por CPU se necesita un proveedor de métricas operativo, normalmente metrics-server, y carga suficiente. Un manifiesto de HPA aceptado no prueba que haya escalado.

Los manifiestos incluyen ConfigMap no sensible y referencias a Secret generado en memoria fuera del repositorio. Base64 no cifra un Secret. Se incorporó y verificó Traefik e Ingress para `devsu.local`, accesible por port-forward limitado a loopback. No se requiere DNS ni una URL pública.

## Restricciones y problemas observados

El diagnóstico inicial registró Windows 11 x64, PowerShell 7.6.5, CPU i7-13620H con 16 procesadores lógicos, 15,63 GiB de RAM y aproximadamente 1,2–1,3 GiB libres, más unos 693 GiB libres en C:. Docker estaba instalado pero el motor Linux no respondía; kubectl no tenía contextos. Ver [environment.json](evidence/baseline/environment.json). Se recuperó Docker Desktop y se verificó el motor Linux 29.6.1. El 23 de octubre se creó kind-devsu con kubeconfig dedicado, nodo limitado a 4 GiB/cuatro CPU y ensayos reales. Los logs preservan la recuperación de sockets de Docker y el primer intento de construcción interrumpido por presión de memoria.

El clúster local quedó operativo con dos réplicas tras finalizar la carga. La presión de memoria requirió ejecutar etapas por separado y aceptar conscientemente el preflight de memoria baja, manteniendo límites del nodo y contenedores. Los requests/limits son valores iniciales del ejercicio; las mediciones acotadas no sustituyen un estudio de capacidad.

La identidad `mpguevara`, la creación del repositorio público, push, Actions y publicación GHCR fueron verificados realmente. La primera ejecución remota falló por resolución múltiple de kubectl en Ubuntu; la siguiente revisión selecciona el primer ejecutable del PATH y aprobó el pipeline completo. En local se corrigió además un HTTP 500 transitorio tras reiniciar PostgreSQL separando su Service cliente estable del headless y esperando readiness estable. Los resultados fallidos permanecen separados de los satisfactorios.

Se mantendrá un registro sencillo de problemas reales con: comando o paso, error observado, causa comprobada o hipótesis identificada como tal, corrección y resultado posterior. No se crearán incidencias, capturas, commits ni fallos artificiales.

Quedan fuera de la propuesta inicial Terraform, Argo CD, service mesh, múltiples entornos permanentes y una plataforma completa de monitorización. Solo se añadirán componentes necesarios para un requisito demostrado. Los diagramas del README representarán la arquitectura implementada y el flujo real del pipeline.

## Preguntas de defensa por etapa

### Etapa 1: diagnóstico

1. ¿Qué archivos demuestran la versión de Java, Spring Boot y Maven? ¿Cuál es la diferencia entre una versión declarada y una herramienta instalada?
2. ¿Qué pruebas existen y qué partes de la aplicación comprueban realmente?
3. ¿Por qué H2 de archivo y `ddl-auto=create` son un problema para réplicas y reinicios?

### Etapa 2: contenedor

1. ¿Por qué separar la construcción y la ejecución en dos etapas de Docker?
2. ¿Cómo se comprueba que el proceso usa un usuario sin privilegios y qué rutas necesita escribir?
3. ¿Qué diferencia hay entre startup, liveness y readiness? ¿Qué ocurriría si liveness dependiera de la BD?

### Etapa 3: datos y calidad

1. ¿Por qué las réplicas necesitan una base de datos compartida y cómo se evita recrear el esquema?
2. ¿Qué garantiza una migración y qué validaciones adicionales requiere cambiar de H2 a PostgreSQL?
3. ¿Qué mide JaCoCo, qué halló el analizador elegido y por qué cobertura alta no garantiza pruebas útiles?

### Etapa 4: Kubernetes

1. ¿Qué responsabilidad cumplen Deployment, Service, ConfigMap, Secret y volumen persistente?
2. ¿En qué se diferencian requests y limits? ¿Cómo afectan los requests al HPA por CPU?
3. ¿Qué componentes siguen siendo puntos únicos de fallo aunque la aplicación tenga dos réplicas?

### Etapa 5: pipeline

1. ¿Qué controles impiden publicar o desplegar una imagen defectuosa?
2. ¿Cómo se relacionan commit, etiqueta, digest, ejecución del pipeline y despliegue?
3. ¿Qué prueba desplegar en kind y qué trabajo quedaría pendiente para un clúster permanente?

### Etapa 6: validación

1. ¿Qué evidencia demuestra que ambas réplicas ven los mismos datos y que un reinicio los conserva?
2. ¿Qué necesita el HPA para escalar y cómo se distingue un problema de métricas de falta de carga?
3. ¿Qué fallos reales se encontraron, cómo se resolvieron y cuáles siguen pendientes?

### Etapa 7: entrega

1. ¿Puede otra persona reproducir la solución a partir del README y qué requisitos necesita?
2. ¿Qué resultados tienen evidencia verificable y qué limitaciones se declaran explícitamente?
3. ¿Qué se mejoraría para producción y por qué esas mejoras exceden esta prueba de siete días?
