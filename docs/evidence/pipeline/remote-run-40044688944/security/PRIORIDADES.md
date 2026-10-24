# Prioridades a partir del escaneo real

Fuente: `trivy-image.json`, Trivy 0.76.1, ejecucion [40044688944](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40044688944), revision `2506a339cd878b0c17d9da94caebccbcbfa1660c`. El escaneo termino el 24 de octubre de 2026 a las 00:25:16 UTC (23 de octubre a las 18:25:16 en El Salvador).

El resultado contiene **121 hallazgos paquete-CVE**, correspondientes a **112 identificadores CVE diferentes**. No son 121 ataques demostrados. Se conserva la clasificacion original: **9 CRITICAL, 40 HIGH, 58 MEDIUM y 14 LOW**. Hay 89 hallazgos en bibliotecas Java y 32 en paquetes Ubuntu. El pipeline es informativo frente a hallazgos; la imagen no se presenta como libre de vulnerabilidades.

## Orden de trabajo propuesto

| Prioridad | Componentes y version instalada | Evidencia y accion pendiente |
|---|---|---|
| 1 | Tomcat embed core 10.1.7 | 7 CRITICAL y 18 HIGH; revisar sus avisos oficiales y actualizar una combinacion compatible del BOM/servidor. Repetir pruebas, probes y despliegue. |
| 1 | Spring Framework 6.0.7 y Spring Boot 3.0.5 | Dos CRITICAL adicionales en WebMVC y Actuator autoconfigure, ademas de otros HIGH. Revisar condiciones de cada aviso y planificar actualizacion coordinada. |
| 2 | Jackson core/databind 2.14.2 | 8 HIGH entre ambos componentes. Verificar la version compatible gestionada por el BOM elegido y repetir validacion de JSON. |
| 2 | Logback classic/core 1.4.6, Micrometer core 1.10.5, SnakeYAML 1.33 | Revisar HIGH del JSON completo y actualizar las dependencias transitivas junto al stack. |
| 2 | H2 2.1.214 | Un HIGH. H2 sigue empaquetado para el perfil local de demostracion; PostgreSQL es el perfil del despliegue. Evaluar excluir H2 de una imagen dedicada a despliegue y mantener la demostracion en otro artefacto, o actualizarlo de manera compatible. Su presencia no se oculta del escaneo. |
| 3 | Paquetes Ubuntu de la imagen base | 32 hallazgos, de los cuales 31 no informan `FixedVersion` en este snapshot. Revisar los avisos del proveedor y reconstruir con una base corregida cuando exista. No se usa `ignore-unfixed`. |

Las prioridades son una propuesta de mantenimiento, basada en severidad reportada y papel del componente. No sustituyen una prueba de explotabilidad. El valor `FixedVersion` puede listar varias ramas o un salto mayor incompatible; no debe copiarse directamente al POM sin validar el conjunto de dependencias.

## Los nueve CRITICAL conservados

La tabla siguiente se extrae del reporte, sin reclasificar ni suprimir hallazgos:

| CVE | Dependencia | Instalada | FixedVersion reportada |
|---|---|---|---|
| CVE-2025-24813 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 11.0.3, 10.1.35, 9.0.99 |
| CVE-2026-41293 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 9.0.118, 10.1.55, 11.0.22 |
| CVE-2026-43512 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 9.0.118, 10.1.55, 11.0.22 |
| CVE-2026-43515 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 9.0.118, 10.1.55, 11.0.22 |
| CVE-2026-65182 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 11.0.25, 10.1.58, 9.0.121 |
| CVE-2026-65905 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 11.0.25, 10.1.58, 9.0.121 |
| CVE-2026-68525 | org.apache.tomcat.embed:tomcat-embed-core | 10.1.7 | 11.0.25, 10.1.58, 9.0.121 |
| CVE-2023-20873 | org.springframework.boot:spring-boot-actuator-autoconfigure | 3.0.5 | 3.0.6, 2.7.11, 2.6.15, 2.5.15 |
| CVE-2026-47884 | org.springframework:spring-webmvc | 6.0.7 | 7.0.9 |

## Condiciones y limites del analisis

Los avisos originales pueden usar una severidad distinta de la base utilizada por Trivy. Por ejemplo, Spring clasifica CVE-2023-20873 como HIGH y exige un despliegue Cloud Foundry con determinadas rutas; el aviso CVE-2026-47884 es MEDIUM y exige XsltView con un mapeo de vistas concreto. Este proyecto despliega en kind y su controlador inspeccionado es REST, sin XsltView. Esas observaciones sirven para revisar aplicabilidad, sin cambiar el conteo del escaner ni declarar que toda la imagen sea inexplotable. Fuentes: [aviso oficial de CVE-2023-20873](https://spring.io/security/cve-2023-20873/), [aviso oficial de CVE-2026-47884](https://spring.io/security/cve-2026-47884/).

Los siete CRITICAL de Tomcat tambien necesitan revisar las condiciones de sus avisos, configuracion, protocolos y rutas activas. La fuente del mantenedor es la [lista oficial de vulnerabilidades de Tomcat 10](https://tomcat.apache.org/security-10.html). No se ejecutaron exploits ni se ha demostrado ausencia de explotabilidad.

El alcance del escaneo es la imagen de la aplicacion: su sistema operativo y sus JAR. Este reporte no equivale a escanear PostgreSQL, Traefik, metrics-server, el nodo Kubernetes ni el host. Mantener la API sin endpoint publico limita exposicion externa del ejercicio, pero no elimina las dependencias vulnerables ni reemplaza su actualizacion.

Este ejercicio conserva Spring Boot 3.0.5 de la aplicacion inicial para mantener el alcance de la automatizacion y sus pruebas de compatibilidad. Las actualizaciones compatibles del stack heredado y una politica bloqueante para produccion quedan pendientes. Los JSON, logs y versiones corregidas que conoce Trivy permiten preparar ese trabajo.


Este escaneo se ejecuto de nuevo para la revision corregida. Se compararon ID, paquete, version instalada, version corregida y severidad con el primer escaneo: el conjunto de hallazgos coincide. El JSON y log de esta carpeta proceden del segundo run; no se reutilizo el resultado operativo del primero.


