# Validación de las instrucciones antes de la entrega

Revisión del 23 de octubre de 2026, hora de El Salvador. Se contrastaron las cuatro capturas del enunciado aportadas por el candidato con los archivos versionados y la evidencia real. La [comprobación de metadatos públicos, enlaces y correspondencia del código](evidence/delivery-review/review.json) registra el alcance de esta revisión. Esta revisión no constituye el envío a la plataforma del ejercicio.

**Resultado: la implementación cubre los puntos de desarrollo solicitados y los entregables están preparados. Queda adjuntar el ZIP y colocar los enlaces en los comentarios del ejercicio.** No se utiliza un endpoint público de la API; el enunciado permite expresamente Kubernetes local.

## Trazabilidad de los puntos de desarrollo

| Instrucción | Estado comprobado | Archivos y evidencia |
|---|---|---|
| Elegir solo una aplicación del ZIP inicial y revisar su README | Aplicación Java conservada; no se incluyen las aplicaciones Node ni Python. La línea base y las diferencias posteriores están documentadas. | [README original](evidence/baseline/README-original.md), [diagnóstico](DIAGNOSTICO.md), [hashes originales](evidence/baseline/source-original.sha256.json) |
| Dockerizar: variables, usuario, puerto y healthcheck | Build de dos etapas, bases fijadas por digest, Maven Wrapper, usuario `10001:10001`, puerto 8000 y healthcheck de readiness; perfiles y credenciales mediante entorno. | [Dockerfile](../Dockerfile), [configuración](../src/main/resources/application.properties), [guía Docker](DOCKER-Y-SALUD.md), [imagen final](evidence/pipeline/remote-run-40048321809/image.json) |
| Pipeline como código: compilación | `Maven verify` compila, prueba y empaqueta; el build Docker también ejecuta los controles. | [Workflow](../.github/workflows/ci.yml), [resumen de calidad real](evidence/pipeline/remote-run-40048321809/quality-summary.json) |
| Unit Tests | 22 pruebas Java aprobadas, sin errores, fallos ni omitidas. Incluyen seis pruebas unitarias aisladas del servicio y pruebas de integración de otros componentes. | [Pruebas Java](../src/test/java/devsu/devops/demo/), [calidad](CALIDAD.md), [resultados reales](evidence/pipeline/remote-run-40048321809/quality-summary.json) |
| Static Code Analysis | PMD ejecutado en el pipeline, cero infracciones en las reglas configuradas. | [Reglas PMD](../config/pmd/ruleset.xml), [POM](../pom.xml), [reporte real](evidence/pipeline/remote-run-40048321809/pmd.xml) |
| Code Coverage | JaCoCo: 51/58 líneas, 87,93%; gate global de 85% y gate de 100% en líneas y ramas del servicio aprobados. | [POM](../pom.xml), [resumen real](evidence/pipeline/remote-run-40048321809/quality-summary.json) |
| Docker build y push | Imagen construida, examinada y publicada realmente en GHCR con etiqueta del commit y digest registrado. | [Publicación](evidence/pipeline/remote-run-40048321809/publication.json), [identidad de la imagen](evidence/pipeline/remote-run-40048321809/image-identity-check.json) |
| Vulnerability scan, opcional | Implementado: escaneo de imagen y de SBOM; se bloquean CRITICAL/HIGH, errores de escaneo e inventario incompleto. Imagen: 0 críticas, 0 altas, 28 medias y 4 bajas. SBOM: cero hallazgos. | [Seguridad](SEGURIDAD.md), [resultados finales](evidence/pipeline/remote-run-40048321809/README.md), [inventario de JAR](evidence/pipeline/remote-run-40048321809/sbom-security/inventory-after-scan.json) |
| Kubernetes local o público con al menos dos réplicas | Deployment con mínimo dos réplicas; ejecución real en kind local y en kind efímero de CI. PostgreSQL compartido evita bases distintas por réplica. | [Deployment](../k8s/app.yaml), [PostgreSQL](../k8s/postgres.yaml), [validación remota](evidence/pipeline/remote-run-40048321809/kubernetes/kubernetes-evidence/kubernetes-results.json), [validación local](evidence/security-remediation/local-kubernetes/kubernetes-results.json) |
| Escalamiento horizontal | HPA CPU, mínimo 2 y máximo 4; escalamiento real de 2 a 4 pods Ready en CI bajo carga HTTP. | [HPA](../k8s/hpa.yaml), [historial real](evidence/pipeline/remote-run-40048321809/kubernetes/kubernetes-evidence/hpa-history.json) |
| ConfigMaps, Secrets, Ingress y recursos necesarios | ConfigMap, Secret generado sin publicar sus valores, Ingress Traefik, Service, probes, requests/limits, restricciones de seguridad y PVC PostgreSQL. | [Manifiestos](../k8s/), [script que crea o reutiliza el Secret](../scripts/Deploy-Kubernetes.ps1), [guía Kubernetes](KUBERNETES.md) |
| Agregar el despliegue a Kubernetes en el pipeline | Job `Deploy and validate private Kubernetes` aprobado. Despliega los mismos bytes de la imagen construida mediante archivo con checksum. | [Workflow](../.github/workflows/ci.yml), [cuatro jobs reales](evidence/pipeline/remote-run-40048321809/jobs.json), [comprobación de identidad](evidence/pipeline/remote-run-40048321809/image-identity-check.json) |
| Documentación en README con diagramas | README contiene preparación, ejecución, pruebas, Docker, pipeline, Kubernetes, diagramas Mermaid, enlaces a decisiones y limitaciones. | [README](../README.md), [decisiones de migración](MIGRACION-SEGURIDAD-JAVA.md), [preguntas por etapa](PLAN-DE-TRABAJO.md#preguntas-de-defensa-por-etapa) |
| Indicar requisitos sin cumplir y explicar limitaciones | No hay punto de desarrollo obligatorio identificado como pendiente. Las limitaciones de producción y las tareas de envío se explican a continuación. | [Consolidado de resultados](evidence/final-verification.json), [seguridad](SEGURIDAD.md), [Kubernetes](KUBERNETES.md) |

Los resultados anteriores proceden del [run final 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809), ejecutado sobre `81beb47ba4b03f98e407860d94d143a22f2d2771`. La API pública de GitHub volvió a consultarse para esta revisión y confirmó repositorio público y los cuatro jobs en `success`. Los cambios posteriores a ese commit son documentación y evidencias; no modifican la aplicación, el Dockerfile, los manifiestos, el POM ni el workflow validado. Esta revisión documental no se presenta como una nueva ejecución de pruebas o de escaneo.

## Entregables y acciones de envío

| Entregable del enunciado | Preparado | Acción pendiente en la plataforma |
|---|---|---|
| Repositorio público creado por el candidato, con todos los archivos generados pertinentes | [Repositorio GitHub](https://github.com/mpguevara/devsu-demo-devops-java), fuentes, infraestructura, pipeline, documentación y evidencia versionada. Se excluyen datos locales, credenciales, cachés y binarios generados pesados. | Pegar esta URL en los comentarios del ejercicio. |
| Archivo `.zip` o `.rar` | `devsu-demo-devops-java-entrega.zip`, generado desde `git archive HEAD`; el manifiesto adjunto registra commit, SHA-256 y hashes de sus archivos. [Script de generación y comprobación](../scripts/New-Delivery.ps1). | Adjuntar el ZIP final. No se requiere generar también RAR. |
| Resultado real del pipeline por URL pública o capturas y resultados | [Pipeline público aprobado](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809), además de [logs y resultados conservados](evidence/pipeline/remote-run-40048321809/README.md). La URL pública satisface esta alternativa; no son obligatorias capturas adicionales. | Pegar la URL del run final en los comentarios. |
| URL pública del endpoint, si es posible | No existe. El acceso local mediante Ingress y port-forward está documentado y verificado. | Indicar que el despliegue es local, permitido expresamente. |

Después de cualquier cambio documental final, se confirma un commit real y limpio, se ejecuta `scripts/New-Delivery.ps1` y se comprueba que el commit del manifiesto corresponde al HEAD público. El manifiesto queda fuera del repositorio para evitar que el archivo incluya su propio hash. No se incluye una copia de la imagen OCI en el ZIP; su construcción y publicación forman parte del pipeline y los metadatos permanecen versionados.

Texto preparado para los comentarios del ejercicio:

> Repositorio público: https://github.com/mpguevara/devsu-demo-devops-java
>
> Ejecución real del pipeline: https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809
>
> Adjunto el ZIP del proyecto con código, Dockerfile, pipeline, manifiestos Kubernetes, documentación, diagramas y evidencias. El despliegue se validó en Kubernetes local y en un clúster efímero de CI, con mínimo dos réplicas y escalamiento horizontal observado. No hay endpoint público; el acceso local y su validación se explican en el README.

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
