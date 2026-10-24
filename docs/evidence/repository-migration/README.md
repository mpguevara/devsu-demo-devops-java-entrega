# Migración al repositorio de entrega

El [repositorio público de entrega](https://github.com/mpguevara/devsu-demo-devops-java-entrega) se creó el 23 de octubre de 2026, hora de El Salvador, con el historial saneado. Es un repositorio independiente, no un fork. El [repositorio anterior](https://github.com/mpguevara/devsu-demo-devops-java) estuvo conservado con su HEAD `b28d8c4acf9cb2479e992454c7d70c03a90d3067` durante la migración, que no se publicó allí. Su eliminación posterior se documenta más abajo; la URL se mantiene como procedencia histórica y ya no está disponible.

[creation.json](creation.json) registra las comprobaciones de creación, rama predeterminada `main`, Actions habilitado y conservación del repositorio anterior en ese momento. La consulta de un blob original previamente identificado devolvió HTTP 404 en el repositorio nuevo. Es una comprobación de ese objeto, no una garantía sobre toda copia o retención externa.

## Inicio de la nueva ejecución

El primer `workflow_dispatch` devolvió `HTTP 404: workflow ci.yml not found on the default branch`. La comprobación posterior encontró el archivo de workflow en `main` con HTTP 200, pero cero workflows registrados. Se conserva esa observación sin presentar el intento como una ejecución de CI ni atribuir una causa interna no demostrada.

Se publicó el commit real `d3af234b09be0241e0ba339e974572da0b506e3a`, con documentación y enlaces del nuevo repositorio, sin instrucción de omisión de CI. Su push a `main` registró e inició el [run 40060607467](https://github.com/mpguevara/devsu-demo-devops-java-entrega/actions/runs/40060607467). No se cambió la lógica del workflow, la aplicación ni sus dependencias para ese arranque.

La ejecución terminó en `success` con sus cuatro jobs aprobados, de 04:00:28 a 04:09:51 UTC del 24 de octubre; en El Salvador fue el 23 de octubre, de 22:00:28 a 22:09:51. La [evidencia nueva](../pipeline/remote-run-40060607467/README.md) conserva los reportes reales: 22 pruebas Java, PMD 0, líneas 87,93 %, imagen 0 CRITICAL/HIGH, SBOM sin hallazgos y 30 comprobaciones Kubernetes, con 16.736 GET correctos/0 fallidos y HPA de dos a cuatro Ready.

## Procedencia de resultados

El [consolidado anterior](previous-final-verification.json) es una copia exacta del estado verificado antes de esta migración. Los reportes de `remote-run-40048321809` y las ejecuciones previas pertenecen al repositorio anterior y conservan sus URLs, SHA, imagen y digest originales.

El workflow utiliza `GITHUB_REPOSITORY` y `GITHUB_SHA` para las etiquetas OCI y el destino GHCR. La nueva publicación es `ghcr.io/mpguevara/devsu-demo-devops-java-entrega:d3af234b09be0241e0ba339e974572da0b506e3a`, digest `sha256:0eaf1b44fe7dd51fb95df7ba938b398a2f09a902c79a1c541463fe0d5ffe9397`. Los resultados anteriores no se atribuyen a esa imagen ni se modifican retroactivamente sus evidencias.

Las pruebas locales de la imagen anterior, incluidos los usuarios y el PVC conservados, mantienen su alcance histórico. Esta migración se valida mediante el clúster efímero del pipeline; no modifica el clúster local existente.

## Comprobación de la publicación

El manifiesto y la configuración OCI respondieron a consultas anónimas. Se calcularon sus SHA-256 sobre los bytes recibidos y se comprobó su vínculo con el ID de imagen construido, la revisión y la URL del repositorio nuevo. Esta comprobación de metadatos no se presenta como un pull completo de capas.

El primer chequeo auxiliar de identidad falló al convertir a texto el `Content` del manifiesto: PowerShell lo había recibido como `System.Byte[]`. La consulta posterior confirmó que esa conversión producía una representación numérica, no el JSON original. Se resolvió decodificando los bytes como UTF-8 para leer el JSON y calculando el hash sobre el array de bytes original. [registry-metadata-diagnostics.json](registry-metadata-diagnostics.json) conserva el error observado y su resolución; el [chequeo corregido](../pipeline/remote-run-40060607467/ghcr-anonymous-check.json) y los [metadatos OCI](../pipeline/remote-run-40060607467/registry-image-metadata.json) aprobaron. Fue un problema del comprobador posterior, no un fallo del pipeline o de la imagen.

## Entrega y límites

El README y la matriz de entrega apuntan al repositorio y run nuevos. El [consolidado actual](../final-verification.json) separa esta revalidación remota de los ensayos locales históricos. El ZIP se genera después del commit documental final y su manifiesto externo registra ese HEAD real. Los resultados de CI corresponden al commit de ejecución, no al commit posterior que incorpora su documentación.

## Eliminación posterior autorizada

Después de finalizar la migración, el usuario solicitó expresamente eliminar únicamente `mpguevara/devsu-demo-devops-java`, conservando `mpguevara/devsu-demo-devops-java-entrega`. El primer intento mediante CLI devolvió HTTP 403 al requerir el permiso `delete_repo`. La eliminación se completó mediante la interfaz de GitHub, tras verificar la identidad del usuario.

La [verificación de la eliminación](deletion-verification.json), realizada el 23 de octubre de 2026 a las 22:48, hora de El Salvador, confirmó HTTP 404 para el repositorio anterior en consultas autenticada y anónima. El repositorio de entrega siguió público, con HTTP 200 e ID `1431791920`, y el run `40060607467` permaneció en `success`. Estas consultas verifican el estado posterior al borrado; no son una nueva ejecución de pruebas ni de escaneos.

Las URLs del repositorio anterior y de sus ejecuciones ya no son vías de acceso disponibles. Se conservan como procedencia en las [copias versionadas de los resultados anteriores](../pipeline/remote-run-40048321809/README.md), junto con sus SHA, imagen y digest originales. Los registros de creación y validación previa conservan sus hechos históricos, incluido que el repositorio anterior estaba preservado entonces. No se modificaron los resultados ni se atribuyeron ejecuciones a otros commits. Esta operación no acredita la eliminación de copias externas ni de paquetes GHCR antiguos. No existe un endpoint público de la API.

## Preguntas de defensa de esta etapa

1. ¿Por qué ejecutar el pipeline en el nuevo repositorio si el código Java no cambió? ¿Qué permisos e integraciones se volvieron a comprobar?
2. ¿Qué vincula el commit de ejecución con la imagen construida, el digest publicado y la imagen cargada en Kubernetes?
3. ¿Por qué conservar las copias de resultados, las URLs de procedencia y los SHA originales después de eliminar el repositorio anterior, mientras la entrega apunta al nuevo run?
