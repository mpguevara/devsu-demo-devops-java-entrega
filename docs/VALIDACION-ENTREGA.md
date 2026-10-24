# Validación de las instrucciones antes de la entrega

Revisión actualizada el 23 de octubre de 2026, hora de El Salvador. Se contrastaron las cuatro capturas del enunciado aportadas por el candidato con los archivos versionados y la evidencia real. La [revisión anterior de entrega](evidence/delivery-review/review.json) se conserva como histórica. Esta matriz utiliza la [metadata del nuevo run](evidence/pipeline/remote-run-40060607467/run-metadata.json) y los [cuatro jobs aprobados](evidence/pipeline/remote-run-40060607467/jobs.json) del repositorio de entrega. Esta revisión no constituye el envío a la plataforma del ejercicio.

**Resultado: la implementación cubre los puntos de desarrollo solicitados y los entregables están preparados. Queda adjuntar el ZIP y colocar los enlaces en los comentarios del ejercicio.** No se utiliza un endpoint público de la API; el enunciado permite expresamente Kubernetes local.

## Trazabilidad de los puntos de desarrollo

| Instrucción | Estado comprobado | Archivos y evidencia |
|---|---|---|
| Elegir solo una aplicación del ZIP inicial y revisar su README | Aplicación Java conservada; no se incluyen las aplicaciones Node ni Python. La línea base y las diferencias posteriores están documentadas. | [README original](evidence/baseline/README-original.md), [diagnóstico](DIAGNOSTICO.md), [hashes originales](evidence/baseline/source-original.sha256.json) |
| Dockerizar: variables, usuario, puerto y healthcheck | Build de dos etapas, bases fijadas por digest, Maven Wrapper, usuario `10001:10001`, puerto 8000 y healthcheck de readiness; perfiles y credenciales mediante entorno. | [Dockerfile](../Dockerfile), [configuración](../src/main/resources/application.properties), [guía Docker](DOCKER-Y-SALUD.md), [imagen final de entrega](evidence/pipeline/remote-run-40060607467/image.json) |
| Pipeline como código: compilación | `Maven verify` compila, prueba y empaqueta; el build Docker también ejecuta los controles. | [Workflow](../.github/workflows/ci.yml), [resumen de calidad real](evidence/pipeline/remote-run-40060607467/quality-summary.json) |
| Unit Tests | 22 pruebas Java aprobadas, sin errores, fallos ni omitidas. Incluyen seis pruebas unitarias aisladas del servicio y pruebas de integración de otros componentes. | [Pruebas Java](../src/test/java/devsu/devops/demo/), [calidad](CALIDAD.md), [resultados reales](evidence/pipeline/remote-run-40060607467/quality-summary.json) |
| Static Code Analysis | PMD ejecutado en el pipeline, cero infracciones en las reglas configuradas. | [Reglas PMD](../config/pmd/ruleset.xml), [POM](../pom.xml), [reporte real](evidence/pipeline/remote-run-40060607467/pmd.xml) |
| Code Coverage | JaCoCo: 51/58 líneas, 87,93%; gate global de 85% y gate de 100% en líneas y ramas del servicio aprobados. | [POM](../pom.xml), [resumen real](evidence/pipeline/remote-run-40060607467/quality-summary.json) |
| Docker build y push | Imagen construida, examinada y publicada realmente en GHCR del repositorio de entrega, con etiqueta del commit y digest registrado. | [Publicación](evidence/pipeline/remote-run-40060607467/publication.json), [identidad de la imagen](evidence/pipeline/remote-run-40060607467/image-identity-check.json) |
| Vulnerability scan, opcional | Implementado: escaneo de imagen y de SBOM; se bloquean CRITICAL/HIGH, errores de escaneo e inventario incompleto. Imagen: 0 críticas, 0 altas, 28 medias y 4 bajas. SBOM: cero hallazgos. | [Seguridad](SEGURIDAD.md), [resultados finales de entrega](evidence/pipeline/remote-run-40060607467/README.md), [inventario de JAR](evidence/pipeline/remote-run-40060607467/sbom-security/inventory-after-scan.json) |
| Kubernetes local o público con al menos dos réplicas | Deployment con mínimo dos réplicas; nuevo CI con 30/30 comprobaciones y PostgreSQL compartido. El ensayo local anterior se conserva como histórico de su propia imagen. | [Deployment](../k8s/app.yaml), [PostgreSQL](../k8s/postgres.yaml), [validación remota nueva](evidence/pipeline/remote-run-40060607467/kubernetes/kubernetes-evidence/kubernetes-results.json), [validación local histórica](evidence/security-remediation/local-kubernetes/kubernetes-results.json) |
| Escalamiento horizontal | HPA CPU, mínimo 2 y máximo 4; el nuevo CI observó de 2 a 4 pods Ready bajo carga HTTP, con 16.736 GET exitosos y cero fallidos. | [HPA](../k8s/hpa.yaml), [historial real del nuevo run](evidence/pipeline/remote-run-40060607467/kubernetes/kubernetes-evidence/hpa-history.json) |
| ConfigMaps, Secrets, Ingress y recursos necesarios | ConfigMap, Secret generado sin publicar sus valores, Ingress Traefik, Service, probes, requests/limits, restricciones de seguridad y PVC PostgreSQL. | [Manifiestos](../k8s/), [script que crea o reutiliza el Secret](../scripts/Deploy-Kubernetes.ps1), [guía Kubernetes](KUBERNETES.md) |
| Agregar el despliegue a Kubernetes en el pipeline | Job `Deploy and validate private Kubernetes` aprobado. Despliega los mismos bytes de la imagen construida mediante archivo con checksum. | [Workflow](../.github/workflows/ci.yml), [cuatro jobs reales](evidence/pipeline/remote-run-40060607467/jobs.json), [comprobación de identidad](evidence/pipeline/remote-run-40060607467/image-identity-check.json) |
| Documentación en README con diagramas | README contiene preparación, ejecución, pruebas, Docker, pipeline, Kubernetes, diagramas Mermaid, enlaces a decisiones y limitaciones. | [README](../README.md), [decisiones de migración](MIGRACION-SEGURIDAD-JAVA.md), [preguntas por etapa](PLAN-DE-TRABAJO.md#preguntas-de-defensa-por-etapa) |
| Indicar requisitos sin cumplir y explicar limitaciones | No hay punto de desarrollo obligatorio identificado como pendiente. Las limitaciones de producción y las tareas de envío se explican a continuación. | [Consolidado de resultados](evidence/final-verification.json), [seguridad](SEGURIDAD.md), [Kubernetes](KUBERNETES.md) |

Los resultados de entrega proceden del [run final 40060607467](https://github.com/mpguevara/devsu-demo-devops-java-entrega/actions/runs/40060607467), ejecutado sobre `d3af234b09be0241e0ba339e974572da0b506e3a`, con conclusión global y cuatro jobs en `success`. Transcurrió el 24 de octubre de 2026 de 04:00:28 a 04:09:51 UTC, 9 minutos y 23 segundos; corresponde al 23 de octubre de 22:00:28 a 22:09:51 en El Salvador. Las actualizaciones documentales posteriores no se presentan como nuevas ejecuciones de pruebas o escaneos.

El [repositorio original](https://github.com/mpguevara/devsu-demo-devops-java) estuvo conservado durante la migración y se eliminó después por solicitud explícita del usuario, confirmado el 23 de octubre de 2026 a las 22:48, hora de El Salvador. Su URL y la del [run 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) se mantienen como procedencia histórica y ya no están disponibles; se conservan las [copias versionadas de sus resultados](evidence/pipeline/remote-run-40048321809/README.md). La [verificación de la eliminación](evidence/repository-migration/deletion-verification.json) registra las comprobaciones. El ensayo local de `81beb47`, sus 7.104 GET exitosos y la conservación de los usuarios, PVC y Flyway/V1 siguen asociados a aquella imagen, no a la nueva revisión de entrega. El [registro de migración](evidence/repository-migration/README.md) conserva la procedencia, las incidencias y su resolución.

Antes de regenerar la entrega se realizó un [saneamiento explícito de metadatos](evidence/report-metadata-sanitization/README.md): 25 copias XML de Surefire sustituyen el valor de `java.library.path` por un marcador. Una [segunda operación reescribió los ocho commits anteriores de `main` del repositorio original](evidence/history-metadata-sanitization/README.md) para sanear también esos valores históricos, preservando sus autores, fechas, mensajes, resultados y restantes bytes. No se alteraron los reportes del pipeline, JaCoCo o PMD ni se atribuyeron ejecuciones a los nuevos SHA; GitHub puede conservar acceso a objetos antiguos fuera del historial recorrido de aquel repositorio.

## Entregables y acciones de envío

| Entregable del enunciado | Preparado | Acción pendiente en la plataforma |
|---|---|---|
| Repositorio público creado por el candidato, con todos los archivos generados pertinentes | [Repositorio GitHub de entrega](https://github.com/mpguevara/devsu-demo-devops-java-entrega), fuentes, infraestructura, pipeline, documentación y evidencia versionada. Se excluyen datos locales, credenciales, cachés y binarios generados pesados. | Pegar esta URL en los comentarios del ejercicio. |
| Archivo `.zip` o `.rar` | `devsu-demo-devops-java-entrega.zip`, generado desde `git archive HEAD`; el manifiesto adjunto registra commit, SHA-256 y hashes de sus archivos. [Script de generación y comprobación](../scripts/New-Delivery.ps1). | Adjuntar el ZIP final. No se requiere generar también RAR. |
| Resultado real del pipeline por URL pública o capturas y resultados | [Pipeline público de entrega aprobado](https://github.com/mpguevara/devsu-demo-devops-java-entrega/actions/runs/40060607467), además de [logs y resultados conservados](evidence/pipeline/remote-run-40060607467/README.md). La URL pública satisface esta alternativa; no son obligatorias capturas adicionales. | Pegar la URL del run final en los comentarios. |
| URL pública del endpoint, si es posible | No existe. El acceso local mediante Ingress y port-forward está documentado y verificado. | Indicar que el despliegue es local, permitido expresamente. |

Después de cualquier cambio documental final, se confirma un commit real y limpio, se ejecuta `scripts/New-Delivery.ps1` y se comprueba que el commit del manifiesto corresponde al HEAD público. El manifiesto queda fuera del repositorio para evitar que el archivo incluya su propio hash. No se incluye una copia de la imagen OCI en el ZIP; su construcción y publicación forman parte del pipeline y los metadatos permanecen versionados.

Texto preparado para los comentarios del ejercicio:

> Repositorio público: https://github.com/mpguevara/devsu-demo-devops-java-entrega
>
> Ejecución real del pipeline: https://github.com/mpguevara/devsu-demo-devops-java-entrega/actions/runs/40060607467
>
> Adjunto el ZIP del proyecto con código, Dockerfile, pipeline, manifiestos Kubernetes, documentación, diagramas y evidencias. El nuevo pipeline aprobó sus cuatro jobs y verificó en Kubernetes efímero 30 comprobaciones, mínimo dos réplicas y escalamiento hasta cuatro Ready. También se conserva un ensayo local histórico de la implementación anterior. No hay endpoint público; el acceso local y su validación se explican en el README.

Este texto está preparado, no enviado. El cumplimiento del plazo de siete días y la recepción de los archivos se verifican en la plataforma del ejercicio; las capturas no permiten comprobarlos.

## Puntos opcionales y límites de la solución

- **Cloud y Terraform:** el enunciado enumera IaC entre las habilidades y expresa preferencia por Terraform; no lo exige como herramienta en los puntos de desarrollo. Se entrega configuración declarativa Kubernetes y kind. No se implementó Terraform ni aprovisionamiento cloud, y no se afirma experiencia demostrada en esos dos componentes por esta entrega.
- **DNS y TLS:** el enunciado los menciona como contenido adicional a considerar para producción. El acceso actual usa loopback y cabecera `Host: devsu.local`, sin dominio ni certificado público. Para exposición externa harían falta DNS, TLS y controles de acceso acordes al entorno.
- **Disponibilidad y recuperación:** un nodo kind y una instancia PostgreSQL con PVC no aportan alta disponibilidad. Se comprobó persistencia al sustituir pods; no se verificó recuperación ante pérdida del disco ni restauración de backups.
- **Seguridad:** quedan 28 hallazgos medios y 4 bajos del sistema base, documentados sin ocultarlos. Cero críticas y altas detectadas en el inventario y snapshot utilizados no equivale a ausencia de todo riesgo. El alcance no incluye un análisis exhaustivo de autorización ni el escaneo de todas las imágenes de infraestructura.
- **Reproducción local:** el fallo real de importación Docker Desktop → kind y la [alternativa verificada con el digest exacto](evidence/security-remediation/local-image/README.md) están conservados. El ejemplo general del README construye una imagen local; la alternativa documenta el caso observado con la imagen descargada del registro.
- **Dimensionamiento:** requests/limits y carga acotada demuestran configuración y funcionamiento del HPA, no un SLA ni capacidad de producción.

## Preguntas finales de defensa

1. ¿Qué evidencia demuestra que el pipeline desplegó la misma imagen que construyó y examinó?
2. ¿Por qué H2 en memoria no proporciona datos compartidos entre réplicas y qué aporta PostgreSQL con Flyway?
3. ¿En qué se diferencian liveness y readiness, y por qué solo readiness depende de la base de datos?
4. ¿Qué necesita el HPA para calcular CPU y qué resultado demuestra escalamiento real?
5. ¿Por qué se añadió el SBOM además del escaneo de imagen y cómo se comprobó su inventario?
6. ¿Qué falta para llevar este despliegue local a producción y cuáles de esos puntos eran opcionales en el ejercicio?
