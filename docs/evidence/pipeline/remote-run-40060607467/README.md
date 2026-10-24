# Ejecución real de entrega: 40060607467

El [run de GitHub Actions](https://github.com/mpguevara/devsu-demo-devops-java-entrega/actions/runs/40060607467) ejecutó la revisión `d3af234b09be0241e0ba339e974572da0b506e3a`, evento `push`, rama `main`, en el repositorio público `mpguevara/devsu-demo-devops-java-entrega`. Conclusión: **success, cuatro jobs aprobados**. Inicio: 24 de octubre de 2026 a las 04:00:28 UTC; finalización: 04:09:51 UTC, **9 minutos y 23 segundos**. En El Salvador corresponde al 23 de octubre, 22:00:28–22:09:51.

| Job | Resultado real |
|---|---|
| Compile, test, PMD and coverage | 22 pruebas Java aprobadas; 0 fallos, errores u omitidas; PMD 0; JaCoCo 51/58 líneas = 87,93 % y 2/2 ramas = 100 %; gates activos |
| Build and inspect the image | Docker build completo; UID/GID 10001; escaneos reales de imagen y SBOM e inventarios aprobados |
| Publish the verified image to GHCR | Push real al paquete del repositorio nuevo; digest registrado |
| Deploy and validate private Kubernetes | 30/30 comprobaciones aprobadas; persistencia, Ingress y escalamiento real; limpieza sin errores |

[run-metadata.json](run-metadata.json), [jobs.json](jobs.json) y [artifacts-metadata.json](artifacts-metadata.json) proceden de las APIs de GitHub. Se descargaron los artifacts de calidad, imagen, publicación y Kubernetes. El artifact pesado `container-40060607467` solo transporta la imagen entre jobs; no se incorpora al repositorio ni al ZIP del código.

La [comparación de copias](artifact-copy-verification.json) comprobó 118 archivos contra los artifacts descargados, sin diferencias de bytes. Los metadatos de API y los chequeos derivados se identifican aparte. [files-sha256.json](files-sha256.json) registra las huellas de esta carpeta, excluyéndose a sí mismo. La [revisión de patrones de credenciales](evidence-secret-check.json) no encontró candidatos en su alcance declarado.

## Calidad y pruebas

El [resumen de calidad](quality-summary.json) conserva el comando real, versión Java, tiempos y exit code. Los [XML y textos Surefire](surefire/), [log Maven](maven-verify.log), [JaCoCo XML](jacoco.xml), [CSV](jacoco.csv) y [PMD XML](pmd.xml) respaldan los contadores. Las 22 pruebas incluyen seis unitarias aisladas del servicio y pruebas Spring de otros componentes; no se presentan todas como unitarias aisladas. El servicio conserva 14/14 líneas y 2/2 ramas cubiertas.

También aprobaron [ocho pruebas offline de política](policy-unit-tests/policy-test-results.json) y [cuatro de inventario](sbom-inventory-unit-tests/test-results.json). Sus entradas sintéticas e informes deliberadamente inválidos son fixtures identificados, no fallos o CVE reales. No ejecutan el escáner y se contabilizan aparte de las pruebas Java.

## Seguridad e inventario

| Control | Resultado |
|---|---|
| Imagen, Trivy real | 0 CRITICAL, 0 HIGH, 28 MEDIUM, 4 LOW, 0 UNKNOWN |
| SBOM, Trivy real | Cero hallazgos en todas las severidades |
| Dependencias empaquetadas | 97/97 JAR coinciden por SHA-256 con componentes del SBOM |
| Coordenadas históricas | 14/14 presentes e incluidas en el inventario analizado |
| Grafo SBOM completo | 110/110 componentes por PURL en 111 registros Trivy, incluida la aplicación |

Los informes completos son [trivy-image.json](security/trivy-image.json) y [trivy-sbom.json](sbom-security/trivy-sbom.json). Los resúmenes [de imagen](security/scan-summary.json) y [de SBOM](sbom-security/scan-summary.json) aprobaron la política antes de publicar o desplegar. Se conservan todas las severidades, sin exclusiones de CVE ni omitir vulnerabilidades sin corrección. Los 32 hallazgos de Ubuntu permanecen en [findings-all.csv](security/findings-all.csv) y [prioridades](security/PRIORIDADES.md).

[inventory-after-scan.json](sbom-security/inventory-after-scan.json) vincula hashes de los JAR, coordenadas y PURL analizados. El [chequeo adicional de todos los componentes](sbom-security/all-components-inventory-check.json) se calculó sobre el SBOM extraído y el reporte Trivy real descargados de este run. No sustituye el control de los bytes empaquetados.

Trivy fue la versión 0.76.1. Su base de vulnerabilidades se actualizó el 24 de octubre a las 01:18:19 UTC y se descargó a las 04:03:57 UTC; la base Java se actualizó a las 01:07:32 UTC y se descargó a las 04:04:20 UTC. Las fechas completas permanecen en [trivy-version.json](security/trivy-version.json). Son el snapshot utilizado, no una garantía futura ni un análisis exhaustivo de seguridad.

## Publicación e identidad de la imagen

Imagen: `ghcr.io/mpguevara/devsu-demo-devops-java-entrega:d3af234b09be0241e0ba339e974572da0b506e3a`.

Digest del manifiesto: `sha256:0eaf1b44fe7dd51fb95df7ba938b398a2f09a902c79a1c541463fe0d5ffe9397`.

[publication.json](publication.json) y [ghcr-push.log](ghcr-push.log) conservan la publicación real. La [consulta anónima](ghcr-anonymous-check.json) devolvió HTTP 200 y verificó el hash de los bytes del [manifiesto recibido](registry-manifest.json). Su configuración apunta a `sha256:a6f88288689ac71a5d2892875ad48ac507070aed931c00342faa899aaf83694f`, el mismo ID de [image.json](image.json).

Los [metadatos OCI comprobados](registry-image-metadata.json) confirman el hash del blob de configuración, UID/GID 10001, nueve DiffIDs, etiqueta de origen del repositorio nuevo y revisión `d3af234…`. No se conservan tokens, URLs firmadas, el entorno completo ni el blob completo de configuración. Estas consultas verifican metadatos anónimos; no demuestran un pull completo de capas.

El [chequeo de identidad](image-identity-check.json) compara el ID del job de construcción y el registrado por el despliegue antes de cargar la imagen en kind: ambos coinciden. El workflow transfiere `docker save` con checksum y carga esos mismos bytes en publicación y Kubernetes. Este CI no se presenta como un pull de GHCR dentro del nodo.

## Kubernetes y carga HTTP

[kubernetes-results.json](kubernetes/kubernetes-evidence/kubernetes-results.json) registra 30 comprobaciones aprobadas: dos pods iniciales Ready, usuario sin privilegios, creación y lectura entre réplicas, Ingress mediante `Host: devsu.local`, reemplazo del pod Java, reinicio de PostgreSQL conservando PVC y datos, readiness estable y HPA bajo carga HTTP.

Los 16 trabajadores registraron **16.736 GET exitosos y 0 fallidos**. [hpa-history.json](kubernetes/kubernetes-evidence/hpa-history.json) muestra 2/2 Ready al comenzar y 4/4 Ready al final; la CPU final fue 487 % de la solicitud de 100m por pod. Las advertencias transitorias y los tiempos reales permanecen en la evidencia.

La carga se detiene al observar escalamiento y nuevas réplicas Ready. El límite configurado de 300 segundos no significa que se ejecutara durante 300 segundos; no se deduce una tasa desde una duración supuesta. No hubo errores de limpieza. El clúster del runner es efímero, sin endpoint público, y no modifica el clúster local del candidato.

## Procedencia y límites

Las ejecuciones anteriores conservan sus repositorios, URLs, SHA, imagen y digest originales. El [registro de migración](../../repository-migration/README.md) separa esta revalidación de los ensayos locales históricos y documenta el intento inicial de dispatch y el problema resuelto al interpretar la respuesta binaria del registry. Los cambios finales de documentación no modifican el código o automatización validados por este run.

La evidencia acredita esta ejecución acotada: no disponibilidad continua, alta disponibilidad de PostgreSQL, restauración de backups, recuperación ante pérdida del disco ni capacidad de producción. El repositorio anterior se conserva.
