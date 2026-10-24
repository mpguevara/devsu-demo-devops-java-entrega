# Prueba unitaria de politica: fixture, sin ejecutar Trivy

Imagen: fixture/not-a-real-image:test

Politica: cualquier CRITICAL o HIGH bloquea publicacion y despliegue. Se conservan todas las severidades.
Estado: blocked-vulnerabilities. Escaner completado: True. Evaluacion valida: True. Gate aprobado: False.

| Severidad | Hallazgos |
|---|---:|
| CRITICAL | 1 |
| HIGH | 0 |
| MEDIUM | 0 |
| LOW | 0 |
| UNKNOWN | 0 |

Detalle: La politica bloquea 1 CRITICAL y 0 HIGH.

Un gate aprobado solo confirma ausencia de CRITICAL/HIGH reportados en este escaneo y no demuestra ausencia de todo riesgo.
