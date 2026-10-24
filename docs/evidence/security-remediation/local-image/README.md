La imagen publicada por el [run 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) se descargó y desplegó realmente en el clúster local existente. Commit: `81beb47ba4b03f98e407860d94d143a22f2d2771`.

- Manifest del registro: `sha256:5186197365985f9249e005d82a47b6b7dc3abd7c88b89de6a2dbb45686d7b56e`.
- Configuración OCI: `sha256:ad99ff140855abbda19fdde585820eaf747b31aba84670fa6d155020bbbb9713`.
- Etiqueta local y Kubernetes: `devsu-demo-java:81beb47ba4b03f98e407860d94d143a22f2d2771`.
- Usuario observado: `10001:10001`; etiquetas OCI de origen y revisión coincidentes.

El primer control [pull-inspect.json](pull-inspect.json) falló porque suponía que `docker image inspect.Id` siempre era el hash de configuración. En este equipo, `Id` y `Descriptor.digest` devolvieron el digest del manifest; el artefacto `image.json` de CI contiene el de configuración. La causa de esa presentación diferente no se demostró. La descarga sí terminó con código cero. [pull-inspect-resolved.json](pull-inspect-resolved.json) conserva 14 comprobaciones aprobadas: SHA-256 de los cuerpos originales de manifest y configuración, vínculo con CI, RepoDigest local, etiquetas, usuario y nueve DiffIDs. Se guardó el [manifest verificado](registry-manifest-verified.json), no el blob completo de configuración. El `docker pull` usó la configuración normal del cliente; esta operación no prueba acceso anónimo.

El primer [despliegue](../local-deploy/deploy-results.json) falló en `kind load docker-image`: el importador informó `content digest sha256:ad99ff…: not found`. La aplicación anterior permaneció con dos réplicas Ready y no se aplicó todavía la nueva imagen. Se conservan ese resultado y su log; no se reinició Docker ni se borraron clúster, PVC, Secret o datos.

La alternativa utilizada fue descargar el mismo digest directamente en el containerd del nodo propio, con TLS normal y sin suministrar credenciales. El primer intento de limitar descargas mediante `--max-concurrent-downloads` fue rechazado porque exigía `--local`; [node-pull.json](node-pull.json) preserva el error. El [segundo intento](node-pull-attempt-2.json), sin esa opción, terminó con código cero. [node-image-identity.json](node-image-identity.json) registra seis comprobaciones aprobadas de manifest, configuración, nueve descriptores de capas y etiqueta del nodo.

Se conservan dos consultas auxiliares fallidas: [node-image-verified.json](node-image-verified.json) esperaba JSON donde `ctr images inspect` imprime texto; [node-image-verified-attempt-2.json](node-image-verified-attempt-2.json) intentó leer todos los blobs comprimidos y encontró uno no retenido. El nodo tiene `discard_unpacked_layers = true`. Estos errores de comprobación se distinguen del fallo real de importación de kind. La comprobación final no afirma haber recalculado todos los blobs de capas ni atribuye corrupción a su descarte.

Secuencia utilizada para transferir la imagen y continuar el despliegue, en PowerShell 7 y sobre el nodo propio `devsu-control-plane`:

```powershell
$ref = 'ghcr.io/mpguevara/devsu-demo-devops-java@sha256:5186197365985f9249e005d82a47b6b7dc3abd7c88b89de6a2dbb45686d7b56e'
$image = 'devsu-demo-java:81beb47ba4b03f98e407860d94d143a22f2d2771'
docker pull $ref
docker tag $ref $image
docker exec devsu-control-plane ctr --namespace k8s.io images pull --platform linux/amd64 $ref
docker exec devsu-control-plane ctr --namespace k8s.io images tag $ref "docker.io/library/$image"
./scripts/Deploy-Kubernetes.ps1 -Image $image -AllowLowMemory -EvidenceDirectory target/local-deploy-reproduction
```

La creación de la etiqueta del nodo se realiza una vez; si ya existe, debe comprobarse que apunta al mismo digest. Aquí se omitió `-LoadImage` en el segundo despliegue porque la imagen ya estaba en el nodo. [local-deploy-attempt-2](../local-deploy-attempt-2/deploy-results.json) terminó correctamente. CI emplea su propio procedimiento de archivo de imagen; la transferencia local comprobada fue el pull directo del registro al nodo.

Antes de crear usuarios nuevos se ejecutó `Test-DependencyUpgrade.ps1 -Mode After -ExpectedImage $image`. [After](../postgres-upgrade/after.json) aprobó 19 comprobaciones: conservó los dos usuarios anteriores, PVC, historial Flyway y hash de V1; ambos pods ya usaban el digest nuevo. Luego se ejecutó `Test-Kubernetes.ps1`, con [30 comprobaciones aprobadas](../local-kubernetes/kubernetes-results.json), lectura entre réplicas, Ingress, recuperación y carga HTTP con HPA. El [estado posterior](../local-kubernetes/post-load-observation.json) muestra cuatro pods Ready, cero Jobs, cero port-forwards propios y el PVC original Bound. El clúster y sus datos quedaron conservados, sin endpoint público.
