# Saneamiento de metadatos locales en reportes archivados

Se sustituyó el valor completo de la propiedad `java.library.path` por `[REDACTED_LOCAL_ENVIRONMENT_PATHS]` en 25 copias XML de Surefire. Ese valor contenía rutas de instalación y búsqueda del entorno personal. Se aplica un marcador neutral a toda la propiedad, sin seleccionar herramientas individuales ni sustituir las rutas por un entorno ficticio.

La operación se realizó después de las ejecuciones originales y **no cambia ni vuelve a ejecutar las pruebas**. No se modificaron código, POM, Dockerfile, workflow, manifiestos Kubernetes, JaCoCo, PMD, logs ni resúmenes de resultados.

## Alcance y comprobación real

| Copias XML afectadas | Cantidad |
|---|---:|
| `quality/baseline/surefire-reports` | 5 |
| `quality/improved-measurement/surefire-reports` | 5 |
| `quality/final/surefire-reports` | 5 |
| `security-remediation/native/attempt-1/surefire-reports` | 5 |
| `security-remediation/native/attempt-2/surefire-reports` | 5 |

El [manifiesto generado durante la operación](manifest.json) registra la fecha, revisión original, ruta de cada archivo, hash del blob Git original y SHA-256 antes/después. Para cada XML se comprobó:

1. El archivo de trabajo coincidía con el blob de la revisión original antes de modificarlo.
2. Existía exactamente una propiedad `java.library.path`; se sustituyó solo su valor, conservando codificación y finales de línea.
3. Al retirar ese valor de ambas versiones, **todo el contenido restante es idéntico**, comprobado por SHA-256. Esto incluye todos los demás metadatos, atributos, timestamps, tiempos, casos, errores y salida de aplicación.
4. Los contadores de suite y el número de casos son iguales. También coinciden los hashes de los nodos `testcase`, incluidos sus resultados y tiempos.
5. El hash de cada archivo escrito coincide con el previsto para la versión saneada.

Los 25 archivos cambiaron una sola línea cada uno. El manifiesto conserva las mediciones históricas tal como eran, incluidas las once pruebas de la línea base de calidad y las veintidós de cada ejecución posterior; no presenta su suma como una nueva ejecución ni altera los porcentajes de cobertura.

Los XML históricos de calidad usan CRLF, conservado intencionalmente. El primer `git diff --check` señaló esos retornos como whitespace; la comprobación de formato se repite aceptando CR al final de línea, sin normalizar los archivos: `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check`.

Los manifiestos `source.sha256.json` de esas carpetas describen los archivos de entrada de los builds, no estas copias XML. Los reportes y manifiestos de las ejecuciones remotas no se modificaron. El ZIP final y su manifiesto externo se regeneran después de confirmar este saneamiento en Git.

## Trazabilidad de los originales

Los originales corresponden a `800bed2550af27fc56ca143d1bf9bc97069db7cf` y continúan disponibles en el historial público. Por ejemplo:

```powershell
git show '800bed2550af27fc56ca143d1bf9bc97069db7cf:docs/evidence/quality/final/surefire-reports/TEST-devsu.devops.demo.service.UserServiceTest.xml'
```

Se añade un commit nuevo de saneamiento documental; no se reescriben commits anteriores ni se afirma que las rutas hayan desaparecido del historial. La versión actual de los XML se identifica como copia con metadatos saneados, no como archivo original byte a byte. El [pipeline real de referencia](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40048321809) sigue siendo la ejecución sobre `81beb47ba4b03f98e407860d94d143a22f2d2771`.
