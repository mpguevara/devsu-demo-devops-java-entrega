# Saneamiento del metadato de rutas en la historia de main

Después del [saneamiento de las copias actuales](../report-metadata-sanitization/README.md), se preparó y verificó una copia de los ocho commits de `main` para sustituir también el valor histórico de `java.library.path` por `[REDACTED_LOCAL_ENVIRONMENT_PATHS]`. La operación no elimina casos, fallos, logs, tiempos ni datos de cobertura, y no pretende modificar la autoría declarada del trabajo.

La fuente de la copia era `e6e4a7778d191066b1909566d088e55fb1660fee`. Antes de modificar la rama activa se creó y verificó un bundle privado, excluido del repositorio y del ZIP por `.gitignore`. No se modificaron otros contextos, clústeres, datos, credenciales ni referencias internas de la aplicación de escritorio.

## Herramienta y alcance

Se utilizó [git-filter-repo v2.47.0](https://github.com/newren/git-filter-repo/releases/tag/v2.47.0), desde el commit oficial `6f79afc8c90c592a3052e6cc53c2ca8907515bca`. SHA-256 del script descargado: `67447413e273fc76809289111748870b6f6072f08b17efe94863a92d810b7d94`.

La transformación sustituyó exclusivamente el valor de la propiedad XML. Se preservaron commits vacíos, orden, padres equivalentes, autores, committers, fechas completas con su zona horaria, codificación y mensajes. Los ocho commits carecían de firmas Git. Solo existía una rama pública, `main`, sin tags ni pull requests abiertos en la comprobación previa; no se publicaron refs privadas ni el bundle de respaldo.

El [mapa producido por la herramienta](commit-map.txt) relaciona los identificadores anteriores con los nuevos. **El contenido de los commits cambia y por eso cambian sus SHA.** La documentación de esta operación se añade después mediante un commit nuevo, con su fecha real.

## Comprobación de la copia candidata

La [verificación binaria de la candidata](candidate-verification.json) se realizó antes de actualizar la rama activa o pública y conserva expresamente ese alcance. Para cada pareja de commits se compararon los objetos originales con los de la copia:

| Comprobación | Resultado medido |
|---|---:|
| Commits conservados con identidad, fechas y mensaje idénticos | 8/8 |
| Versiones históricas de reportes comprobadas | 170 |
| Versiones que requerían sustituir el valor de rutas | 145 |
| Blobs XML distintos que requerían saneamiento | 25 |
| Otros blobs y permisos modificados por la transformación | 0 |
| Rutas objetivo restantes en las versiones comprobadas | 0 |
| Árbol completo de la candidata frente al HEAD inicial ya saneado | Idéntico |
| Nuevas pruebas de aplicación ejecutadas por este saneamiento | 0 |

Las 170 versiones son apariciones de reportes a través de los ocho commits, no nuevas ejecuciones de pruebas. Las 25 apariciones del último commit ya estaban saneadas y no necesitaban cambios. Para cada blob modificado se comprobó la sustitución exacta por bytes y la igualdad de atributos de suite y de los casos `testcase`. La igualdad de los restantes bytes protege también contadores, tiempos, timestamps y salida de aplicación. Se mantuvieron los finales de línea originales.

El árbol final de la candidata es idéntico al de `e6e4a77` antes de añadir esta documentación. Por tanto, la reescritura no cambia la aplicación, POM, Dockerfile, scripts, workflow, Compose, Kubernetes ni los resultados actuales. Los reportes remotos, PMD, JaCoCo, logs y manifiestos de hashes mantienen sus bytes originales.

## Evidencia real y revisiones anteriores

El [pipeline real 40048321809](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) se ejecutó sobre `81beb47ba4b03f98e407860d94d143a22f2d2771`. Ese identificador permanece en sus metadatos, reportes y etiqueta OCI porque describe lo realmente ejecutado. Su correspondencia dentro del historial saneado es `544c143229cacd6241b1527def5c670b29a423d5`; **no se afirma que GitHub Actions se ejecutara sobre esta nueva revisión**.

Se conserva el digest publicado de la imagen y sus etiquetas, sin construir ni publicar otra imagen para cambiar retrospectivamente esa evidencia. La aplicación y automatización son idénticas a las validadas; las copias archivadas de reportes locales tienen el metadato indicado saneado.

El manifiesto del primer saneamiento sigue siendo un registro histórico, con sus SHA anteriores y `gitHistoryRewritten=false` tal como correspondía en aquel momento. Esta segunda operación se documenta aparte para no alterar ese registro. El ZIP de entrega y su manifiesto externo se regeneran desde el HEAD final de la rama saneada.

## Publicación y límites

La actualización pública afecta únicamente a `refs/heads/main`, utilizando un lease con el SHA público esperado `e6e4a7778d191066b1909566d088e55fb1660fee`. Si otra persona modifica la rama durante la preparación, la publicación debe detenerse en lugar de descartar ese cambio. Se comprueba después el HEAD remoto y el contenido de un clon nuevo.

El saneamiento no equivale a una purga de toda copia existente. [GitHub documenta](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) que un force-push puede dejar objetos accesibles por SHA, vistas en caché, clones o referencias externas. GitHub Support no garantiza eliminar datos no sensibles. Los SHA históricos se conservan donde identifican ejecuciones reales; no se promete que dejen de ser consultables por otros medios.

Para evitar reintroducir la historia anterior, otras copias deben adoptar la historia saneada sin fusionar los commits antiguos. Antes de versionar nuevos reportes locales, se deben revisar los metadatos de rutas y documentar cualquier saneamiento con la misma separación entre resultados reales y metadatos del entorno.
