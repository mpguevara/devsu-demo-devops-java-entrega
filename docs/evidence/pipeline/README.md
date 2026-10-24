# Evidencia del pipeline

`actionlint-result.json` registra una ejecucion real de actionlint 1.7.12 sobre `.github/workflows/ci.yml`, con comando, fechas, codigo de salida, SHA256 del workflow y del binario utilizado. El paquete se verifico contra el checksum publicado en el release oficial. `actionlint.log` contiene su salida; un archivo vacio es el resultado normal cuando no hay diagnosticos.

Esta evidencia demuestra validacion estatica del YAML. No demuestra compilacion, ejecucion de GitHub Actions, publicacion GHCR ni despliegue Kubernetes. Los resultados de esas etapas deben obtenerse de ejecuciones reales y documentarse por separado.

Si cambia el workflow, su SHA256 deja de coincidir con este resultado y corresponde volver a ejecutar la validacion.

Ejecuciones remotas conservadas:

- [40043825396](remote-run-40043825396/README.md): calidad, imagen y publicacion aprobadas; validacion Kubernetes fallida por resolucion multiple de kubectl en Linux. El fallo real y sus logs se conservan.
- [40044688944](remote-run-40044688944/README.md): revision corregida, ejecucion completa aprobada con cuatro jobs exitosos, 22 pruebas y 30 comprobaciones Kubernetes. La carpeta conserva sus propios artifacts; no sustituye la evidencia anterior.
