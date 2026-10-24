# Prueba unitaria de politica: fixture, sin ejecutar Trivy

Imagen: fixture/not-a-real-image:test

Politica: cualquier CRITICAL o HIGH bloquea publicacion y despliegue. Se conservan todas las severidades.
Estado: passed. Escaner completado: True. Evaluacion valida: True. Gate aprobado: True.

| Severidad | Hallazgos |
|---|---:|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 1 |
| LOW | 1 |
| UNKNOWN | 1 |

Un gate aprobado solo confirma ausencia de CRITICAL/HIGH reportados en este escaneo y no demuestra ausencia de todo riesgo.
