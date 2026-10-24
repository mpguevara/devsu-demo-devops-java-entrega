Esta ejecución real utilizó la imagen del commit `81beb47ba4b03f98e407860d94d143a22f2d2771`, publicada por el [run 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809), en el clúster local existente `kind-devsu`.

[kubernetes-results.json](kubernetes-results.json) registra 30 comprobaciones aprobadas y nueve observaciones HTTP. Son verificaciones de despliegue e integración, no 30 pruebas unitarias. Incluyen dos réplicas Ready, ejecución sin privilegios, escritura temporal permitida, lectura de un usuario creado en una réplica desde otra y desde Ingress, sustitución de un pod Java, reinicio de PostgreSQL y conservación del usuario y del PVC.

Antes de esta prueba, [After](../postgres-upgrade/after.json) comprobó mediante una sesión SQL de solo lectura que seguían los dos usuarios anteriores, el mismo PVC y el mismo historial Flyway, con 19 controles aprobados. Por tanto, esa evidencia antecede a los nuevos usuarios sintéticos creados aquí.

La carga del Job `devsu-http-load-d564e790` produjo **7.104 GET correctos y cero fallidos**, según [http-load.log](http-load.log). Se registraron 55,17 segundos entre la finalización del comando de creación del Job y la orden de parada; esto no representa exactamente la duración activa de cada trabajador. El Job se detuvo al observar escalamiento, antes del límite de 300 segundos. Este resultado no es un benchmark de capacidad ni mide percentiles de latencia.

[hpa-history.json](hpa-history.json) muestra una base de dos réplicas actuales, deseadas y Ready. Bajo solicitudes HTTP reales pasó a cuatro deseadas y tres Ready; la última muestra registró 499 % de CPU respecto al request de 100m, no respecto a toda la máquina. No se generó carga artificial mediante bucles de CPU o comandos dentro de la aplicación. [post-load-observation.json](post-load-observation.json) observó después cuatro réplicas Ready de la imagen aprobada.

La ejecución finalizó sin errores de limpieza. La observación posterior confirmó cero Jobs en el namespace propio, cero port-forwards propios y el PVC original `0052b7a3-772c-49b4-984b-4e437fb8bef9` en estado Bound. Se conservaron el clúster y sus datos. El HPA puede reducir réplicas posteriormente según sus métricas y ventana de estabilización; no se forzó un escalamiento manual. No hay endpoint público.

Para repetir la validación sobre el clúster propio desplegado:

```powershell
./scripts/Test-Kubernetes.ps1 -EvidenceDirectory target/kubernetes-reproduction
```

Cada repetición crea un nuevo usuario sintético y reemplaza pods propios como parte de la prueba. La [secuencia local de descarga y despliegue](../local-image/README.md) documenta el fallo de importación y la alternativa realmente utilizada, conservando los intentos fallidos.
