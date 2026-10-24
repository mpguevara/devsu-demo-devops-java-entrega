# Migración Java para remediar dependencias vulnerables

## Motivo y alcance

El usuario autorizó corregir todos los hallazgos CRITICAL y HIGH y repetir la validación completa, sin ocultarlos con exclusiones. El [CSV del segundo pipeline original](evidence/pipeline/remote-run-40044688944/security/critical-high.csv) contiene **49 hallazgos Java** en catorce coordenadas Maven. La migración conserva Java 17, los endpoints y las reglas de creación, consulta y duplicados.

La selección se basó en versiones publicadas y fuentes primarias. Para [CVE-2026-47884](https://spring.io/security/cve-2026-47884/), el aviso oficial ofrece Spring Framework **7.0.9** como corrección OSS; las correcciones de ramas anteriores figuran como soporte empresarial. Se eligió una línea Spring Boot que gestiona Framework 7 de forma coherente, evitando mezclar Framework 7 con Boot 3 mediante un override aislado. La distinta severidad que muestran proveedores no se utilizó para descartar el hallazgo ni cambiar el objetivo del escaneo.

## Plataforma seleccionada

Spring Boot **4.1.2** es una versión estable publicada. Sus [requisitos oficiales](https://docs.spring.io/spring-boot/system-requirements.html) admiten Java 17 y Maven 3.6.3 o posterior. Se mantuvieron Temurin **17.0.20.1+1** y Maven Wrapper con **Maven 3.8.7**, usados en la verificación real.

Las versiones siguientes proceden del [BOM publicado 4.1.2](https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-dependencies/4.1.2/spring-boot-dependencies-4.1.2.pom), sin overrides individuales de estas librerías:

| Componente | Versión gestionada y empaquetada |
| --- | --- |
| Spring Framework | 7.0.10 |
| Tomcat embebido | 11.0.27 |
| Jackson preferido por Boot | 3.1.7 |
| Jackson 2 para dependencias que todavía lo necesitan | 2.21.7 |
| Logback | 1.5.38 |
| H2 | 2.4.240 |
| Micrometer | 1.17.2 |
| SnakeYAML | 2.6 |
| Flyway y módulo PostgreSQL | 12.4.0 |
| PostgreSQL JDBC | 42.7.14 |
| Hibernate ORM | 7.4.13.Final |
| Lombok | 1.18.48 |

Springdoc se actualizó de 2.1.0 a **3.1.1**, versión estable que su [documentación oficial](https://springdoc.org/) declara compatible con Boot 4. ModelMapper sigue en 2.4.5: no tenía un hallazgo en la entrada del trabajo y el mapeo se comprobó con las pruebas y la ejecución HTTP. JUnit **6.0.3** y los plugins Compiler **3.15.0** y Surefire **3.5.6** quedan gestionados por el nuevo padre; no se fijó una versión JUnit de la plataforma anterior.

La [lista efectiva de librerías del JAR](evidence/security-remediation/native/attempt-2/packaged-libraries.json) comprueba lo empaquetado, además de lo declarado. Contiene Jackson 2 y 3 con versiones actualizadas porque hay dependencias transitivas que conservan Jackson 2. La [matriz de resolución](evidence/security-remediation/native/resolved-dependency-mapping.json) comprueba las catorce librerías actualizadas para los 49 hallazgos y la ausencia de sus versiones anteriores. Esto no sustituye el reescaneo de la imagen completa.

## Adaptaciones necesarias

Se siguió la [guía oficial de migración Boot 4](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide): se usa el starter `webmvc`, los starters de prueba Web MVC/JPA, y el starter Flyway con su módulo PostgreSQL. Las anotaciones MockMvc y JPA de prueba cambiaron de paquete. La prueba de contrato usa el `ObjectMapper` y `JsonNode` de Jackson 3; `JsonProperty` conserva el namespace de anotaciones compartido `com.fasterxml.jackson.annotation`.

El handler de validación obtiene directamente `exception.getBindingResult()`, eliminando el cast anterior a `BindException`, incompatible con la jerarquía actual. Conserva los códigos y la estructura `errors`. No se modificaron condiciones del servicio, rutas del controlador, entidad, DTO, migración V1 ni configuraciones de base de datos o salud.

El test existente de alta envía ahora `id=2147483647` y verifica que el servidor devuelve un ID positivo distinto, recuperable por GET. Asegura que Jackson 3 respeta el contrato de ID de solo lectura. No se añadió una funcionalidad ni se aumentó el número de casos.

## Validación ejecutada

Dos ejecuciones completas de `clean verify`, con heap de 384 MiB para Maven y Surefire, aprobaron **22 pruebas**, PMD con **cero violaciones**, y los controles JaCoCo existentes. El segundo comando se justificó por la nueva comprobación del ID enviado por el cliente. Los dos intentos permanecen separados en la [evidencia nativa](evidence/security-remediation/native/README.md).

El JAR pasó **nueve comprobaciones HTTP reales**, incluidas creación, consulta, validación, duplicado, ausencia, Swagger y OpenAPI. Su proceso se detuvo al finalizar. El JAR del segundo build tiene exactamente el mismo SHA-256 que el artefacto comprobado por HTTP, porque el cambio posterior afectó únicamente una prueba; se conserva la [comparación de hashes](evidence/security-remediation/native/jar-identity.json). No se repitió innecesariamente el smoke test sobre los mismos bytes.

## Cobertura y límites

La medición vigente es **51/58 líneas, 87,93 %**, y **2/2 ramas, 100 %**. El servicio mantiene **14/14 líneas y 2/2 ramas**. No se cambiaron las nueve reglas PMD ni se redujeron los gates: 85 % de líneas globales y 100 % de líneas y ramas del servicio.

El resultado histórico era 65/72 líneas y 8/62 ramas. El [cambio predeterminado de Lombok desde 1.18.34](https://projectlombok.org/changelog) añade `@lombok.Generated`; JaCoCo filtra ese código automáticamente. Por eso los denominadores cambian al actualizar el BOM, aunque los 22 casos permanezcan. No se añadieron exclusiones, configuraciones Lombok o pruebas artificiales para elevar la cobertura. La [guía de calidad](CALIDAD.md) conserva las mediciones anteriores y explica su comparación.

No hubo errores de compilación o de pruebas en estas dos ejecuciones nativas. PMD conserva una advertencia sobre la falta de URL del proyecto padre en su navegación HTML; no es una infracción de las reglas. El resultado nativo no acredita por sí solo ausencia de CVE, construcción Linux, publicación, migración sobre PostgreSQL existente ni despliegue Kubernetes. Esos controles requieren el escaneo y el pipeline posteriores sobre el artefacto actualizado.

## Preguntas de defensa

1. ¿Por qué un override de Framework 7 sobre Boot 3 habría sido una decisión diferente de actualizar un BOM coherente?
2. ¿Qué prueba la lista de JAR empaquetados que no basta con declarar en el POM? ¿Por qué sigue siendo necesario Trivy?
3. ¿Por qué hay Jackson 2 y 3 en el artefacto y cómo se comprobó el ID de solo lectura?
4. ¿Qué cambió en los starters de Flyway y en los módulos de pruebas de Boot 4?
5. ¿Por qué el 100 % de ramas actual no demuestra por sí solo que las pruebas mejoraron respecto al 12,90 % histórico?
