# hub-infra

Infraestructura compartida del Hub Empresarial: gateway Nginx, base de datos PostgreSQL y orquestación Docker que conecta los repos [`hub-backends`](https://github.com/benjaminAndaur/hub-backends) y [`hub-frontends`](https://github.com/benjaminAndaur/hub-frontends).

## Contenido

| Carpeta/Archivo | Descripción |
|---|---|
| `docker-compose.yml` | Orquestación completa: bases de datos, gateway, 10 microservicios y 10 frontends |
| `nginx/nginx.conf` | Gateway Nginx (puerto `8080`): rutea frontends por path, proxifica `/api/v1/*` a cada microservicio y valida JWT vía `auth_request` |
| `db_postgres/init.sql` | Schema de la base de datos compartida `asdf_db` (PostgreSQL 15) |
| `db_operacion/init.sql` | Schema de la base de datos aislada `operacion_db` (Database per Service) |
| `db_facturacion/init.sql` | Schema de la base de datos aislada `facturacion_db` (Database per Service) |
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
| `DATABASE_URL` (mayoría de módulos) | `postgresql+asyncpg://admin:admin123@db-global:5432/asdf_db` |
| `DATABASE_URL` (`ms-operacion`) | `postgresql+asyncpg://admin:admin123@db-operacion:5432/operacion_db` |
| `DATABASE_URL` (`ms-facturacion`) | `postgresql+asyncpg://admin:admin123@db-facturacion:5432/facturacion_db` |
| `JWT_SECRET` | `super-secret-key-123` |
| `VITE_API_URL` | `/api/v1` (inyectado en build de los frontends; Nginx lo proxifica) |

## Flujo de autenticación (a nivel gateway)

1. `POST /api/v1/administracion/login` es la única ruta pública (además de `/health` del watchdog).
2. Nginx intercepta cada request protegida con `auth_request /_auth_check` → proxifica a `ms-middleware:8009/validate`.
3. El middleware valida el JWT y retorna `X-User-ID`, `X-User-Role`, `X-User-Email` como headers, que Nginx pasa al microservicio destino.

## Base de datos: Database per Service

El Hub empezó como una única base de datos compartida (`asdf_db`). Como primer paso hacia una arquitectura de microservicios con persistencia realmente independiente, **`modulo_operacion` y `modulo_facturacion` migraron a su propia base de datos PostgreSQL aislada**, cada una en su propio contenedor:

| Base de datos | Contenedor | Módulo dueño | Tablas |
|---|---|---|---|
| `asdf_db` (compartida) | `db-global` | RRHH, Mantención, Acreditación, Bodega, Prevención, Administración | `personal`, `personal_historico`, `vehiculos`, `mantenciones*`, `ordenes_trabajo`, `ot_repuestos`, `reportes`, `clientes`, `requerimientos`, `acreditaciones`, `productos`, `ingresos_bodega`, `solicitudes_bodega`, `incidentes`, `usuarios` |
| `operacion_db` (aislada) | `db-operacion` | `modulo_operacion` | `viajes` |
| `facturacion_db` (aislada) | `db-facturacion` | `modulo_facturacion` | `facturas` |

### Acceso desde DBeaver (host)

Cada Postgres aislado publica su puerto al host, igual que `db-global`:

| Base de datos | Host | Puerto | Usuario | Password | Database |
|---|---|---|---|---|---|
| `asdf_db` (compartida) | `localhost` | `5432` | `admin` | `admin123` | `asdf_db` |
| `operacion_db` (aislada) | `localhost` | `5433` | `admin` | `admin123` | `operacion_db` |
| `facturacion_db` (aislada) | `localhost` | `5434` | `admin` | `admin123` | `facturacion_db` |

En DBeaver: **New Database Connection → PostgreSQL**, usar el host/puerto/usuario/password/database de la fila correspondiente. Con el stack levantado (`docker-compose up`), basta una conexión por base — no comparten puerto, así que pueden estar las tres abiertas a la vez sin colisión.

**¿Por qué estos dos primero?** Ninguna de las dos tablas (`viajes`, `facturas`) tiene foreign keys hacia otros módulos ni dependía de llamadas HTTP cruzadas — son los candidatos de menor acoplamiento del sistema. Son además, en el roadmap del proyecto, el par publisher/consumer del futuro flujo de eventos `viaje.completado` (RabbitMQ), por lo que aislar su persistencia ahora deja la independencia de datos demostrada antes de sumar mensajería asíncrona.

**Lo que NO cambia para el resto del stack:** Nginx sigue ruteando `/api/v1/operacion/*` y `/api/v1/facturacion/*` exactamente igual (por nombre de contenedor del microservicio, nunca por su base de datos). El frontend tampoco se ve afectado — solo cambió el `DATABASE_URL` interno de esos dos microservicios.

```mermaid
flowchart TB
    subgraph Frontends["Frontends React (Vite)"]
        FE[front_modulo_*]
    end

    FE --> NGINX["Nginx Gateway :8080"]
    NGINX -- "auth_request /_auth_check" --> MW["ms-middleware :8009<br/>(valida JWT)"]
    NGINX --> MSOP["ms-operacion :8000"]
    NGINX --> MSFACT["ms-facturacion :8000"]
    NGINX --> MSOTROS["resto de ms-* :8000<br/>(rrhh, mantencion, bodega,<br/>acreditacion, prevencion, administracion)"]

    MSOP --> DBOP[("db-operacion<br/>operacion_db")]
    MSFACT --> DBFACT[("db-facturacion<br/>facturacion_db")]
    MSOTROS --> DBGLOBAL[("db-global<br/>asdf_db")]
```

**pg_cron:** ejecuta `snapshot_personal_diario()` cada día a las 23:59 en `db-global`, copiando todos los registros de `personal` a `personal_historico` (auditoría histórica). Las bases de datos aisladas no usan pg_cron — no lo necesitan.

No hay migraciones — el schema se crea con `init.sql` (montado en `docker-entrypoint-initdb.d`) y reforzado por `Base.metadata.create_all()` al arrancar cada microservicio (schema-on-startup).
