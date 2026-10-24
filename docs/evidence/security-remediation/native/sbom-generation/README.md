# Generación nativa del SBOM y comprobación del inventario

El **23 de octubre de 2026**, con Temurin 17.0.20.1+1, Maven 3.8.7 y heap de 384 MiB, se ejecutó únicamente:

```powershell
.\mvnw.cmd -B -ntp org.cyclonedx:cyclonedx-maven-plugin:2.9.3:makeBom
```

Este objetivo generó el inventario en unos veinte segundos, sin compilar, ejecutar pruebas ni reconstruir el JAR. No se utilizaron flags para omitir pruebas. Docker y el nodo local ya estaban activos; se limitó el trabajo a un único proceso Maven. Las dos suites completas anteriores siguen identificadas en [el índice nativo](../README.md).

| Comprobación real | Resultado | Evidencia |
| --- | --- | --- |
| Generación CycloneDX | Exit code 0; esquema 1.6; 110 componentes | [comando y entorno](generation-result.json), [log](maven-makeBom.log), [BOM original](bom.json) |
| Identidad del JAR antes/después | SHA-256 intacto: `7a31462fbc2709e493d7bc0658c464f9eebeaee89a7a6f39ccb0689b6d02632c` | [resultado](generation-result.json) |
| Cobertura de librerías del JAR anterior por SHA-256 | 97 de 98; falta únicamente `spring-boot-jarmode-tools-4.1.2.jar` | [comparación completa](old-archive-coverage.json) |
| Coordenadas de los 49 hallazgos originales | Las catorce están presentes con sus versiones actualizadas | [comparación](old-archive-coverage.json) |
| Campos variables del BOM | Sin `serialNumber` ni timestamp de ejecución; `cdx:reproducible=enabled` | [BOM](bom.json), [comparación](old-archive-coverage.json) |
| Última versión estable publicada | 2.9.3 | [metadata de Maven Central](maven-central-metadata.xml), [fuentes y configuración final](configuration-and-sources.json) |

## Interpretación y siguiente validación

Los 110 componentes representan el grafo Maven `compile,provided,runtime`. Incluyen trece componentes ausentes del JAR comparado: DevTools y doce starters. El informe los enumera; no se eliminan para aparentar que inventario de construcción y contenido del archivo son idénticos. Lombok, de alcance `provided`, sí coincide con el JAR empaquetado y se conserva en el BOM.

El auxiliar `spring-boot-jarmode-tools` lo inserta el plugin de Boot para extracción por jarmode; no procede de una dependencia declarada de la aplicación. Tras medir el hueco y consultar la [documentación oficial de Boot 4.1.2](https://docs.spring.io/spring-boot/maven-plugin/packaging.html#includeTools), se configuró `includeTools=false`. La imagen usa `java -jar` y no necesita esa herramienta. No se añadió una dependencia artificial ni un componente manual al BOM. Este cambio se realizó **después** de la generación registrada; por eso se conservan por separado el hash del POM ejecutado y el de la configuración final. El grafo de dependencias del BOM no cambió.

El siguiente empaquetado se espera con 97 JAR anidados. No se construyó localmente ni se declara aprobado a partir de esta expectativa. El pipeline debe ejecutar `clean verify`, obtener JAR y BOM de la misma etapa de construcción, copiarlos a la imagen y validar por SHA-256 todas las librerías extraídas de esa imagen. Debe aplicar el escaneo complementario `trivy sbom` y conservar el escaneo de imagen para los paquetes del sistema operativo. El BOM local no se usará para afirmar cobertura de una imagen Linux distinta.

Los parámetros de reproducibilidad eliminan campos variables; una generación única no demuestra por sí sola que dos ejecuciones completas produzcan bytes iguales. Tampoco se evaluó reproducibilidad OCI como parte de este comando.

## Incidencias conservadas

El plugin emitió advertencias de su validador JSON sobre `meta:enum` y `deprecated`; terminó con `BUILD SUCCESS` y exit code 0. Se conserva el log, sin presentarlas como fallos de pruebas. El primer comando ad hoc para comparar el archivo falló al reutilizar `$Matches`, variable automática de PowerShell; se corrigió el nombre de la colección y se completó la comparación sin volver a ejecutar Maven. La [nota del error](comparison-initial-error.txt) registra ese problema de inspección.

Las fuentes de parámetros son la [versión etiquetada 2.9.3](https://github.com/CycloneDX/cyclonedx-maven-plugin/blob/cyclonedx-maven-plugin-2.9.3/src/main/java/org/cyclonedx/maven/BaseCycloneDxMojo.java) y su [release oficial](https://github.com/CycloneDX/cyclonedx-maven-plugin/releases/tag/cyclonedx-maven-plugin-2.9.3). La documentación generada que mostraba `2.10.0-SNAPSHOT` no se utilizó para seleccionar una versión de desarrollo.
