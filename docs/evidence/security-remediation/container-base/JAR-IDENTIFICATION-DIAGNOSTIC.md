Este diagnóstico inspeccionó en memoria `target/demo-0.0.1.jar`, SHA-256 `7a31462fbc2709e493d7bc0658c464f9eebeaee89a7a6f39ccb0689b6d02632c`. No ejecutó Trivy, Maven ni Docker ni extrajo archivos. Los datos completos, hashes y fuentes están en [jar-identification-diagnostic.json](jar-identification-diagnostic.json).

| Observación real | Cantidad |
| --- | ---: |
| JAR en `BOOT-INF/lib` | 98 |
| Registros Java del informe Trivy del run `40046900827` | 62 |
| Rutas de esos JAR con al menos un registro Trivy | 59 |
| Rutas sin registro Trivy | 39 |
| JAR con `pom.properties` | 48 |
| JAR sin `pom.properties` | 50 |
| JAR con SHA-256 idéntico al artefacto de la caché Maven local | 97 |
| JAR restante con SHA-256 idéntico a un recurso del empaquetador Boot | 1 |

Los 62 registros no equivalen a 62 JAR anidados: ModelMapper aporta tres registros para una ruta y existe un registro de la aplicación exterior. Las 39 rutas ausentes corresponden a Spring Framework, Spring Boot y Micrometer; ninguna contiene `pom.properties`.

En los metadatos observados, `spring-core` tiene nombre y versión pero carece de identificador Maven de grupo. Boot tiene títulos como `Spring Boot AutoConfigure`, versión y tampoco grupo. Micrometer tiene `Implementation-Title=io.micrometer#micrometer-core;1.17.2` y `Bundle-SymbolicName=micrometer-core`, que no constituyen directamente su GAV Maven.

El [parser fijado de Trivy 0.76.1](https://github.com/aquasecurity/trivy/blob/v0.76.1/pkg/dependency/parser/java/jar/parse.go) prefiere `pom.properties`. En su ausencia intenta metadatos del manifest, valida la identidad en Java DB y recurre al hash SHA-1 y a una búsqueda por nombre. Esta observación explica por qué estos archivos dependen de identificación adicional; **no prueba que sus hashes falten de la Java DB utilizada por CI**, cuya consulta exacta no se realizó. La [documentación Java de esa versión](https://github.com/aquasecurity/trivy/blob/v0.76.1/docs/guide/coverage/language/java.md) describe ese mecanismo y marca la búsqueda en Java DB como experimental. [Java DB](https://github.com/aquasecurity/trivy-java-db) contiene identidades y hashes de artefactos, con un propósito diferente al de la base de advisories.

El JAR `spring-boot-jarmode-tools-4.1.2.jar` no fue una dependencia resuelta independiente en la caché: su SHA-256 `a0d9e74c09c81f2c8e096bc856f327605a34df2209e5cf6884351170c6aa3547` coincide exactamente con `META-INF/jarmode/spring-boot-jarmode-tools.jar` dentro de `spring-boot-loader-tools-4.1.2.jar`. Boot [documenta su inclusión por el empaquetador y el parámetro `includeTools`](https://docs.spring.io/spring-boot/maven-plugin/packaging.html). Un inventario basado solo en dependencias del proyecto debe considerar ese archivo adicional o excluir de forma explícita la herramienta si no se utiliza.

El [plugin Maven CycloneDX](https://cyclonedx.github.io/cyclonedx-maven-plugin/makeBom-mojo.html) obtiene las dependencias de Maven y permite seleccionar sus scopes. Su JSON puede aportar GAV, PURL y hashes sin depender del manifest de cada JAR. El [importador CycloneDX de Trivy](https://github.com/aquasecurity/trivy/blob/v0.76.1/pkg/sbom/cyclonedx/unmarshal.go) lee PURL, grupo, nombre, versión y hashes. Esto permite complementar el escaneo de imagen, pero debe verificarse en el resultado real que todos los componentes necesarios fueron ingeridos; [Trivy advierte limitaciones de los SBOM de terceros](https://trivy.dev/docs/latest/guide/target/sbom/).

Este diagnóstico compara el JAR nativo con las rutas del informe de imagen. **No demuestra igualdad de bytes con el JAR Linux de esa imagen.** CI debe vincular los hashes del SBOM con los JAR efectivamente empaquetados en la imagen exacta y comprobar las 14 coordenadas anteriormente vulnerables. Un inventario completo tampoco garantiza que todas las vulnerabilidades posibles existan en las bases consultadas. El resultado defendible será el número real de hallazgos conocidos, con versión de escáner, base y cobertura verificadas.
