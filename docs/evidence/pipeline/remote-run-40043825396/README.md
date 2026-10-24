# Primera ejecucion real: 40043825396

- [Ejecucion de GitHub Actions](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40043825396).
- Revision ejecutada: `f5a65da4592c6d09884513e23df6fa82b3567001`, rama `main`, evento `push`, intento 1.
- Inicio: 24 de octubre de 2026, 00:12:37 UTC. Ultima actualizacion final: 00:21:14 UTC; 8 minutos y 37 segundos. En El Salvador corresponde al 23 de octubre, 18:12:37-18:21:14.
- Conclusion global: **failure**. Esta ejecucion no demuestra una validacion Kubernetes completa.

| Job | Resultado real |
|---|---|
| Compile, test, PMD and coverage | success: 22 pruebas, 0 fallos/errores/omitidas; 65/72 lineas cubiertas, 90,28%; PMD 0 |
| Build and inspect the image | success: imagen construida, usuario 10001:10001 y Trivy ejecutado |
| Publish the verified image to GHCR | success: push y digest conservados en publication.json |
| Deploy and validate private Kubernetes | failure: el despliegue aprobo; el script de validacion fallo antes del primer check |

La cobertura global de ramas reportada es 8/62, 12,90%, sin exclusiones; no se presenta como 90,28%. El porcentaje 90,28% corresponde a LINE. Los umbrales y la cobertura de UserServiceImpl se revisan en el POM y el reporte JaCoCo completo.

## Fallo encontrado

El paso de despliegue concluyo correctamente y conservo los rollouts. El paso de validacion fallo al resolver `kubectl` en Ubuntu: `Get-Command kubectl -CommandType Application` devolvio tres ejecutables (el fijado por el pipeline y los dos del runner). Al obtener todas las propiedades `Source`, el script intento ejecutar una cadena con tres rutas en lugar de una ruta individual.

El mensaje real consta en `kubernetes/kubernetes-evidence/kubernetes-results.json` y `kubernetes-job.log`. No hubo comprobaciones HTTP ni de HPA en esta ejecucion: los arrays `checks`, `http` y `commands` estan vacios. La correccion preparada selecciona `Select-Object -First 1`; su validacion remota corresponde a una nueva revision y una nueva ejecucion, sin sobrescribir este resultado.

Este fallo es distinto del problema de recuperacion de PostgreSQL detectado localmente. El primer CI se detuvo antes de poder probar ese escenario.

## Imagen publicada y acceso anonimo

Imagen: `ghcr.io/mpguevara/devsu-demo-devops-java:f5a65da4592c6d09884513e23df6fa82b3567001`.

Digest publicado:

```text
sha256:7ebe174eafe2718ca861e398b23c745941e01a5007d5b12668c5b8cace9018ad
```

Una comprobacion HTTP separada y anonima obtuvo el manifiesto con estado 200 despues del desafio normal del registry, y verifico el mismo digest. No uso credenciales de GitHub ni modifico la visibilidad. El token anonimo temporal no se conservo. Esta comprobacion valida acceso a metadata del manifiesto; no equivale a haber descargado y ejecutado todas las capas de la imagen.

## Vulnerabilidades

Trivy 0.76.1 completo el escaneo: **121 hallazgos**, **9 CRITICAL**, **40 HIGH**, 58 MEDIUM y 14 LOW. La politica informativa permitio continuar; no se declara una imagen limpia ni preparada para produccion.

En `security/` se conserva el JSON completo, log, resumen, los 49 registros CRITICAL/HIGH en CSV y [prioridades con versiones exactas](security/PRIORIDADES.md). El reporte diferencia presencia de un paquete vulnerable y explotabilidad comprobada; no se ejecutaron exploits.

## Archivos y procedencia

`run-metadata.json` y `jobs.json` proceden de GitHub; `artifacts-metadata.json` conserva nombres, fechas, tamanos y digest de artifacts. Se descargaron solamente los artifacts de calidad, evidencia de imagen/escaneo, publicacion y Kubernetes. El artifact pesado `container-40043825396` no se descargo ni se incluye en el repositorio.

Los archivos copiados conservan resultados reales. `evidence-secret-check.json` registra una revision adicional por patrones de tokens y claves, sin coincidencias. No se copiaron kubeconfigs ni contenidos de Secrets. Los paquetes del pipeline tienen caducidad; esta copia conserva la evidencia seleccionada despues del vencimiento.

El API y el cluster del runner permanecieron privados. La publicacion del repositorio y del manifiesto de imagen no es un endpoint publico de la aplicacion.

