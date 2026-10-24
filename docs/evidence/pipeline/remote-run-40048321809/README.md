# Ejecucion real final: 40048321809

[GitHub Actions](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) ejecuto la revision `81beb47ba4b03f98e407860d94d143a22f2d2771`, rama `main`, evento `push`. Inicio: 24 de octubre de 2026 a las 01:07:15 UTC; ultima actualizacion final: 01:16:35 UTC, **9 minutos y 20 segundos**. En El Salvador corresponde al 23 de octubre de 2026, 19:07:15-19:16:35. Conclusion global: **success**, cuatro jobs aprobados.

| Job | Resultado real |
|---|---|
| Compile, test, PMD and coverage | 22 pruebas Java, 0 fallos/errores/omitidas; PMD 0; LINE 51/58 = 87,93%; BRANCH 2/2 = 100%; fixtures offline 8 de politica y 4 de inventario aprobados |
| Build and inspect the image | Build completo, usuario 10001:10001; dos escaneos reales aprobados e inventario completo por SHA256/PURL |
| Publish the verified image to GHCR | Push real, digest conservado y consulta anonima del manifiesto confirmada |
| Deploy and validate private Kubernetes | 30/30 comprobaciones, persistencia y HPA aprobados, sin errores de limpieza |

[run-metadata.json](run-metadata.json), [jobs.json](jobs.json) y [artifacts-metadata.json](artifacts-metadata.json) proceden de GitHub. Los resultados Maven estan en [quality-summary.json](quality-summary.json), Surefire, JaCoCo y PMD. Los fixtures se identifican como `unit-test-fixture` y no ejecutan el escaner; se distinguen de los escaneos reales y de las 22 pruebas Java. Los umbrales de calidad del POM permanecen activos.

## Escaneos y cobertura comprobada

| Control real | Resultado |
|---|---|
| Trivy imagen | 0 CRITICAL, 0 HIGH, 28 MEDIUM, 4 LOW, 0 UNKNOWN; 32 hallazgos de paquetes Ubuntu |
| Trivy SBOM | 0 hallazgos de todas las severidades |
| Hashes de dependencias empaquetadas | 97/97 JAR de `BOOT-INF/lib` coinciden por SHA256 con componentes Maven del SBOM |
| Inventario efectivamente analizado | Todos los PURL empaquetados y las 14 coordenadas historicas presentes en Trivy |
| Componentes adicionales del BOM | Los 110 componentes del SBOM aparecen en los 111 registros del escaner, incluida la aplicacion |
| Limpieza | Contenedor temporal y JAR extraido retirados; el JAR no se incorpora a los artifacts de evidencia |

[sbom-check-results.json](sbom-security/sbom-check-results.json) registra la extraccion real de `/app/app.jar` y `/app/sbom.json` de la misma imagen, sin arrancar el contenedor temporal. [inventory-before-scan.json](sbom-security/inventory-before-scan.json) e [inventory-after-scan.json](sbom-security/inventory-after-scan.json) conservan el SHA256 del JAR completo, del SBOM y de cada dependencia; tambien sus coordenadas y PURL. El numero 97 fue medido, no fijado en el validador. [all-components-inventory-check.json](sbom-security/all-components-inventory-check.json) conserva la comprobacion adicional 110/110.

El escaneo de imagen conserva el analisis del sistema operativo y paquetes identificados; el segundo analiza las coordenadas Maven del SBOM que genero CycloneDX 2.9.3 dentro del build Docker. De este modo se resuelve la [limitacion observada en la ejecucion previa](../remote-run-40046900827/README.md), donde varias dependencias nuevas no fueron identificadas por el escaneo de archivo. `includeTools=false` evita empaquetar el auxiliar de modos JAR que esta aplicacion no utiliza; no se ocultan dependencias ni CVE del analisis.

Los reportes completos son [trivy-image.json](security/trivy-image.json) y [trivy-sbom.json](sbom-security/trivy-sbom.json). Ambos usan Trivy 0.76.1, todas las severidades, sin exclusiones y sin omitir hallazgos sin correccion. Los dos gates se evaluaron antes de exportar, publicar o desplegar. Sus resúmenes diferencian proceso completado, reporte evaluable y politica aprobada. Los logs conservan tambien las advertencias reales del escaner.

Las fechas de las bases estan en `trivy-version.json` dentro de cada carpeta. En este run la base de vulnerabilidades se actualizo el 23 de octubre a las 19:15:43 UTC y se descargo el 24 de octubre a las 01:10:37 UTC; la base Java disponible se actualizo el 23 de octubre a las 01:03:33 UTC y se descargo el 24 a las 01:11:07 UTC. Son datos reales del snapshot utilizado, no una garantia futura.

Los 32 MEDIUM/LOW permanecen visibles en [findings-all.csv](security/findings-all.csv) y [PRIORIDADES.md](security/PRIORIDADES.md), con versiones instaladas y corregidas tal como las reporta Trivy. Cero CRITICAL/HIGH detectados con este inventario y snapshot no significa ausencia de todo riesgo, autorizacion de la API revisada ni preparacion completa para produccion.

## Publicacion e identidad de la imagen

Imagen: `ghcr.io/mpguevara/devsu-demo-devops-java:81beb47ba4b03f98e407860d94d143a22f2d2771`.

Digest: `sha256:5186197365985f9249e005d82a47b6b7dc3abd7c88b89de6a2dbb45686d7b56e`.

[publication.json](publication.json) y `ghcr-push.log` proceden del job de publicacion. [ghcr-anonymous-check.json](ghcr-anonymous-check.json) registra una consulta anonima del manifiesto: estado 200 y el mismo digest, sin conservar token ni cambiar visibilidad. Esa comprobacion de metadata no equivale a un pull completo de capas.

[image-identity-check.json](image-identity-check.json) compara el ID registrado por construccion y Kubernetes: ambos `sha256:ad99ff140855abbda19fdde585820eaf747b31aba84670fa6d155020bbbb9713`. El workflow transfiere un archivo `docker save` con SHA256 validado antes de cargarlo. El cluster del runner usa esa misma imagen; esta ejecucion no se presenta como un pull de GHCR dentro de kind ni demuestra igualdad de bytes con un build nativo Windows.

## Kubernetes privado

[kubernetes-results.json](kubernetes/kubernetes-evidence/kubernetes-results.json) conserva 30 comprobaciones aprobadas: al menos dos pods Ready, UID 10001, creacion en un pod y lectura desde otro, Ingress con `Host: devsu.local`, sustitucion del pod Java, reinicio del pod PostgreSQL con mismo PVC y datos, recuperacion estable de readiness y escalamiento bajo carga HTTP real.

Dieciseis trabajadores informaron **21.354 peticiones HTTP exitosas y 0 fallidas**. El test completo transcurrio entre 01:14:39 y 01:16:31 UTC. [hpa-history.json](kubernetes/kubernetes-evidence/hpa-history.json) registra dos pods Ready al comienzo y cuatro al final, con CPU final equivalente al 402% de la solicitud de 100m por pod. Las metricas tardaron en estar disponibles; las advertencias transitorias y estados iniciales permanecen en la evidencia.

El Job de carga se detiene al observar escalamiento y nuevas replicas Ready. No se afirma que haya durado 300 segundos completos ni se calcula una tasa desde un tiempo supuesto. La limpieza no produjo errores.

El cluster es efimero y no expone la API publicamente. No hay URL publica de la aplicacion. Esta validacion no demuestra disponibilidad continua, alta disponibilidad de PostgreSQL, recuperacion ante perdida del volumen ni backups restaurables. Se conservaron solo artifacts de calidad, imagen/seguridad, publicacion y Kubernetes; el archivo pesado de imagen no se incluye en el repositorio ni en el ZIP del codigo.
