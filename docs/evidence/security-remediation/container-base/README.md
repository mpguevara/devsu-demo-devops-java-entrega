# Revisión de base de contenedor durante la remediación

Se consultaron las fuentes oficiales y el registro real el 23 de octubre de 2026. Esta revisión no ejecutó Maven, Docker build, contenedores ni otro análisis de vulnerabilidades; esas ejecuciones se conservan por separado. El Dockerfile no necesitó cambios en esta revisión.

## Versión disponible y decisión

La API oficial Adoptium y el release de GitHub informaron **Temurin 17.0.21+9**, publicado el 22 de octubre. Se conservaron versión, fecha y checksum de su archivo Linux en [adoptium-current-java17.json](adoptium-current-java17.json); no se descargó ese binario. [Release oficial](https://github.com/adoptium/temurin17-binaries/releases/tag/jdk-17.0.21%2B9).

En esa misma consulta, Docker Hub aún no publicaba tags `17.0.21`: la búsqueda devolvió cero y los cuatro manifiestos explícitos JDK/JRE Noble/Jammy consultados devolvieron HTTP 404. Los tags flotantes `17-jdk-noble` y `17-jre-noble` todavía apuntaban a **17.0.20.1+1**. [Disponibilidad observada](java17-new-tag-availability.json), [índices, manifiestos, configuración y revisión fuente](docker-published-java17.json).

Se mantuvieron las referencias ya fijadas, que coinciden exactamente con las imágenes oficiales publicadas consultadas:

| Etapa | Referencia conservada |
| --- | --- |
| Constructor | `eclipse-temurin:17.0.20.1_1-jdk-noble@sha256:fdae60b4aee31b7228cd10fa883141fe8da67b59ba4d6292af47ccf8e5fd59d2` |
| Runtime | `eclipse-temurin:17.0.20.1_1-jre-noble@sha256:07fa0356cf354c5252947575f42ed42aa6fd921f36438b7bc77ad81c31c537dd` |

La decisión conserva Java 17.0.20.1+1 también en el entorno nativo y CI para mantener la misma herramienta validada. **No es el último parche Temurin upstream:** hay un desfase real de publicación de las imágenes oficiales. No se inventó un digest, no se cambió a una etiqueta flotante y no se introdujo `apt upgrade` ni una instalación manual adicional del JDK. Un futuro cambio a 17.0.21 requerirá consultar sus manifiestos publicados y repetir la validación.

## Compatibilidad con el empaquetado Boot 4

[Spring Boot 4.1.2](https://docs.spring.io/spring-boot/system-requirements.html) declara Java 17 como mínimo, Maven 3.6.3 o posterior y Spring Framework 7.0.10 o posterior. El proyecto conserva Java 17 y Maven Wrapper 3.8.7. El [plugin de empaquetado](https://docs.spring.io/spring-boot/maven-plugin/packaging.html) mantiene `repackage` y la ejecución mediante `java -jar`; no se usa una clase de launcher codificada en el Dockerfile.

Los [14 controles estáticos](static-review.json) confirmaron pins, dos etapas JDK/JRE, nombre esperado `demo-0.0.1.jar`, copia de `config/` para PMD, usuario/grupo 10001, healthcheck configurable y `curl` en la fuente oficial de la base JRE fijada. El POM conserva la propiedad separada de JaCoCo, por lo que el argumento de memoria del Dockerfile no reemplaza el agente de cobertura. También conserva la normalización de timestamps. Estos mecanismos no demuestran por sí solos identidad de bytes del nuevo JAR ni aprobación de sus pruebas; la compilación, el runtime y el escaneo deben comprobarse después.

Las restricciones `readOnlyRootFilesystem`, capabilities, seccomp y `/tmp` permanecen en los manifiestos Kubernetes y no se modificaron. El usuario sí está definido en la imagen. No se cambiaron rutas HTTP, campos de API ni credenciales desde esta revisión.

## Alcance de los hallazgos previos

El [Trivy JSON previo](../../pipeline/remote-run-40044688944/security/trivy-image.json) contiene **0 CRITICAL y 0 HIGH en paquetes Ubuntu**, y **9 CRITICAL y 40 HIGH en bibliotecas JAR**. La remediación de esas bibliotecas corresponde al POM y sus dependencias, no a inventar un parche de la base. Mantener estas bases no equivale a certificar ausencia de vulnerabilidades en la JVM o en todo el sistema: describe únicamente lo detectado por aquel escaneo, con su fecha y cobertura. La conclusión de remediación requiere el nuevo escaneo de la imagen resultante.
