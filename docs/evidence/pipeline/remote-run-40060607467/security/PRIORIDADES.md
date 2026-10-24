# Hallazgos pendientes del escaneo real de entrega

Datos derivados exclusivamente de [trivy-image.json](trivy-image.json), run `40060607467`, imagen `devsu-demo-java:d3af234b09be0241e0ba339e974572da0b506e3a`. No se omitieron hallazgos sin corrección.

Resultado: **32 hallazgos paquete-CVE**, 0 CRITICAL, 0 HIGH, 28 MEDIUM y 4 LOW. 1 incluye versión corregida indicada; 31 no la incluye en este snapshot. Estos resultados no prueban explotación ni ausencia de otras vulnerabilidades.

## Con versión corregida indicada

| ID | Severidad | Paquete | Instalada | Corregida |
|---|---|---|---|---|
| CVE-2026-85091 | MEDIUM | zlib1g | 1:1.3.dfsg-3.1ubuntu2.2 | 1:1.3.dfsg-3.1ubuntu2.3 |

## Sin versión corregida indicada en el reporte

| ID | Severidad | Paquete | Instalada |
|---|---|---|---|
| CVE-2026-40228 | LOW | libsystemd0 | 255.4-1ubuntu8.17 |
| CVE-2026-40228 | LOW | libudev1 | 255.4-1ubuntu8.17 |
| CVE-2024-56433 | LOW | login | 1:4.13+dfsg1-4ubuntu3.2 |
| CVE-2024-56433 | LOW | passwd | 1:4.13+dfsg1-4ubuntu3.2 |
| CVE-2026-102473 | MEDIUM | dash | 0.5.12-6ubuntu5 |
| CVE-2026-102474 | MEDIUM | dash | 0.5.12-6ubuntu5 |
| CVE-2026-18374 | MEDIUM | libc-bin | 2.39-0ubuntu8.9 |
| CVE-2026-89092 | MEDIUM | libc-bin | 2.39-0ubuntu8.9 |
| CVE-2026-18374 | MEDIUM | libc6 | 2.39-0ubuntu8.9 |
| CVE-2026-89092 | MEDIUM | libc6 | 2.39-0ubuntu8.9 |
| CVE-2025-66382 | MEDIUM | libexpat1 | 2.6.1-2ubuntu0.6 |
| CVE-2026-67693 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-88647 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-88648 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-95184 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-95209 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-95210 | MEDIUM | libgnutls30t64 | 3.8.3-1.1ubuntu3.6 |
| CVE-2026-103111 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-86145 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-89156 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-89157 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-89158 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-89160 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-89161 | MEDIUM | libpcre2-8-0 | 10.42-4ubuntu2.1 |
| CVE-2026-107161 | MEDIUM | libsasl2-2 | 2.1.28+dfsg1-5ubuntu3.1 |
| CVE-2026-107161 | MEDIUM | libsasl2-modules-db | 2.1.28+dfsg1-5ubuntu3.1 |
| CVE-2026-18374 | MEDIUM | locales | 2.39-0ubuntu8.9 |
| CVE-2026-89092 | MEDIUM | locales | 2.39-0ubuntu8.9 |
| CVE-2026-18477 | MEDIUM | tar | 1.35+dfsg-3ubuntu0.4 |
| CVE-2026-18508 | MEDIUM | tar | 1.35+dfsg-3ubuntu0.4 |
| CVE-2021-31879 | MEDIUM | wget | 1.21.4-1ubuntu4.5 |

La política bloquea cualquier CRITICAL/HIGH y errores de análisis. Los MEDIUM/LOW permanecen visibles. Una actualización de base deberá fijar un digest nuevo y repetir build, pruebas, ambos escaneos y despliegue; no se ejecutó una actualización sin versiones de paquetes del sistema para alterar esta evidencia.
