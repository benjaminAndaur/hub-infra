# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Cómo ejecutar el proyecto

**Stack completo (recomendado):**
```bash
docker-compose up --build
```

**Acceso tras el arranque — todo entra por el gateway Nginx en `http://localhost:8080`:**
- Login: `http://localhost:8080/login/`
- RRHH: `http://localhost:8080/rrhh/`
- Mantención: `http://localhost:8080/mantencion/`
- Operación: `http://localhost:8080/operacion/`
- Bodega: `http://localhost:8080/bodega/`
- Acreditación: `http://localhost:8080/acreditacion/`
- Facturación: `http://localhost:8080/facturacion/`
- Prevención: `http://localhost:8080/prevencion/`
- Administración: `http://localhost:8080/`
- Watchdog: `http://localhost:8080/watchdog/`
- pgAdmin: `http://localhost:5050` (`admin@asdf.com` / `admin`)

**Usuarios pre-cargados (seeder):**
| Email | Password | Acceso |
|---|---|---|
| `admin@asdf.cl` | `admin123` | Todos los módulos: edit |
| `rrhh@asdf.cl` | `user123` | rrhh: edit |
| `mantencion@asdf.cl` | `user123` | mantencion: edit, bodega: view |
| `operacion@asdf.cl` | `user123` | operacion: edit, facturacion: view |
| `bodega_visor@asdf.cl` | `user123` | bodega: view |

**Frontend (módulo individual):**
```bash
cd front_modulo_rrhh   # o _mantencion, _acreditacion, _operacion, _bodega, etc.
npm install
npm run dev
```

**Backend (módulo individual):**
```bash
cd modulo_rrhh   # o _mantencion, _acreditacion, _operacion, etc.
pip install -r requirements.txt
# Requiere DATABASE_URL y JWT_SECRET como variables de entorno
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

No hay tests automatizados en el proyecto.

## Variables de entorno

| Variable | Valor en dev |
|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://admin:admin123@db-global:5432/asdf_db` |
| `JWT_SECRET` | `super-secret-key-123` |
| `VITE_API_URL` | `/api/v1` (inyectado en build; Nginx lo proxifica) |

## Arquitectura

**11 módulos de negocio independientes**, cada uno con backend Python/Quart y frontend React/Vite. Todos comparten una sola base de datos PostgreSQL 15. Todo el tráfico entra por un gateway Nginx (`puerto 8080`) que:
1. Sirve los frontends por path (`/rrhh/`, `/mantencion/`, etc.)
2. Enruta las APIs (`/api/v1/*`) al microservicio correspondiente
3. Valida JWT en cada request protegida vía `auth_request` al `ms-middleware`

### Módulos y puertos internos

| Módulo | Backend (interno) | Frontend (interno) | Dominio |
|---|---|---|---|
| `modulo_rrhh` | 8000 | 3000 (`/rrhh/`) | Personal/RRHH |
| `modulo_mantencion` | 8000 | 3000 (`/mantencion/`) | Mantención vehículos |
| `modulo_acreditacion` | 8000 | 3000 (`/acreditacion/`) | Acreditación clientes |
| `modulo_operacion` | 8000 | 3000 (`/operacion/`) | Viajes/Operaciones |
| `modulo_bodega` | 8000 | 3005 (`/bodega/`) | Bodega/Inventario |
| `modulo_facturacion` | 8000 | 3006 (`/facturacion/`) | Facturación |
| `modulo_prevencion` | 8000 | 3002 (`/prevencion/`) | Prevención/Incidentes |
| `modulo_administracion` | **8007** | 3007 (`/`) | Usuarios y permisos |
| `modulo_middleware` | **8009** | — | Validación JWT (interno) |
| `modulo_watchdog` | **8008** | 3002 (`/watchdog/`) | Monitoreo servicios |
| `front_modulo_login` | — | 3008 (`/login/`) | Login |

### Flujo de autenticación

1. Usuario hace POST a `/api/v1/administracion/login` (ruta pública, sin validación JWT)
2. Backend retorna JWT con payload: `{sub, email, rol, permisos: {modulo: "none"|"view"|"edit"}}`
3. Frontend almacena `token` y `userData` en `localStorage`
4. Cada request subsiguiente incluye `Authorization: Bearer {token}`
5. Nginx intercepta con `auth_request /_auth_check` → proxifica a `ms-middleware:8009/validate`
6. Middleware valida el JWT y retorna `X-User-ID`, `X-User-Role`, `X-User-Email` como headers
7. El backend lee esos headers para autorización con `@login_required` + `@require_permission('modulo', 'view'|'edit')`

La única ruta pública en backend es `/api/v1/administracion/login`. El watchdog `/health` también es pública.

### Backend (Python/Quart) — patrón estricto de capas

```
main.py
  └─ @app.before_request: inyecta repo, service y sesión de BD en g{}
src/
  models/
    {entidad}.py          # Pydantic: {Entidad}Create, {Entidad}Update, {Entidad}Response
    {entidad}_db.py       # ORM SQLAlchemy (Base)
  repository/
    {entidad}_repository.py   # Solo consultas async; sin lógica de negocio
  service/
    {entidad}_service.py      # Lógica de negocio; orquesta repositorios
  controller/
    {entidad}_controller.py   # Blueprint Quart; valida Pydantic; llama g.service
  utils/
    auth.py               # Decoradores @login_required y @require_permission
```

Todas las operaciones de BD son asíncronas (SQLAlchemy 2.0 async + asyncpg). Las tablas se crean con `Base.metadata.create_all()` al arrancar. **No hay migraciones** (schema-on-startup).

**Referencias entre módulos:** No hay FK en BD entre tablas de módulos distintos (por diseño). En cambio se guarda el ID externo y el valor denormalizado (ej: `viaje.conductor_id` + `viaje.conductor_nombre`). Esto permite independencia de despliegue.

### Frontend (React/Vite) — patrón por módulo

```
src/
  App.jsx               # Navegación por pestañas (useState); checkModuleAccess() al montar
  components/
    {Entidad}Form.jsx
    {Entidad}List.jsx
    {Entidad}StatusManage.jsx
  services/
    {entidad}Service.js  # Wraps fetch con Authorization: Bearer {token} hacia VITE_API_URL
```

No se usa React Router. La navegación es por `activeTab` → renderizado condicional. Los botones de acción se muestran/ocultan según `permiso === 'edit'`. El componente `Sidebar`, `Header` y `LoginForm` vienen del paquete compartido `shared_components/`.

Al montar, cada `App.jsx` llama `checkModuleAccess('nombre_modulo', '/ruta/')` que lee el JWT del localStorage y redirige si el usuario no tiene permiso.

### Base de datos (PostgreSQL 15, `asdf_db`)

Schema completo en `db_postgres/init.sql`. Módulos y sus tablas principales:

| Módulo | Tablas principales |
|---|---|
| RRHH | `personal`, `personal_historico` |
| Mantención | `vehiculos`, `mantenciones`, `mantenciones_template`, `ordenes_trabajo`, `ot_repuestos` |
| Acreditación | `clientes`, `requerimientos`, `acreditaciones` |
| Operación | `viajes` |
| Bodega | `productos`, `ingresos_bodega` |
| Facturación | `facturas` |
| Prevención | `incidentes` |
| Administración | `usuarios` |

**pg_cron:** Se ejecuta `snapshot_personal_diario()` cada día a las 23:59 para copiar todos los registros de `personal` a `personal_historico` (auditoría histórica).

## El Watchdog (`modulo_watchdog`)

El watchdog es un microservicio Quart en el puerto 8008 que monitorea automáticamente la salud de todos los demás microservicios y los reinicia si fallan.

**Cómo funciona:**

1. Al arrancar, lanza un **thread daemon** (`monitor_loop()`) que se ejecuta en paralelo a la app
2. Cada 30 segundos (`CHECK_INTERVAL_SECONDS`) hace `GET` al endpoint `/health` de cada servicio (timeout 5s)
3. Si la respuesta es 200: resetea el contador de fallos del servicio a 0 → estado `"UP"`
4. Si hay error/timeout: incrementa `failures_count[servicio]` → estado `"DOWN"`
5. Si `failures_count >= 2` (dos checks fallidos consecutivos): llama `container.restart()` vía **Docker API** (`/var/run/docker.sock` montado en el contenedor)
6. El endpoint `GET /status` (protegido, requiere permiso `administracion edit`) devuelve el estado actual de todos los servicios
7. El frontend `front_modulo_watchdog` muestra un dashboard con tarjetas por servicio y auto-refresca cada 5 segundos

**Servicios monitoreados:**
```
ms_middleware, ms_rrhh, ms_mantencion, ms_acreditacion, ms_operacion,
ms_bodega, ms_facturacion, ms_prevencion, ms_administracion
```

El watchdog accede directamente al Docker daemon del host mediante el socket montado (`/var/run/docker.sock`), lo que le permite reiniciar contenedores sin privilegios adicionales. El contador de fallos se resetea en el primer check exitoso (no hay cooldown).

## Lógica de negocio no obvia

**Bloqueo de vehículos por mantención:**
- Al crear una `mantencion` → el `vehiculo.estado` cambia a `"BLOQUEADO POR MANTENCIÓN PREVENTIVA"` o `"BLOQUEADO POR MANTENCIÓN CORRECTIVA"` automáticamente
- Al marcar la mantención como `estado = "Completada"` → el vehículo vuelve a `"Disponible"`
- Esta lógica vive en `MantencionService`, no en el controlador

**Planificador preventivo:**
- `modulo_mantencion` tiene un worker async (`PreventiveService.start_worker()`) que corre en background
- Monitorea templates de mantención y crea automáticamente registros de `mantenciones` cuando se cumplen las condiciones programadas
- El estado se persiste en BD (sobrevive reinicios)

**Permisos granulares:**
- El campo `permisos` en `usuarios` es un JSON: `{"rrhh": "edit", "bodega": "view", "operacion": "none", ...}`
- `"none"` = sin acceso, `"view"` = solo lectura (botones ocultos), `"edit"` = acceso completo
- Los permisos se incluyen en el JWT y se verifican tanto en frontend (UI) como en backend (decorator)
