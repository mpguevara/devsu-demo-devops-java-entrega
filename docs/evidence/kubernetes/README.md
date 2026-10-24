# Evidencia Kubernetes

Esta carpeta conserva resultados reales del 23 de octubre de 2026, hora de El Salvador. La infraestructura se ejecuto localmente en Windows/Docker Linux. El kubeconfig y los Secrets quedan fuera del repositorio y de esta evidencia.

## Infraestructura verificada

- [kind-install/kind-install.json](kind-install/kind-install.json): kind 0.33.0 portable instalado fuera del proyecto; SHA-256 fijado y contrastado con el checksum oficial.
- [infrastructure-provenance.json](infrastructure-provenance.json): cinco referencias de imagen comprobadas directamente en sus registros por digest: nodo Kubernetes 1.36.4, PostgreSQL 15.19, Traefik 3.7.16, metrics-server 0.9.0 y BusyBox 1.37.0-musl.
- [deploy-infrastructure-attempt-1/deploy-results.json](deploy-infrastructure-attempt-1/deploy-results.json): creacion del cluster `devsu`, nodo Ready y rollouts Traefik/metrics-server aprobados; `infrastructureOnly=true` y `passed=true`.
- [memoria al iniciar](deploy-infrastructure-attempt-1/memory-preflight.json): 1851 MiB libres en Windows. Se utilizo `-AllowLowMemory` de manera explicita y se limito el nodo Docker a 4 GiB y cuatro CPU. No se cerraron aplicaciones del usuario.
- [kind-create.log](deploy-infrastructure-attempt-1/kind-create.log): salida real de creacion. El kubeconfig exclusivo se guardo en el perfil del usuario, fuera del repo.

El motor Docker no estaba iniciado al comenzar esta etapa. La recuperacion e incidencias reales del motor se registran por separado en [environment-20261023](../environment-20261023/). No se borro ni restablecio la instalacion Docker.

## Resultado final local

El [segundo despliegue de aplicacion](deploy-application-attempt-2/deploy-results.json) termino aprobado. La [segunda verificacion runtime](runtime-attempt-2/kubernetes-results.json) termino con `passed=true`, **30 comprobaciones aprobadas**, `scaledUnderRealHttpLoad=true` y ningun error de limpieza. No hay endpoint publico.

| Verificacion | Resultado real | Evidencia |
| --- | --- | --- |
| Dos replicas Java | Dos pods Ready al iniciar; UID 10001 y `/tmp` escribible | [resultado](runtime-attempt-2/kubernetes-results.json), [Deployment efectivo](runtime-attempt-2/app-deployment.json) |
| Datos compartidos | Pod A creo usuario ID 2; B consulto los mismos ID, DNI y nombre | Array `http` y comprobaciones del [resultado](runtime-attempt-2/kubernetes-results.json) |
| Ingress local | GET por Traefik con `Host: devsu.local`, HTTP 200 | Mismo array `http`; puertos locales 18080/18081/18082 |
| Reemplazo Java | Controlador creo nuevo pod y el usuario siguio accesible | [eliminacion del pod propio](runtime-attempt-2/app-pod-delete.log), [resultado](runtime-attempt-2/kubernetes-results.json) |
| Reemplazo PostgreSQL | Pod nuevo Ready; mismo UID del PVC y mismo usuario | [eliminacion del pod propio](runtime-attempt-2/postgres-pod-delete.log), tres sondeos de recuperacion 200/UP y GET 200 |
| HPA | Linea base 2/2 Ready, evento de aumento a cuatro por CPU y mas de dos Ready durante carga | [historial real](runtime-attempt-2/hpa-history.json), [describe HPA](runtime-attempt-2/hpa-describe.log) |
| Estado al final de carga | Deployment 4/4 disponible, cuatro pods 1/1 Ready | [recursos finales](runtime-attempt-2/resources-final.log) |
| Carga HTTP | 16 trabajadores: 7382 GET exitosos y cero fallidos en sus contadores | [log del Job](runtime-attempt-2/http-load.log), [metricas observadas](runtime-attempt-2/pod-metrics.log) |
| Limpieza de prueba | Job propio eliminado; procesos port-forward terminados; cluster y PVC conservados | [limpieza Job](runtime-attempt-2/load-job-cleanup.log), `cleanupErrors=[]` |

Las 30 comprobaciones son aserciones de integracion y estado; no son 30 pruebas unitarias ni 30 solicitudes HTTP diferentes. El resultado conserva nueve peticiones/sondeos HTTP detallados, ademas de los contadores agregados de los trabajadores de carga.

El Job se creo a las 18:21:29 y se envio su marcador de parada a las 18:22:45, hora de El Salvador: aproximadamente 77 segundos entre esas operaciones, incluyendo su arranque. El mensaje inicial del Job anuncia un maximo de 300 segundos; la prueba lo interrumpio al observar escalamiento. No se ejecutaron 300 segundos completos ni se midieron percentiles de latencia. Los contadores de cero fallos describen ese ensayo acotado; no son una garantia de disponibilidad ni un benchmark de produccion.

El historial de HPA parte de dos replicas Ready con CPU media del 6 % del request y llega a cuatro replicas deseadas, con tres Ready en su ultimo sondeo. El archivo de recursos tomado segundos despues confirma cuatro Ready. El evento `SuccessfulRescale` indica `cpu resource utilization ... above target`; no se ejecuto `kubectl scale` para fabricar ese aumento. Los avisos iniciales de metricas ausentes corresponden al arranque y se conservaron.

Los sondeos posteriores sin carga conservan la reduccion natural: primero [tres replicas](post-load-observation.json) y despues [dos replicas actuales, deseadas y Ready](post-load-final-observation.json). No representan otra ejecucion de la suite ni modifican el HPA. La [comprobacion posterior de limpieza](cleanup-verification.json) encontro cero Jobs de carga propios y cero procesos port-forward propios, con el PVC original todavia Bound.

El [resumen consolidado](verification-summary.json) extrae los resultados de los archivos anteriores y registra huellas de los manifiestos y scripts al consolidar. No vuelve a ejecutar pruebas ni convierte un intento fallido en aprobado. La correccion especifica de resolucion del ejecutable en Linux tiene su validacion remota documentada por separado.

## Intentos de aplicacion conservados

El [primer despliegue](deploy-application-attempt-1/deploy-results.json) aprobo PostgreSQL y dos pods Java Ready. El [primer intento runtime](runtime-attempt-1/kubernetes-results.json) comprobo lectura entre pods, Ingress, reemplazo de pod Java y permanencia del UID del PVC, pero **fallo** despues de reemplazar PostgreSQL: el GET del usuario devolvio HTTP 500. El [log de recuperacion](runtime-attempt-1/app-recovery.log) contiene conexiones cerradas y `UnknownHostException: postgres`. Ese resultado mantiene `passed=false`; sus procesos port-forward se limpiaron y no se elimino el PVC.

La configuracion inicial hacia que Java usara el servicio headless de PostgreSQL. Al faltar el unico endpoint durante el reemplazo, su nombre podia dejar de resolver. Se agrego un servicio de clientes ClusterIP separado y se actualizo la URL JDBC mediante ConfigMap con rollout por hash de configuracion. Se conservo el servicio headless, StatefulSet, Secret y PVC. La prueba se ajusto para esperar recuperacion estable por HTTP, sin repetir POST ni afirmar disponibilidad continua. Las ejecuciones posteriores se guardan en carpetas distintas.

La primera ejecucion CI encontro ademas varias rutas `kubectl` en Ubuntu. El verificador asignaba todas las rutas `.Source` al ejecutable. Se corrigio seleccionando explicitamente la primera aplicacion resuelta por `Get-Command`; los instaladores y el despliegue no utilizan esa conversion multiple. La evidencia remota y el resultado de su siguiente ejecucion se conservan en [pipeline](../pipeline/), separados de las pruebas locales.

La guia de comandos, decisiones y limites esta en [KUBERNETES.md](../../KUBERNETES.md).
