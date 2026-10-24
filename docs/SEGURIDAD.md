# Corrección de vulnerabilidades y verificación

## Punto de partida

El [pipeline anterior](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40044688944) terminó correctamente con una política de escaneo informativa. Trivy 0.76.1 registró **9 hallazgos críticos y 40 altos**, todos en librerías Java, además de 58 medios y 14 bajos. Son coincidencias entre paquete, versión y aviso; no representan 49 exploits demostrados. Se conserva íntegro el [informe anterior](evidence/pipeline/remote-run-40044688944/security/trivy-image.json), junto a sus prioridades y resultados.

La nueva etapa corrige las dependencias y añade una política que bloquea la publicación y el despliegue si se detecta cualquier hallazgo crítico o alto. Se conservan todas las severidades, incluidas vulnerabilidades sin versión corregida. No se añaden exclusiones de CVE ni se utiliza `--ignore-unfixed`.

## Actualización compatible

Se eligió Spring Boot **4.1.2**, estable y compatible con Java 17, para gestionar conjuntamente las versiones del framework, servidor HTTP, serialización, persistencia y pruebas. El informe anterior sitúa la corrección de `CVE-2026-47884` en Spring MVC 7.0.9; sustituir solamente Spring 6 por Spring 7 dentro de Boot 3 no sería una actualización coherente. Boot 4.1.2 gestiona Spring Framework 7.0.10.

La aplicación conserva sus endpoints, puerto y modelo de datos. La adaptación incluye los starters modulares de Boot 4, los imports de pruebas, Jackson 3 y el módulo PostgreSQL de Flyway. La migración SQL V1 existente permanece intacta. La [guía de migración Java](MIGRACION-SEGURIDAD-JAVA.md) detalla las versiones efectivas, cambios de compatibilidad y resultados nativos.

Referencias de selección: [requisitos oficiales de Spring Boot](https://docs.spring.io/spring-boot/system-requirements.html), [BOM 4.1.2 publicado en Maven Central](https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-dependencies/4.1.2/spring-boot-dependencies-4.1.2.pom) y [compatibilidad de springdoc](https://springdoc.org/). Las versiones concretas resueltas y los resultados de cada intento se guardan en [evidencia de esta etapa](evidence/security-remediation/).

## Alcance y límites

El escaneo solicitado se aplica a la imagen Java construida. Su resultado depende del contenido de la imagen, la versión del escáner y la base de avisos consultada. Cero hallazgos críticos y altos, cuando se verifica, no significa ausencia de vulnerabilidades ni sustituye una revisión de autorización, infraestructura, credenciales o exposición de red.

Los informes y las mediciones anteriores permanecen como capturas históricas. No se modifican para aparentar que las versiones anteriores estaban corregidas. Los nuevos resultados se documentan después de ejecutar las herramientas.

## Preguntas de defensa

1. ¿Por qué se actualizó el BOM de Spring Boot en conjunto en lugar de sustituir únicamente un JAR vulnerable?
2. ¿Cómo distingue el pipeline un fallo operativo del escáner de un escaneo terminado que encuentra una vulnerabilidad alta?
3. ¿Qué demuestra el escaneo de la imagen que se publica y qué no demuestra un resultado de cero críticos y altos?
4. ¿Cómo comprobamos que actualizar Flyway y Hibernate conserva el esquema y los datos existentes?
5. ¿Por qué deben conservarse los reportes anteriores y las vulnerabilidades medias o bajas restantes?
