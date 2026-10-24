# Hallazgos y cobertura de esta ejecucion

Trivy imagen `0.76.1` reporto 32 hallazgos: 0 CRITICAL, 0 HIGH, 28 MEDIUM y 4 LOW. Todos corresponden a paquetes Ubuntu; las versiones instaladas y corregidas provienen del JSON, sin inferir explotacion confirmada. [findings-all.csv](findings-all.csv) conserva los 32 pares paquete/CVE, incluidos los que no tienen version corregida indicada.

La prioridad de esta revision fue resolver una limitacion de inventario: 39 de 98 rutas JAR no fueron identificadas por este escaneo. El resultado no permite afirmar que toda la aplicacion quedo analizada. La [explicacion de la ejecucion](../README.md) y el [diagnostico](../../../security-remediation/container-base/JAR-IDENTIFICATION-DIAGNOSTIC.md) describen la evidencia y el nuevo gate SBOM requerido.

Los hallazgos MEDIUM/LOW siguen pendientes de evaluacion y actualizaciones de la base; no se eliminan ni se consideran inexplotables por usar un cluster privado. El resultado depende del snapshot de bases registrado en [trivy-version.json](trivy-version.json).
