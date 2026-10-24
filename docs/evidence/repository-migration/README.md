# Migración al repositorio de entrega

El [repositorio público de entrega](https://github.com/mpguevara/devsu-demo-devops-java-entrega) se creó el 23 de octubre de 2026, hora de El Salvador, con el historial saneado. Es un repositorio independiente, no un fork. El [repositorio anterior](https://github.com/mpguevara/devsu-demo-devops-java) se conserva con su HEAD `b28d8c4acf9cb2479e992454c7d70c03a90d3067`; no se elimina ni se publica allí esta migración.

[creation.json](creation.json) registra las comprobaciones de creación, rama predeterminada `main`, Actions habilitado y conservación del repositorio anterior. La consulta de un blob original previamente identificado devolvió HTTP 404 en el repositorio nuevo. Es una comprobación de ese objeto, no una garantía sobre toda copia o retención externa.

## Inicio de la nueva ejecución

El primer `workflow_dispatch` devolvió `HTTP 404: workflow ci.yml not found on the default branch`. La comprobación posterior encontró el archivo de workflow en `main` con HTTP 200, pero cero workflows registrados. Se conserva esa observación sin presentar el intento como una ejecución de CI ni atribuir una causa interna no demostrada.

La siguiente acción es un commit real de documentación con los enlaces del nuevo repositorio, sin instrucción de omisión de CI, seguido de push a `main`. No se cambia la lógica del workflow, la aplicación ni sus dependencias para ese arranque. Los resultados del nuevo pipeline se incorporarán después de ejecutarlo realmente.

## Procedencia de resultados

El [consolidado anterior](previous-final-verification.json) es una copia exacta del estado verificado antes de esta migración. Los reportes de `remote-run-40048321809` y las ejecuciones previas pertenecen al repositorio anterior y conservan sus URLs, SHA, imagen y digest originales.

El nuevo workflow utiliza `GITHUB_REPOSITORY` y `GITHUB_SHA` para las etiquetas OCI y el destino GHCR. La nueva publicación corresponderá a `ghcr.io/mpguevara/devsu-demo-devops-java-entrega:<SHA de la ejecución>`. No se atribuirán los resultados anteriores a esa imagen ni se modificarán retroactivamente sus evidencias.

Las pruebas locales de la imagen anterior, incluidos los usuarios y el PVC conservados, mantienen su alcance histórico. Esta migración se valida mediante el clúster efímero del pipeline; no modifica el clúster local existente.
