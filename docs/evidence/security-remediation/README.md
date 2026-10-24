# Evidencia de corrección de vulnerabilidades

Esta etapa conserva resultados reales del 23 de octubre de 2026, hora de El Salvador. Las fechas UTC de GitHub y Trivy pueden mostrar el 24 de octubre. Los informes anteriores permanecen intactos.

## Secuencia comprobada

1. El [run anterior](../pipeline/remote-run-40044688944/README.md), con Boot 3.0.5, reportó 9 CRITICAL y 40 HIGH. El [agregado anterior](before-remediation-final-verification.json) se conserva como captura histórica.
2. La actualización a Boot 4.1.2 pasó dos `clean verify` de 22 pruebas, PMD y gates JaCoCo, más nueve comprobaciones HTTP del JAR. Véase [evidencia nativa](native/README.md). La segunda ejecución reforzó la aserción de ID de solo lectura con Jackson 3; no corrigió un fallo ficticio de la primera.
3. El [run 40046900827](https://github.com/mpguevara/devsu-demo-devops-java/actions/runs/40046900827), revisión `ccf1adc4afed257e2c7bb7a7a4005c144f742a9c`, aprobó sus cuatro jobs, incluyendo 30 comprobaciones Kubernetes. Su escaneo reportó 0 CRITICAL/HIGH, pero una revisión del inventario detectó cobertura incompleta de identificación Java: 62 registros, correspondientes a 59 de las 98 rutas JAR, además de registros auxiliares. Se conserva la [comparación inicial](scan-comparison.json), la [comprobación fallida de coordenadas](image-java-inventory-verification.json) y el [diagnóstico por ruta y hash](container-base/JAR-IDENTIFICATION-DIAGNOSTIC.md). Este run no se usa como prueba de cobertura completa.
4. CycloneDX 2.9.3 generó un SBOM Maven con 110 componentes, incluyendo compile/runtime/provided y excluyendo el scope de pruebas. La [generación aislada](native/sbom-generation/generation-result.json) no compiló ni ejecutó tests. La comparación vinculó por SHA-256 97 de los 98 JAR anteriores; el auxiliar de extracción `jarmode-tools` se desactivó mediante la opción oficial `includeTools=false`, porque esta imagen usa `java -jar` y no utiliza ese modo. No se añadió una dependencia artificial ni una excepción de CVE.
5. El [escaneo standalone del SBOM](standalone-sbom-scan/) ejecutó Trivy real y verificó 110/110 componentes por PURL, con cero hallazgos en todas las severidades. Valida el formato y sus coordenadas; no demuestra por sí solo qué bytes contiene la imagen final.
6. El [run final 40048321809](../pipeline/remote-run-40048321809/README.md), revisión `81beb47ba4b03f98e407860d94d143a22f2d2771`, aprobó sus cuatro jobs. Verificó **97/97 JAR por SHA-256**, 14/14 coordenadas históricas y 110/110 componentes SBOM incorporados en los 111 registros de Trivy. Imagen: **0 CRITICAL/0 HIGH, 28 MEDIUM/4 LOW**; SBOM: **cero hallazgos**. Kubernetes aprobó 30 comprobaciones y registró 21.354 GET exitosos/0 fallidos, con HPA de dos a cuatro Ready. Véase la [comparación final](final-scan-comparison.json). La publicación requiere ambos gates e inventarios aprobados.

## Política y controles

- [Ocho pruebas offline de política](scan-gate/README.md): distinguen hallazgos de errores operativos y verifican que se guarde el reporte antes de bloquear. Los identificadores `FIXTURE-*` son entradas unitarias, no CVE reales.
- [Controles de inventario SBOM](sbom-gate/): fixtures separados comprueban el caso completo, un componente ausente, hash incorrecto y PURL omitido. No ejecutan el escáner, Maven ni Docker.
- Ambos escaneos reales conservan todas las severidades y vulnerabilidades sin corrección. No hay lista de excepciones de CVE. Un error operativo, JSON inválido o inventario incompleto también bloquea.

## Datos y recursos locales

El [snapshot Before](postgres-upgrade/before.json), obtenido en una sesión PostgreSQL de solo lectura, conserva dos usuarios sintéticos, el UID del PVC, la V1 y su historial Flyway. El [After aprobado](postgres-upgrade/after.json) comprobó esos mismos datos después de actualizar a la imagen final y antes de que la prueba Kubernetes creara otro usuario.

La [identidad OCI resuelta](local-image/pull-inspect-resolved.json) comprobó manifiesto, configuración, capas y etiquetas contra CI y el registry. El primer chequeo comparaba directamente dos representaciones distintas de `image inspect.Id` y se conserva como diagnóstico fallido; aquí el ID local coincide con el digest del manifiesto, mientras CI registra el digest de configuración. No se presenta esa diferencia como corrupción ni se atribuye una causa no demostrada.

El [primer despliegue local](local-deploy/deploy-results.json) falló en `kind load docker-image` con un contenido de configuración no encontrado, antes de cambiar la aplicación. Se mantuvieron los pods anteriores y sus datos. La alternativa descargó el digest publicado directamente en containerd del nodo propio, con TLS y sin credenciales, y el [segundo despliegue](local-deploy-attempt-2/deploy-results.json) aprobó sin `-LoadImage`. Las consultas auxiliares y el primer intento de `ctr` con una opción incompatible quedan conservados; no se cambiaron manifiestos, scripts, configuración de containerd, PVC ni Secret para resolverlo. CI sí utilizó su archivo de imagen con checksum, como describe su evidencia.

El [ensayo local final](local-kubernetes/README.md) aprobó 30 comprobaciones y 7.104 GET exitosos/0 fallidos. El objetivo HPA pasó de dos a cuatro, con tres Ready durante carga y cuatro en la observación posterior. Esa captura confirmó cero Jobs y port-forwards propios, conservando el PVC. La [guía de transferencia](local-image/README.md) permite reproducir el método realmente utilizado.

Para liberar memoria se detuvieron temporalmente el nodo propio y Docker Desktop, conservando contenedores, volumen y datos: [coordinación](resource-coordination.json), [pausa](docker-pause.json) y [reanudación](docker-resumed.json). Reapareció el error de socket AF_UNIX de Docker; los directorios exactos se conservaron como respaldo y se reinició Desktop, sin factory reset: [resolución real](docker-startup-recovery.json).

La primera comparación ad hoc del inventario nativo encontró una colisión con la variable automática `$Matches` de PowerShell. Se renombró la colección y se obtuvo el resultado conservado: [incidencia](native/sbom-generation/comparison-initial-error.txt). El validador del pipeline utiliza nombres propios y sus fixtures comprueban el comportamiento. Este error de la herramienta de comparación no se presenta como un fallo Maven o de la aplicación.

La [guía de seguridad](../../SEGURIDAD.md) explica decisiones, limitaciones y preguntas de defensa. El alcance son la imagen Java y sus dependencias; no se certifica ausencia de todo riesgo ni se declara alta disponibilidad, backup o exposición pública.
