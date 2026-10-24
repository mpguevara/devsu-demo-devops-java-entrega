# Comparar datos antes y después de la actualización

`scripts/Test-DependencyUpgrade.ps1` consulta exclusivamente el clúster propio `kind-devsu` y verifica su marca externa de propiedad y la etiqueta del namespace. No arranca Docker, no despliega recursos, no lee Secrets y no modifica datos. Ejecuta un SELECT por el socket local de PostgreSQL, con `PGOPTIONS` que fuerza la sesión a solo lectura.

Antes de desplegar la nueva imagen, con los pods antiguos ya iniciados:

```powershell
./scripts/Test-DependencyUpgrade.ps1 -Mode Before
```

Después del despliegue y su rollout, sobre el mismo clúster y PVC:

```powershell
./scripts/Test-DependencyUpgrade.ps1 -Mode After -ExpectedImage 'referencia-exacta-de-la-imagen-desplegada'
```

`ExpectedImage` es opcional; permite contrastar la referencia del Deployment con el digest/tag esperado. El script registra también imageIDs reales y exige que hayan cambiado respecto al snapshot anterior.

Los archivos predeterminados son `docs/evidence/security-remediation/postgres-upgrade/before.json` y `after.json`. Conservan usuarios sintéticos ordenados por ID, cantidad, historial Flyway con versión/checksum/success, UID del PVC, referencia de la imagen e imageIDs y SHA-256 del archivo V1. No contienen contraseñas ni kubeconfig.

El modo After exige que todos los usuarios anteriores mantengan ID, DNI y nombre; permite usuarios sintéticos nuevos creados durante los smoke tests. Exige el mismo PVC, historial Flyway idéntico y ningún cambio de bytes en la fuente V1. Los controles y cualquier error quedan en el resultado. Un fallo sale con error y se conserva como fallido.

No se sobrescribe un snapshot existente. Para repetir un After fallido, usa otra carpeta con `-EvidenceDirectory` y apunta al Before original mediante `-BeforeSnapshotPath`. Estas capturas no prueban recuperación ante pérdida del volumen ni alta disponibilidad. Su alcance es preservar datos existentes al cambiar dependencias/imagen.

Este archivo describe el procedimiento. Los snapshots reales aparecen únicamente cuando se ejecuta el script; escribirlo y analizar su sintaxis no acredita la actualización.
