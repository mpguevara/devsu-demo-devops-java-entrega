# Pruebas del gate de inventario SBOM

Se ejecutaron realmente cuatro pruebas unitarias offline con PowerShell 7. Los archivos sinteticos usan versiones `0.0.0-fixture`; no ejecutan Trivy, Docker ni Maven y no son resultados de vulnerabilidades de la aplicacion.

Comando: `./scripts/ci/Test-SbomInventory.ps1 -EvidenceDirectory .devsu-local/sbom-inventory-tests`.

| Caso | Resultado exigido | Resultado observado |
|---|---|---|
| Cada JAR tiene SHA256/PURL en SBOM y reporte | Aceptar | Aceptado |
| Componente ausente del SBOM | Rechazar y guardar evidencia | Rechazado, JSON escrito |
| Hash del SBOM incorrecto | Rechazar y guardar evidencia | Rechazado, JSON escrito |
| PURL ausente del inventario Trivy | Rechazar y guardar evidencia | Rechazado, JSON escrito |

[test-results.json](test-results.json) contiene los resultados reales y cada carpeta conserva su inventario, incluidos los mensajes de rechazo. [powershell-parser.json](powershell-parser.json) conserva la validacion sintactica y SHA256 de los scripts revisados; [actionlint-result.json](actionlint-result.json) y [actionlint.log](actionlint.log) registran la revision real del YAML, version y hashes. Un analisis sintactico no demuestra una ejecucion remota ni un escaneo de imagen; estos requieren evidencia separada.
