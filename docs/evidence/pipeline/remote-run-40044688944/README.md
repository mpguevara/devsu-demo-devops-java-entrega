# Segunda ejecucion real: 40044688944

- [Ejecucion de GitHub Actions](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40044688944).
- Revision ejecutada: `2506a339cd878b0c17d9da94caebccbcbfa1660c`, rama `main`, evento `push`, intento 1.
- Inicio: 24 de octubre de 2026, 00:22:54 UTC. Ultima actualizacion final: 00:30:23 UTC; **7 minutos y 29 segundos**. En El Salvador corresponde al 23 de octubre, 18:22:54-18:30:23.
- Conclusion global de GitHub: **success**. Los cuatro jobs concluyeron correctamente.

| Job | Resultado real |
|---|---|
| Compile, test, PMD and coverage | 22 pruebas, 0 fallos/errores/omitidas; 65/72 lineas, 90,28%; PMD 0 |
| Build and inspect the image | Docker build completo, UID/GID de imagen 10001:10001, Trivy completo |
| Publish the verified image to GHCR | Push real y digest conservados |
| Deploy and validate private Kubernetes | Despliegue y **30 comprobaciones aprobadas**, sin errores de limpieza |

El 90,28% corresponde a cobertura LINE. El reporte tambien conserva cobertura global de ramas 8/62, 12,90%, sin exclusiones. Los umbrales del servicio y del proyecto permanecen en el POM; el HTML original puede recuperarse del artifact de calidad.

## Validacion Kubernetes

El archivo [kubernetes-results.json](kubernetes/kubernetes-evidence/kubernetes-results.json) conserva las comprobaciones, respuestas HTTP y comandos reales. Se verifico:

- Al menos dos pods Ready y UID efectivo 10001.
- Ingress con `Host: devsu.local` y readiness `UP`, mediante port-forward en 127.0.0.1.
- Creacion de un usuario en un pod y lectura de los mismos campos desde otro pod y desde Ingress.
- Reemplazo de un pod Java por el controlador, conservando el usuario.
- Reemplazo del pod PostgreSQL, reutilizando el mismo PVC y recuperando readiness estable y los mismos datos.
- HPA con minimo dos y maximo cuatro replicas, metricas disponibles y escalamiento observado durante carga HTTP real.
- Dieciseis trabajadores informaron **18.770 peticiones exitosas y 0 fallidas**. La limpieza de los port-forwards y del Job de carga no produjo errores.

La evidencia temporal del HPA en [hpa-history.json](kubernetes/kubernetes-evidence/hpa-history.json) muestra:

| Hora de El Salvador | Replicas actuales | Deseadas | Ready | CPU media / request |
|---|---:|---:|---:|---:|
| 18:29:21 | 2 | 2 | 2 | 13% |
| 18:29:52 | 2 | 4 | 2 | 269% |
| 18:30:07 | 4 | 4 | 2 | 451% |
| 18:30:18 | 4 | 4 | 4 | 451% |

El porcentaje compara consumo con la solicitud CPU del pod, no con toda la CPU del host. La solicitud es 100m; 451m equivale a 451% de esa solicitud. Los logs conservan lo observado sin convertirlo en un benchmark de produccion.

El Job permite hasta 300 segundos, pero el script lo detiene cuando observa escalamiento y nuevos pods Ready. Por tanto **no se afirma que se hayan ejecutado 300 segundos completos** ni se calcula una tasa de peticiones por segundo a partir de un tiempo supuesto.

## Imagen publicada

Imagen:

```text
ghcr.io/mpguevara/devsu-demo-devops-java:2506a339cd878b0c17d9da94caebccbcbfa1660c
```

Digest del registry:

```text
sha256:866fb924326ec03377b0d190131103ae281c1d31f869b42a185e1a4f9d9b2302
```

[publication.json](publication.json) y `ghcr-push.log` proceden del job de publicacion. Una comprobacion HTTP anonima separada verifico estado 200 del manifiesto y el mismo digest; no se conservo el token anonimo ni se modifico visibilidad. Esa comprobacion es de metadata y no equivale a un pull completo de capas.

[image-identity-check.json](image-identity-check.json) compara el ID registrado por el job de construccion y por el job Kubernetes antes de cargar la imagen en kind: ambos son `sha256:1aa97cf88e961611a5b87881a9aa7cf5c38717e3807ac1c29c2cce15360ea4f1`. El pipeline transfiere un archivo `docker save` y verifica su SHA256 entre jobs. Kubernetes utiliza esa imagen transferida; no se presenta como una prueba de pull desde GHCR dentro del cluster.

## Vulnerabilidades y limites

El segundo escaneo tambien se ejecuto realmente: **121 hallazgos**, **9 CRITICAL**, **40 HIGH**, 58 MEDIUM y 14 LOW. El resultado es informativo y no declara la imagen limpia. Sus archivos originales estan en `security/`; [PRIORIDADES.md](security/PRIORIDADES.md) distingue los paquetes, versiones corregidas reportadas y condiciones que requieren revision. La comparacion entre escaneos se conserva aparte: los dos JSON y logs son independientes.

El cluster es efimero y su API permanece privada. Esta prueba no demuestra disponibilidad continua, alta disponibilidad de PostgreSQL, recuperacion ante perdida del nodo ni backups restaurables. No hay URL publica de la aplicacion.

## Correcciones y trazabilidad

La [primera ejecucion](../remote-run-40043825396/README.md) se conserva con su conclusion fallida. Esta nueva revision corrige la resolucion multiple de kubectl en Linux y tambien incorpora la recuperacion de PostgreSQL probada localmente mediante Service de cliente y espera de disponibilidad estable. El segundo CI confirma la nueva revision; no se rehizo un historial ni se reemplazaron los logs del primero.

`run-metadata.json`, `jobs.json` y `artifacts-metadata.json` proceden de GitHub. Se descargaron solamente calidad, evidencia de imagen/escaneo, publicacion y Kubernetes. El artifact pesado `container-40044688944` no se incluye. La revision desplegada y publicada es la indicada arriba; una actualizacion posterior solo de documentacion no equivale a otra ejecucion de este pipeline.

