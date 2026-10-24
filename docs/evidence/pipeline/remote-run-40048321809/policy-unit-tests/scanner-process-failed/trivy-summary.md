# Prueba unitaria de politica: fixture, sin ejecutar Trivy

Imagen: fixture/not-a-real-image:test

Politica: cualquier CRITICAL o HIGH bloquea publicacion y despliegue. Se conservan todas las severidades.
Estado: operational-error. Escaner completado: False. Evaluacion valida: False. Gate aprobado: False.

No hay un conteo validado; consultar el error operativo o del reporte.

Detalle: Trivy no termino correctamente (exitCode=2).

Un gate aprobado solo confirma ausencia de CRITICAL/HIGH reportados en este escaneo y no demuestra ausencia de todo riesgo.
