# hub-infra

Infraestructura compartida del Hub Empresarial: gateway Nginx, base de datos PostgreSQL y orquestación Docker que conecta los repos [`hub-backends`](https://github.com/benjaminAndaur/hub-backends) y [`hub-frontends`](https://github.com/benjaminAndaur/hub-frontends).

## Contenido

| Carpeta/Archivo | Descripción |
|---|---|
| `docker-compose.yml` | Orquestación completa: base de datos, gateway, 10 microservicios y 10 frontends |
| `nginx/nginx.conf` | Gateway Nginx (puerto `8080`): rutea frontends por path, proxifica `/api/v1/*` a cada microservicio y valida JWT vía `auth_request` |
| `db_postgres/init.sql` | Schema completo de la base de datos `asdf_db` (PostgreSQL 15) |
| `db_postgres/Dockerfile` y `docker-compose.yml` | Imagen y servicio de base de datos |
| `CLAUDE.md` | Documentación de arquitectura y guía de desarrollo del Hub Empresarial |

## Cómo levantar el stack completo

```bash
docker-compose up --build
```

> Este `docker-compose.yml` referencia los Dockerfiles de cada módulo en `hub-backends` y `hub-frontends`. Para que funcione, ambos repos deben estar clonados como directorios hermanos de `hub-infra` (mismo nivel), o ajustar los `context:` de cada servicio en `docker-compose.yml` para que apunten a las rutas correctas.

```
Escritorio/
├── hub-backends/
├── hub-frontends/
└── hub-infra/        ← ejecutar docker-compose desde aquí
```

## Acceso tras el arranque

Todo entra por el gateway Nginx en `http://localhost:8080`:

| Servicio | URL |
|---|---|
| Administración | `http://localhost:8080/` |
| Login | `http://localhost:8080/login/` |
| RRHH | `http://localhost:8080/rrhh/` |
| Mantención | `http://localhost:8080/mantencion/` |
| Operación | `http://localhost:8080/operacion/` |
| Bodega | `http://localhost:8080/bodega/` |
| Acreditación | `http://localhost:8080/acreditacion/` |
| Facturación | `http://localhost:8080/facturacion/` |
| Prevención | `http://localhost:8080/prevencion/` |
| Watchdog | `http://localhost:8080/watchdog/` |
| pgAdmin | `http://localhost:5050` (`admin@asdf.com` / `admin`) |

## Usuarios pre-cargados (seeder)

| Email | Password | Acceso |
|---|---|---|
| `admin@asdf.cl` | `admin123` | Todos los módulos: edit |
| `rrhh@asdf.cl` | `user123` | rrhh: edit |
| `mantencion@asdf.cl` | `user123` | mantencion: edit, bodega: view |
| `operacion@asdf.cl` | `user123` | operacion: edit, facturacion: view |
| `bodega_visor@asdf.cl` | `user123` | bodega: view |

## Variables de entorno

| Variable | Valor en dev |
|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://admin:admin123@db-global:5432/asdf_db` |
| `JWT_SECRET` | `super-secret-key-123` |
| `VITE_API_URL` | `/api/v1` (inyectado en build de los frontends; Nginx lo proxifica) |

## Flujo de autenticación (a nivel gateway)

1. `POST /api/v1/administracion/login` es la única ruta pública (además de `/health` del watchdog).
2. Nginx intercepta cada request protegida con `auth_request /_auth_check` → proxifica a `ms-middleware:8009/validate`.
3. El middleware valida el JWT y retorna `X-User-ID`, `X-User-Role`, `X-User-Email` como headers, que Nginx pasa al microservicio destino.

## Base de datos (`asdf_db`, PostgreSQL 15)

Schema en `db_postgres/init.sql`. Tablas principales por módulo:

| Módulo | Tablas |
|---|---|
| RRHH | `personal`, `personal_historico` |
| Mantención | `vehiculos`, `mantenciones`, `mantenciones_template`, `ordenes_trabajo`, `ot_repuestos` |
| Acreditación | `clientes`, `requerimientos`, `acreditaciones` |
| Operación | `viajes` |
| Bodega | `productos`, `ingresos_bodega` |
| Facturación | `facturas` |
| Prevención | `incidentes` |
| Administración | `usuarios` |

**pg_cron:** ejecuta `snapshot_personal_diario()` cada día a las 23:59, copiando todos los registros de `personal` a `personal_historico` (auditoría histórica).

No hay migraciones — el schema se crea con `Base.metadata.create_all()` al arrancar cada microservicio (schema-on-startup).
