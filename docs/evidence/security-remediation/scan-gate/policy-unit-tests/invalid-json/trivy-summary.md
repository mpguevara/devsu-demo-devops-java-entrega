# Prueba unitaria de politica: fixture, sin ejecutar Trivy

Imagen: fixture/not-a-real-image:test

Politica: cualquier CRITICAL o HIGH bloquea publicacion y despliegue. Se conservan todas las severidades.
Estado: report-error. Escaner completado: True. Evaluacion valida: False. Gate aprobado: False.

No hay un conteo validado; consultar el error operativo o del reporte.

Detalle: Conversion from JSON failed with error: Unexpected end when deserializing object. Path 'SchemaVersion', line 3, position 0.

Un gate aprobado solo confirma ausencia de CRITICAL/HIGH reportados en este escaneo y no demuestra ausencia de todo riesgo.
