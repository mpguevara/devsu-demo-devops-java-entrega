# Hoja de ruta guiada de la prueba DevOps

## Objetivo y estado

Preparar únicamente la aplicación Java entregada para construirla, probarla, empaquetarla y desplegarla automáticamente en Kubernetes, con evidencias que permitan explicar cada decisión. El plazo orientativo es de siete días; las etapas se cierran por sus criterios de aceptación, no por el cambio de fecha.

**Estado de esta hoja de ruta:** las etapas 1 y 2 están completadas. La etapa 1 conserva seis pruebas originales y nueve comprobaciones HTTP en [el diagnóstico](DIAGNOSTICO.md) y [la evidencia local](evidence/baseline/README.md). En la etapa 2 se construyó y ejecutó la imagen: 11 pruebas Maven tanto en Windows como en Docker, nueve comprobaciones H2 y 39 comprobaciones Docker con PostgreSQL. Véanse [la guía](DOCKER-Y-SALUD.md) y [las evidencias](evidence/docker-health/README.md). Calidad y Kubernetes siguen pendientes. No existen imágenes publicadas, despliegues Kubernetes, métricas de carga ni resultados de un pipeline remoto.

**Avance de persistencia:** se adelantó la parte de datos de la etapa 3. PostgreSQL, Flyway, perfiles y aislamiento de pruebas están implementados. En esa etapa pasaron seis pruebas Maven, nueve comprobaciones H2 y 36 comprobaciones con PostgreSQL real y dos JVM. Ver [guía y decisiones](POSTGRESQL.md) y [evidencia](evidence/postgres/README.md). La etapa 2 comprobó además persistencia al reiniciar la BD en Docker. El siguiente paso es calidad estática/cobertura; el orden diario se adapta a lo que podemos verificar.

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
| 1. Diagnóstico y línea base | 1 | Verificar Windows, CPU, RAM, disco, WSL, Java, Maven Wrapper, Git, Docker, kubectl e identidad GitHub; leer README y código; ejecutar la línea base disponible. | Versiones y recursos registrados; herramientas presentes, ausentes y bloqueadas distinguidas; resultado original de compilación y pruebas documentado. | Completada: diagnóstico, seis pruebas aprobadas, JAR y nueve comprobaciones HTTP; logs y JSON enlazados al inicio. Docker se recuperó en la etapa 2; publicación pendiente. |
| 2. Empaquetado y salud | 2 | Añadir Actuator y configuración de salud; preparar Docker multietapa, usuario sin privilegios, `.dockerignore` y variables de entorno. | Construir la imagen; iniciar el contenedor; comprobar API, puerto, identidad del usuario y endpoints de salud. | Completada: imagen local, 11 pruebas Maven, dos JAR Linux idénticos y 39 comprobaciones Docker; caída/recuperación de BD, persistencia y apagado ordenado verificados. |
| 3. Datos y controles de calidad | 3 | Aislar pruebas con H2 en memoria; preparar PostgreSQL compartido y migración; añadir JaCoCo y elegir PMD o SpotBugs tras evaluar el código. | Pasar pruebas relevantes; generar cobertura real; ejecutar el analizador elegido; comprobar migración sin recreación de datos al reiniciar. | Datos implementados y comprobados con dos JVM, SQL e historial Flyway; Surefire satisfactorio. JaCoCo y análisis estático pendientes. |
| 4. Kubernetes mínimo | 4 | Preparar PostgreSQL persistente, Deployment Java con dos réplicas, Service, ConfigMap, Secret, recursos, probes y HPA; añadir Ingress si se valida una ruta útil. | Dos pods Java Ready; acceso al servicio; lectura coherente entre réplicas; volumen de BD; manifiestos válidos y configuración aplicada. | Estado de pods, eventos, endpoints del Service, consultas HTTP y configuración efectiva sin secretos. Pendiente. |
| 5. Automatización y registro | 5 | Crear GitHub Actions para compilar, probar, analizar, medir cobertura, construir, escanear y publicar en GHCR; desplegar en un clúster kind temporal del runner. | Un run real en GitHub completa los controles, publica una imagen identificable y comprueba el despliegue de esa imagen. | URL del run, logs y artefactos de reportes, digest de imagen y validaciones de Kubernetes. Pendiente. |
| 6. Validación y resolución de problemas | 6 | Verificar creación/consulta, errores esperados, reinicio, actualización y HPA con métricas; corregir fallos observados. | Validar los escenarios con respuestas y estados reales; separar HPA configurado de escalamiento observado; resolver o registrar cada bloqueo. | Resultados de smoke tests, rollout, persistencia, métricas y cambios de réplicas cuando sea viable. Pendiente. |
| 7. Entrega y defensa | 7 | Completar README y diagramas; revisar datos sensibles; preparar repositorio público y ZIP/ RAR; practicar la explicación. | Una persona puede reproducir los pasos documentados; entregables accesibles; evidencias enlazadas; limitaciones y pendientes explícitos. | URL pública del repositorio, archivo final, URL del pipeline y endpoint público solo si realmente existe. Pendiente. |

Si el diagnóstico local impide una etapa, se continuará con preparación de archivos y validación disponible, manteniendo visible el bloqueo. No se declarará una etapa ejecutada por haber escrito sus archivos.

## Decisiones propuestas y justificación

### Java y construcción

Mantener inicialmente Java 17 y Spring Boot 3.0.5 porque son las versiones declaradas por la aplicación. No incorporar una migración de framework sin una necesidad comprobada. Las vulnerabilidades encontradas podrían justificar actualizaciones acotadas, verificadas con pruebas y documentadas.

Usar Maven Wrapper para fijar Maven. Se actualizó el wrapper de 3.1.1 a 3.3.4 para verificar descargas por checksum, manteniendo Maven 3.8.7. Las bases Docker están fijadas por digest. Dos construcciones limpias Linux generaron el mismo JAR; el alcance y la diferencia de metadatos Windows/Linux están en la guía de Docker. No se afirma identidad de la imagen OCI completa.

### Contenedor y salud

El Dockerfile construye con JDK y ejecuta con JRE 17 y usuario 10001. Compose aplica raíz de solo lectura y `/tmp` en tmpfs; ambas condiciones y la escritura en `/tmp` se verificaron en ejecución. Los límites iniciales son 512 MiB y una CPU para Java; requieren medición con carga antes de considerarse dimensionamiento.

Actuator expone los grupos liveness y readiness bajo `/api/actuator/health`. Liveness comprueba el estado del proceso; readiness incluye PostgreSQL. Al detener la BD se observaron liveness 200/UP y readiness 503/DOWN; al recuperarla, readiness volvió a 200/UP sin reiniciar Java. Una futura startupProbe Kubernetes podrá consultar liveness durante el arranque; no se añadió un endpoint HTTP llamado startup.

### Datos compartidos entre réplicas

Se mantiene H2 para ejecución sencilla y pruebas aisladas. PostgreSQL es el perfil predeterminado; se añadió Flyway 9.5.1, una migración V1 y validación de esquema al iniciar. Dos JVM sobre PostgreSQL real ya comprobaron lectura compartida e historial con una única migración. El despliegue de esa configuración en Kubernetes sigue pendiente.

Una instancia PostgreSQL con volumen persistente es suficiente para esta prueba. Su disponibilidad sería una limitación explícita: tener dos réplicas Java no convierte la base de datos en altamente disponible. La propuesta conserva los contratos de la API y evita modificar funcionalidades ajenas al ejercicio.

### Cobertura y análisis estático

JaCoCo generará reportes de cobertura y un resultado que pueda adjuntarse al pipeline. Primero se medirá la cobertura existente; después se fijará un umbral razonable y se añadirán pruebas de comportamiento relevantes. No se inventará un porcentaje ni se forzará un umbral arbitrario para aparentar calidad.

Se elegirá **un** analizador tras la línea base: PMD si interesa explicar reglas de código fuente y mantener una configuración pequeña; SpotBugs si aporta hallazgos útiles sobre el bytecode de esta aplicación y compatibilidad adecuada con Lombok y Java 17. La elección final, las reglas y las exclusiones se justificarán con su ejecución real. No es necesario incorporar ambos ni montar un servidor SonarQube para satisfacer este alcance.

### Pipeline y publicación

GitHub Actions y GHCR reducen la cantidad de servicios externos y permiten enlazar la ejecución con el repositorio entregable. Las credenciales de publicación deben proceder del contexto autorizado de GitHub, con permisos mínimos; no deben quedar en archivos. Se fijarán versiones o commits de las acciones utilizadas.

El pipeline propuesto tendrá controles de compilación, pruebas, análisis estático y cobertura antes de publicar. Construirá una imagen, ejecutará un análisis de vulnerabilidades si el runner lo permite, publicará una etiqueta vinculada al commit y registrará el digest. El despliegue deberá usar una imagen identificable para relacionar código, artefacto y evidencia.

Trivy es una opción propuesta para el escaneo. Su versión, base de vulnerabilidades y política de bloqueo se definirán a partir de resultados reales. Los hallazgos heredados se resolverán o documentarán con alcance e impacto; no se ocultarán mediante exclusiones sin explicación.

### Kubernetes y acceso

Un clúster kind temporal en el runner permitirá validar un despliegue real incluso si la máquina local no dispone de Docker operativo o acceso a un clúster. Ese clúster desaparecerá al finalizar el job: prueba el procedimiento de despliegue, pero no constituye un servicio permanente ni proporciona un endpoint público para la entrega.

La aplicación tendrá al menos dos réplicas, requests y limits, probes y HPA. Para demostrar escalamiento por CPU se necesita un proveedor de métricas operativo, normalmente metrics-server, y carga suficiente. Un manifiesto de HPA aceptado no prueba que haya escalado.

ConfigMap contendrá configuración no sensible; Secret recibirá credenciales fuera del repositorio. Base64 no cifra un Secret. El acceso mínimo será mediante Service y port-forward para validación. Ingress se incorporará cuando haya un controlador y una ruta reproducible; no se inventará una URL pública.

## Restricciones y problemas por verificar

El diagnóstico inicial registró Windows 11 x64, PowerShell 7.6.5, CPU i7-13620H con 16 procesadores lógicos, 15,63 GiB de RAM y aproximadamente 1,2–1,3 GiB libres, más unos 693 GiB libres en C:. Docker estaba instalado pero el motor Linux no respondía; kubectl no tenía contextos. Ver [environment.json](evidence/baseline/environment.json). En la etapa 2 se recuperó Docker Desktop y se verificó el motor Linux 29.6.1 con contenedores reales; se conservaron el problema y su resolución en la guía de Docker. El clúster Kubernetes sigue pendiente.

Al redactar este plan no se dispone de evidencia de acceso operativo a un clúster. La ejecución simultánea de IDE, Docker, Kubernetes, Java y PostgreSQL puede estar limitada por los recursos locales; el tamaño del clúster, los recursos de los pods y el tipo de validación se ajustarán al diagnóstico. Los valores iniciales de requests y limits deberán presentarse como una estimación hasta medirlos.

Se verificó la identidad `mpguevara` mediante el conector GitHub. Deben verificarse permisos para crear/publicar el repositorio, acceso a GHCR, disponibilidad de Actions y conectividad a registros de imágenes. La conectividad usada para descargar el JDK y resolver dependencias Maven funcionó en esta etapa. Una descarga o acceso bloqueado se registrará como tal, con la resolución aplicada o la acción pendiente.

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
