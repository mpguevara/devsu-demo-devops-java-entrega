# Ejecucion real 40046900827: remediacion con inventario limitado

[GitHub Actions](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40046900827) ejecuto la revision `ccf1adc4afed257e2c7bb7a7a4005c144f742a9c` por un push a `main`. Inicio: 24 de octubre de 2026 a las 00:49:53 UTC; ultima actualizacion final: 00:58:08 UTC. Conclusion global: **success**, cuatro jobs aprobados. [run-metadata.json](run-metadata.json), [jobs.json](jobs.json) y [artifacts-metadata.json](artifacts-metadata.json) proceden de GitHub.

| Control | Resultado real |
|---|---|
| Java, Maven, PMD y cobertura | 22 pruebas, 0 fallos/errores/omitidas; PMD 0; LINE 51/58 = 87,93%; BRANCH 2/2 = 100% |
| Pruebas unitarias del gate | 8 fixtures offline aprobados, sin ejecutar Trivy |
| Docker | Build completo, usuario `10001:10001` |
| Trivy imagen | 0 CRITICAL, 0 HIGH, 28 MEDIUM, 4 LOW; cobertura Java incompleta detectada despues |
| GHCR | Push real y digest conservado |
| Kubernetes privado | 30/30 comprobaciones; 21.418 peticiones HTTP exitosas y 0 fallidas; HPA de 2 a 4 Ready |

Los resultados de calidad estan en [quality-summary.json](quality-summary.json), Surefire, JaCoCo y PMD. La cobertura menor que la revision anterior refleja la actualizacion real del stack y el codigo generado, sin exclusiones añadidas; el pipeline conservo los umbrales existentes del POM. Los fixtures de politica estan identificados en `policy-unit-tests` y se distinguen de los 22 tests Java y del escaneo real.

## Limite de seguridad descubierto

El [reporte Trivy original](security/trivy-image.json) contiene 32 hallazgos, todos en paquetes Ubuntu; el gate configurado encontro 0 CRITICAL/HIGH entre los paquetes identificados. El analisis posterior encontro que los **62 registros Java** del reporte representan **59 rutas JAR distintas** mas registros adicionales y la aplicacion, mientras el archivo contiene **98 JAR**. Quedaron 39 rutas sin identificar, incluidas dependencias nuevas de Spring, Boot y Micrometer. Por ello este resultado **no cierra la validacion de seguridad** del stack actualizado.

El [diagnostico](../../security-remediation/container-base/JAR-IDENTIFICATION-DIAGNOSTIC.md) conserva la discrepancia real. La siguiente revision añade SBOM Maven y comprobacion SHA256 de todos los JAR, mas comprobacion de los PURL realmente devueltos por `trivy sbom`. Esta ejecucion no contenia ese segundo gate y no se le atribuyen resultados posteriores.

[scan-summary.json](security/scan-summary.json) y [trivy-version.json](security/trivy-version.json) conservan el resultado y las fechas reales de las bases. [findings-all.csv](security/findings-all.csv) contiene los 32 hallazgos con paquete, version instalada y version corregida reportada, incluso si no existe correccion indicada. MEDIUM/LOW permanecen visibles; el pipeline no afirma ausencia de todo riesgo.

## Publicacion e identidad

Imagen: `ghcr.io/mpguevara/devsu-demo-devops-java:ccf1adc4afed257e2c7bb7a7a4005c144f742a9c`.

Digest: `sha256:076d2d01eec70917a72a3a7f9f5f8f1f58ed78e291adde697ea79c38cac7b707`.

[publication.json](publication.json) y `ghcr-push.log` proceden del job de publicacion. [ghcr-anonymous-check.json](ghcr-anonymous-check.json) confirma una consulta anonima del manifiesto: estado 200 y mismo digest, sin conservar token ni cambiar visibilidad. Esta consulta de metadata no constituye un pull completo de capas.

[image-identity-check.json](image-identity-check.json) compara los IDs registrados en los jobs de construccion y Kubernetes: ambos `sha256:c97584f1f5e8b21491018675ecdc567fad4312984939d7088dfe6e59457642f1`. El pipeline transfiere `docker save` con SHA256 validado; el cluster carga esa imagen. No se afirma un pull desde GHCR dentro de kind ni igualdad de bytes con el build nativo Windows.

## Validacion Kubernetes

[kubernetes-results.json](kubernetes/kubernetes-evidence/kubernetes-results.json) conserva 30 comprobaciones aprobadas: pods Ready y UID 10001, escritura en un pod y lectura desde otro, Ingress con `Host: devsu.local`, sustitucion del pod Java, reinicio del pod PostgreSQL con mismo PVC y datos, recuperacion de readiness y HPA bajo carga HTTP real. No hubo errores de limpieza. [hpa-history.json](kubernetes/kubernetes-evidence/hpa-history.json) registra 2 replicas Ready al inicio y 4 al final.

Los dieciseis trabajadores informaron 21.418 peticiones exitosas y 0 fallidas. La prueba completa transcurrio entre 00:56:32 y 00:58:04 UTC; el Job de carga se detuvo al observar escalamiento y nuevos pods Ready, sin afirmar 300 segundos completos ni una tasa calculada desde un tiempo supuesto. Las advertencias transitorias de arranque y metricas quedan en los logs.

El cluster es efimero y la API permanece privada; no hay endpoint publico. Esta evidencia no demuestra disponibilidad continua, alta disponibilidad de PostgreSQL ni recuperacion ante perdida del volumen. No se incluye el artifact pesado de imagen en el repositorio ni en el ZIP del codigo.
