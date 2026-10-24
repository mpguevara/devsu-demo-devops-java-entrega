# Calidad: pruebas, análisis estático y cobertura

## Qué se incorporó

El proyecto conserva Java 17 y Spring Boot 3.0.5. `clean verify` compila, ejecuta pruebas, empaqueta el JAR, genera cobertura y aplica los controles de calidad. Se incorporaron **JaCoCo 0.8.15** y **Maven PMD Plugin 3.28.0**, que incluye PMD **7.17.0**. Se utiliza un solo analizador de código, sin servidor externo ni una plataforma adicional que operar.

JaCoCo incorpora un agente a la JVM de pruebas para medir qué bytecode se ejecuta. PMD analiza el código fuente de producción con un [conjunto explícito de nueve reglas](../config/pmd/ruleset.xml). Detecta imports y código innecesarios, variables sin uso, recursos sin cierre y construcciones que pueden ocultar errores, como `catch` vacío o `return` en `finally`. No se suprimieron hallazgos mediante exclusiones ni se cambiaron los contratos HTTP.

## Medición antes de seleccionar umbrales

Primero se midió la suite existente, sin un control de cobertura que pudiera alterar la medición. Las once pruebas pasaron, con **31/74 líneas cubiertas: 41,89 %**, y **0/62 ramas: 0 %**. La primera integración de PMD falló porque dos nombres de reglas antiguos no existen en PMD 7; se conservó ese log y se corrigieron los nombres antes de analizar el código.

Con reglas válidas y los mismos fuentes Java, PMD encontró **dos violaciones `VariableCanBeInlined` en `UserMapper`**. Ambos métodos almacenaban el resultado del mapeo en una variable usada únicamente para retornarlo. Se sustituyeron esos dos bloques por retornos directos, manteniendo el mismo mapeo, tipos y comportamiento.

Después se añadieron comprobaciones de comportamiento que faltaban. La medición ampliada obtuvo **22 pruebas aprobadas**, **65/72 líneas: 90,28 %**, y **8/62 ramas: 12,90 %**. La disminución de 74 a 72 líneas ejecutables se debe a simplificar los dos retornos del mapper. El servicio principal obtuvo **14/14 líneas y 2/2 ramas: 100 %**. PMD pasó con cero violaciones.

Los contadores proceden de los XML de JaCoCo y Surefire; [el índice de evidencia](evidence/quality/README.md) enlaza las mediciones y los intentos fallidos. La cobertura es una medida de ejecución, no una prueba de que todas las condiciones de negocio o de infraestructura sean correctas.

## Pruebas de comportamiento

| Grupo | Casos | Alcance |
| --- | --- | --- |
| `UserServiceTest` | 6 | Lista vacía; mapeo y orden de usuarios; consulta existente; ausencia real mediante `Optional.empty()`; alta con ID generado; rechazo de DNI duplicado sin escritura |
| `UserControllerTest` | 9 | Listado; alta 201 y consulta 200; duplicado 400 sin nueva fila; tres entradas inválidas sin persistencia; ausencia 404; ID no numérico 400; Content-Type no soportado 415 |
| `HealthEndpointTest` | 5 | Dos probes 200/UP sin detalles; tres endpoints internos no expuestos |
| `UserRepositoryTest` | 1 | Persistencia y consulta del ID realmente generado |
| `DemoJavaApplicationTests` | 1 | Carga del contexto con el perfil de pruebas |

Las seis pruebas del servicio utilizan `MockitoExtension`, sin `SpringBootTest`, contexto Spring, red ni base de datos. Los repositorios y mapper están simulados para aislar las decisiones del servicio. La prueba de ausencia devuelve `Optional.empty()` en lugar de programar el mock para lanzar de antemano la misma excepción que se intenta comprobar.

Las pruebas de controlador conservan la aplicación Spring real con MockMvc, validación, mapper, servicio y H2 de pruebas. `@Transactional` revierte los cambios al terminar cada caso; no dependen de un ID fijo ni de datos dejados por otra prueba. No representan llamadas a un puerto TCP ni prueban PostgreSQL. La integración PostgreSQL, contenedores y Kubernetes requiere sus verificaciones correspondientes.

## Controles que bloquean la construcción

Después de observar los resultados se fijaron estos límites en `jacoco:check`:

| Elemento | Métrica | Mínimo |
| --- | --- | --- |
| Aplicación completa, sin exclusiones de clases | Líneas cubiertas | 85 % |
| `UserServiceImpl` | Líneas cubiertas | 100 % |
| `UserServiceImpl` | Ramas cubiertas | 100 % |

El límite global conserva una parte amplia de los caminos ya probados, con margen frente al 90,28 % medido para cambios legítimos. El servicio tiene solo catorce líneas ejecutables y dos ramas, y contiene las decisiones de consulta y duplicados; mantener su cobertura completa es verificable con pocos casos útiles. Estos porcentajes son decisiones del ejercicio basadas en esa medición, no estándares universales ni un indicador de seguridad.

No se impuso un porcentaje global de ramas equivalente al del servicio: los contadores globales incluyen código generado por Lombok en entidades y DTO, especialmente `equals` y `hashCode`. Se conserva su cobertura visible de **12,90 %**, sin excluir clases para aparentar un porcentaje mayor ni añadir pruebas artificiales de métodos generados. Quedan siete líneas sin cubrir: constructores de excepción sin mensaje, el punto de entrada `main` y el camino del handler para una violación directa de integridad de datos. Es una limitación explícita de esta suite.

PMD bloquea `verify` si aparece una violación de cualquiera de las reglas seleccionadas. El alcance es `src/main/java`; las pruebas no se incluyen en PMD. Un resultado cero se refiere a ese conjunto y alcance, y no equivale a una auditoría de seguridad ni a un escaneo de dependencias.

## Repetir la verificación

Desde la raíz del proyecto en PowerShell 7:

```powershell
. .\scripts\Use-Java17.ps1
$env:MAVEN_OPTS = '-Xmx384m -Dfile.encoding=UTF-8'
.\mvnw.cmd -B -ntp clean verify '-DargLine=-Xmx384m'
```

En un entorno Linux con JDK 17:

```bash
export MAVEN_OPTS='-Xmx384m -Dfile.encoding=UTF-8'
./mvnw -B -ntp clean verify '-DargLine=-Xmx384m'
```

El wrapper fija Maven 3.8.7. `verify` incluye las fases de compilación y pruebas; ejecutar `compile`, `test` y después `verify` como comandos consecutivos repetiría trabajo y pruebas. Para ejecutar solo los controles de fuente, puede utilizarse `./mvnw -B -ntp pmd:check`; no genera cobertura ni sustituye la verificación completa.

Surefire configura `@{jacocoArgLine} ${argLine}`: el agente preparado por JaCoCo se conserva mediante evaluación tardía, y `argLine` contiene el límite de heap u otros argumentos de pruebas. Por eso el comando heredado `-DargLine=-Xmx384m` no elimina el agente. La medición se comprobó con ese mismo argumento. No utilizar `forkCount=0`, `skipTests` ni opciones de omisión para presentar un resultado final de calidad.

| Archivo generado | Uso |
| --- | --- |
| `target/site/jacoco/index.html` | Navegación visual de cobertura por paquete, clase y línea |
| `target/site/jacoco/jacoco.xml` | Contadores verificables y consumo desde CI |
| `target/site/jacoco/jacoco.csv` | Resumen tabular de cobertura |
| `target/jacoco.exec` | Datos binarios capturados por el agente |
| `target/pmd.xml` | Hallazgos de PMD en formato legible por herramientas |
| `target/reports/pmd.html` | Reporte de análisis estático para lectura humana |
| `target/surefire-reports/` | Resultados individuales de pruebas en XML y texto |

`clean` elimina `target`. Los reportes que sirvan de evidencia deben copiarse antes de otra construcción o conservarse como artefactos del pipeline. El repositorio mantiene XML, resúmenes, comandos y logs reales en `docs/evidence/quality`; no necesita versionar todos los HTML generados.

## Problemas encontrados y límites

- El primer ruleset utilizaba `UnusedImports` y `EmptyFinallyBlock`, que PMD 7.17.0 rechazó. Se corrigieron a las reglas de esa versión, y se reemplazó la referencia de una regla obsoleta por `VariableCanBeInlined`. La primera compilación tiene exit code 1 aunque sus once pruebas y la medición JaCoCo sí finalizaron.
- El primer análisis válido encontró dos retornos simplificables en el mapper y falló la construcción. Se corrigieron los dos hallazgos, sin deshabilitar la regla.
- PMD muestra una advertencia de navegación porque no hay URL del proyecto padre para su reporte HTML. No es una violación de las reglas y no impide generar el reporte.
- Surefire 2.22.2, gestionado por el POM padre original, generó en Windows un dump del comprobador de proceso padre (`Cannot use PPID ... Going to use NOOP events`). Las 22 pruebas y el proceso Maven terminaron correctamente; se conserva el dump sin presentarlo como un fallo de la aplicación. La detección del proceso padre es una limitación observada de esta herramienta en Windows, separada de los resultados de las pruebas.
- H2 facilita una suite reproducible sin infraestructura externa, pero no sustituye las pruebas de migraciones o concurrencia sobre PostgreSQL.
- Estos controles no analizan vulnerabilidades de imágenes o librerías, no demuestran carga soportada y no verifican despliegues. Esos resultados deben proceder de sus herramientas y entornos reales.

## Referencias primarias

- [JaCoCo: versiones publicadas](https://www.jacoco.org/jacoco/trunk/doc/changes.html), [prepare-agent y evaluación tardía de argLine](https://www.jacoco.org/jacoco/trunk/doc/prepare-agent-mojo.html) y [límites de check](https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html).
- [Apache Maven PMD Plugin: check](https://maven.apache.org/plugins/maven-pmd-plugin/check-mojo.html) y [versión PMD predeterminada de 3.28.0](https://maven.apache.org/plugins/maven-pmd-plugin/examples/upgrading-PMD-at-runtime.html).
- [PMD 7.17.0: reglas de estilo](https://docs.pmd-code.org/pmd-doc-7.17.0/pmd_rules_java_codestyle.html) y [reglas de errores](https://docs.pmd-code.org/pmd-doc-7.17.0/pmd_rules_java_errorprone.html).

## Preguntas de defensa

1. ¿Qué diferencia hay entre un test unitario del servicio con Mockito y un test MockMvc que usa servicio, mapper y H2 reales?
2. ¿Por qué `Optional.empty()` comprueba mejor la ausencia de usuario que un mock que ya lanza la excepción esperada?
3. ¿Cómo pueden coexistir 90,28 % de líneas y 12,90 % de ramas? ¿Qué aporta mirar además las dos ramas del servicio?
4. ¿Qué ejecuta `verify`, qué resultados bloquean la construcción y por qué `-DargLine` necesita conservar el agente JaCoCo?
5. ¿Qué encontraron realmente las reglas PMD, cómo se corrigió y qué no puede concluirse a partir de cero violaciones?
