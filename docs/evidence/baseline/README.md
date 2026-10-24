# Evidencia real de la línea base

Ejecución local en Windows, el **20 de octubre de 2026**, hora de El Salvador. Estos archivos acreditan únicamente la etapa 1. No son una ejecución de GitHub Actions, un escaneo de seguridad ni un despliegue Kubernetes.

| Archivo | Qué acredita |
| --- | --- |
| [README-original.md](README-original.md) | Documentación recibida sin editar, incluida la atribución original |
| [source-original.sha256.json](source-original.sha256.json) | Hashes de los 25 archivos iniciales, antes de los cambios de documentación |
| [environment.json](environment.json) | Instantánea de herramientas y recursos observados; no contiene un volcado de variables de entorno |
| [docker-version.log](docker-version.log) | Cliente Docker instalado y error real de conexión al motor Linux |
| [kubectl-contexts.log](kubectl-contexts.log) | Lista vacía de contextos Kubernetes |
| [tool-checks-result.json](tool-checks-result.json) | Fecha y códigos de salida de esas comprobaciones de herramientas |
| [toolchain.json](toolchain.json) | JDK utilizado, origen y SHA-256 verificado; comparación del wrapper con el JAR de Maven Central |
| [maven-version.log](maven-version.log) | Maven 3.8.7 ejecutado con Temurin 17.0.20.1 |
| [build-result.json](build-result.json) | Comando real de construcción, límites de heap, fechas y código de salida |
| [maven-clean-verify.log](maven-clean-verify.log) | Salida de la construcción y seis pruebas originales; BUILD SUCCESS |
| [test-summary.json](test-summary.json) | Resumen extraído de XML de Surefire; tamaño/hash del JAR generado |
| [surefire/](surefire/) | Reportes TXT reales por clase de prueba |
| [dependency-tree.txt](dependency-tree.txt) | Árbol real de dependencias resueltas |
| [maven-dependency-tree.log](maven-dependency-tree.log) | Resultado del comando que generó el árbol |
| [http/http-results.json](http/http-results.json) | Nueve peticiones con estado esperado/observado, cuerpos JSON y verificación de cierre del proceso |
| [http/application.stdout.log](http/application.stdout.log) | Arranque real del JAR y procesamiento de solicitudes |
| [http/application.stderr.log](http/application.stderr.log) | Salida estándar de error de esa ejecución; archivo vacío |

La construcción utilizó la configuración de pruebas original; las pruebas Spring generaron el archivo H2 local, excluido por `.gitignore`. El smoke del JAR usó H2 **en memoria**, enlazó HTTP a `127.0.0.1:8000` y descartó sus datos al detenerse. No demuestra persistencia entre reinicios ni uso de variables de entorno en un contenedor.

Swagger se comprobó siguiendo su redirección hasta HTTP 200. Los casos 400 de duplicado/validación y 404 de usuario inexistente son resultados esperados. El usuario `Prueba DevOps` y el DNI de prueba son datos sintéticos utilizados para comprobar el contrato.

El JAR y la base de datos local permanecen fuera del contenido publicable (`target/` y `*.mv.db`). Los logs contienen rutas de esta máquina y fixtures de demostración; no se incluyeron tokens, kubeconfigs ni credenciales reales. La revisión de secretos deberá repetirse antes de publicar cambios posteriores.

Para repetir sin sobrescribir esta captura inicial:

```powershell
. .\scripts\Use-Java17.ps1
$env:MAVEN_OPTS = '-Xmx384m -Dfile.encoding=UTF-8'
.\mvnw.cmd -B -ntp clean verify '-DargLine=-Xmx384m'
.\scripts\Test-LocalApi.ps1
```

Las nuevas respuestas HTTP quedan por defecto en `target/local-api-evidence/`. El SHA-256 identifica el artefacto específico de esta captura. La reproducibilidad byte a byte del JAR todavía no se ha probado; no se debe exigir que una nueva construcción produzca este mismo hash.
