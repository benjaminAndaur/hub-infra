-- Tabla de Personal para el MS de RRHH
CREATE TABLE IF NOT EXISTS personal (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nombre2 VARCHAR(100),
    apellido1 VARCHAR(100) NOT NULL,
    apellido2 VARCHAR(100),
    cargo VARCHAR(100) NOT NULL,
    rut VARCHAR(20) UNIQUE NOT NULL,
    base VARCHAR(100) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    motivo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice de rendimiento
CREATE INDEX idx_rut_personal ON personal(rut);

-- Tabla de Histórico de Personal (snapshot diario)
CREATE TABLE IF NOT EXISTS personal_historico (
    id SERIAL PRIMARY KEY,
    personal_id INT NOT NULL,
    nombre VARCHAR(100),
    nombre2 VARCHAR(100),
    apellido1 VARCHAR(100),
    apellido2 VARCHAR(100),
    cargo VARCHAR(100),
    rut VARCHAR(20),
    base VARCHAR(100),
    estado BOOLEAN,
    motivo TEXT,
    fecha_snapshot DATE NOT NULL
);

-- Índices de rendimiento
CREATE INDEX idx_historico_personal_id ON personal_historico(personal_id);
CREATE INDEX idx_historico_fecha ON personal_historico(fecha_snapshot);

-- Función: snapshot diario del personal a personal_historico
CREATE OR REPLACE FUNCTION snapshot_personal_diario()
RETURNS void AS $$
BEGIN
    INSERT INTO personal_historico
        (personal_id, nombre, nombre2, apellido1, apellido2,
         cargo, rut, base, estado, motivo, fecha_snapshot)
    SELECT
        id, nombre, nombre2, apellido1, apellido2,
        cargo, rut, base, estado, motivo, CURRENT_DATE
    FROM personal;
END;
$$ LANGUAGE plpgsql;

-- pg_cron: programar snapshot a las 23:59 todos los días
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'snapshot-personal-diario',
    '59 23 * * *',
    'SELECT snapshot_personal_diario()'
);

-- Población de datos para Personal
INSERT INTO personal (nombre, apellido1, cargo, rut, base) VALUES 
('Juan', 'Perez', 'Chofer', '11111111-1', 'Lampa'),
('Maria', 'Gomez', 'Administrativo', '22222222-2', 'Santiago'),
('Carlos', 'Lopez', 'Mecanico', '33333333-3', 'Lampa'),
('Ana', 'Martinez', 'Prevencionista', '44444444-4', 'Santiago')
ON CONFLICT (rut) DO NOTHING;

-- TABLAS Y POBLACIÓN DE DATOS PARA OTROS MÓDULOS

-- Bodega: Productos
CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    precio FLOAT NOT NULL,
    stock INT DEFAULT 0 NOT NULL
);

INSERT INTO productos (nombre, descripcion, precio, stock) VALUES
('Aceite Motor 10W40', 'Tambor 200L', 250000, 10),
('Neumatico 295/80R22.5', 'Direccional', 180000, 24),
('Filtro de Aire', 'Para camion Scania', 45000, 50),
('Pastillas de Freno', 'Kit completo', 80000, 15)
ON CONFLICT DO NOTHING;

-- Bodega: Ingresos de Bodega
CREATE TABLE IF NOT EXISTS ingresos_bodega (
    id SERIAL PRIMARY KEY,
    usuario_entrega VARCHAR(150),
    usuario_recepcion VARCHAR(150),
    tipo_doc_origen VARCHAR(100),
    tipo_doc_recepcion VARCHAR(100),
    n_documento VARCHAR(100),
    fecha_requerimiento DATE,
    descripcion VARCHAR(500),
    n_oc VARCHAR(100),
    n_salida VARCHAR(100)
);

INSERT INTO ingresos_bodega (usuario_entrega, usuario_recepcion, tipo_doc_origen, tipo_doc_recepcion, n_documento, fecha_requerimiento, descripcion, n_oc) VALUES
('Proveedor XYZ', 'Vicente Parada', 'Orden de Compra', 'Guia de Despacho', 'GD-1001', '2026-04-20', 'Ingreso de repuestos varios', 'OC-5001'),
('Ferreteria Industrial', 'Luciano Quintanilla', 'Factura', 'Guia de Despacho Interna', 'F-8899', '2026-04-25', 'Herramientas menores', 'OC-5002'),
('Distribuidora Neumaticos', 'Vicente Parada', 'Orden de Compra', 'Guia de Despacho', 'GD-1050', '2026-04-28', 'Set de neumaticos nuevos', 'OC-5003')
ON CONFLICT DO NOTHING;

-- Nota: la tabla "facturas" vive en su propia base de datos aislada
-- (ver hub-infra/db_facturacion/init.sql) — Database per Service.

-- Prevención: Incidentes
CREATE TABLE IF NOT EXISTS incidentes (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descripcion VARCHAR(500),
    nivel_gravedad VARCHAR(50) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO incidentes (titulo, descripcion, nivel_gravedad) VALUES
('Derrame de aceite', 'Derrame menor en taller de Lampa', 'Baja'),
('Casi colision en ruta', 'Camion esquivo vehiculo particular cerca de peaje', 'Alta'),
('Corte en mano', 'Mecanico se corto con pieza metalica', 'Media'),
('Extintor vencido', 'Se detecto extintor vencido en bodega principal', 'Baja')
ON CONFLICT DO NOTHING;

-- Bodega: Solicitudes de Bodega
CREATE TABLE IF NOT EXISTS solicitudes_bodega (
    id BIGSERIAL PRIMARY KEY,
    area_solicitante VARCHAR(100) NOT NULL,
    usuario_solicitante VARCHAR(150) NOT NULL,
    fecha_solicitud TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(50) NOT NULL DEFAULT 'Pendiente',
    detalles_json JSON NOT NULL DEFAULT '[]',
    comentarios VARCHAR(500)
);

INSERT INTO solicitudes_bodega (area_solicitante, usuario_solicitante, estado, detalles_json, comentarios) VALUES
('Mantencion', 'Carlos Lopez', 'Pendiente', '[{"producto_id": 1, "cantidad": 2}]', 'Urgente para camion Scania'),
('Operaciones', 'Maria Gomez', 'Aprobada', '[{"producto_id": 3, "cantidad": 5}]', NULL)
ON CONFLICT DO NOTHING;

-- Mantención: Vehículos
CREATE TABLE IF NOT EXISTS vehiculos (
    id BIGSERIAL PRIMARY KEY,
    patente VARCHAR(50) UNIQUE NOT NULL,
    modelo VARCHAR(100),
    color VARCHAR(50),
    numero_interno VARCHAR(50),
    device_id BIGINT,
    estado VARCHAR(50) NOT NULL DEFAULT 'Disponible',
    notas TEXT
);

CREATE INDEX idx_vehiculos_patente ON vehiculos(patente);

INSERT INTO vehiculos (patente, modelo, color, numero_interno, estado) VALUES
('AB-CD-12', 'Scania R450', 'Blanco', 'T-01', 'Disponible'),
('EF-GH-34', 'Volvo FH16', 'Rojo', 'T-02', 'Disponible'),
('IJ-KL-56', 'Mercedes Actros', 'Azul', 'T-03', 'BLOQUEADO POR MANTENCIÓN PREVENTIVA')
ON CONFLICT (patente) DO NOTHING;

-- Mantención: Templates de mantención
CREATE TABLE IF NOT EXISTS mantenciones_template (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(500),
    tareas_json JSON,
    repuestos_json_default JSON
);

INSERT INTO mantenciones_template (nombre, descripcion, tareas_json, repuestos_json_default) VALUES
('Mantención Preventiva 10.000km', 'Revisión y cambio de fluidos cada 10.000km', '["Cambio de aceite", "Revisión de frenos", "Revisión de neumáticos"]', '[{"producto_id": 1, "cantidad": 1}]'),
('Mantención Preventiva 50.000km', 'Mantención mayor cada 50.000km', '["Cambio de filtros", "Revisión de suspensión", "Alineación"]', '[{"producto_id": 3, "cantidad": 2}]')
ON CONFLICT DO NOTHING;

-- Mantención: Mantenciones
CREATE TABLE IF NOT EXISTS mantenciones (
    id BIGSERIAL PRIMARY KEY,
    vehiculo_id BIGINT NOT NULL REFERENCES vehiculos(id) ON DELETE CASCADE,
    mecanico_id BIGINT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ingreso TIMESTAMP,
    fecha_salida TIMESTAMP,
    fecha_programada TIMESTAMP,
    odometro BIGINT,
    tareas TEXT,
    estado VARCHAR(50) NOT NULL DEFAULT 'Pendiente'
);

CREATE INDEX idx_mantenciones_vehiculo_id ON mantenciones(vehiculo_id);
CREATE INDEX idx_mantenciones_estado ON mantenciones(estado);

INSERT INTO mantenciones (vehiculo_id, mecanico_id, tipo, fecha_programada, estado) VALUES
(3, 3, 'Preventiva', CURRENT_TIMESTAMP, 'En Progreso')
ON CONFLICT DO NOTHING;

-- Mantención: Órdenes de Trabajo
CREATE TABLE IF NOT EXISTS ordenes_trabajo (
    id BIGSERIAL PRIMARY KEY,
    mantencion_id BIGINT NOT NULL REFERENCES mantenciones(id) ON DELETE CASCADE,
    mecanico_id BIGINT NOT NULL,
    estado VARCHAR(50) NOT NULL DEFAULT 'Abierta',
    fecha_inicio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMP
);

CREATE INDEX idx_ot_mantencion_id ON ordenes_trabajo(mantencion_id);

INSERT INTO ordenes_trabajo (mantencion_id, mecanico_id, estado) VALUES
(1, 3, 'Abierta')
ON CONFLICT DO NOTHING;

-- Mantención: Repuestos usados en Órdenes de Trabajo
CREATE TABLE IF NOT EXISTS ot_repuestos (
    id BIGSERIAL PRIMARY KEY,
    ot_id BIGINT NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
    producto_id BIGINT NOT NULL,
    cantidad_solicitada BIGINT NOT NULL DEFAULT 1,
    cantidad_usada BIGINT NOT NULL DEFAULT 0,
    cantidad_devuelta BIGINT NOT NULL DEFAULT 0,
    estado_devolucion VARCHAR(50) NOT NULL DEFAULT 'Ninguna'
);

CREATE INDEX idx_ot_repuestos_ot_id ON ot_repuestos(ot_id);

INSERT INTO ot_repuestos (ot_id, producto_id, cantidad_solicitada) VALUES
(1, 1, 2)
ON CONFLICT DO NOTHING;

-- Mantención: Reportes GPS (telemetría de vehículos)
CREATE TABLE IF NOT EXISTS reportes (
    report_id TEXT PRIMARY KEY,
    sequential_id BIGINT,
    report_date TIMESTAMPTZ,
    input_date TIMESTAMPTZ,
    device_id BIGINT,
    holder_id BIGINT,
    asset_id TEXT,
    asset_name TEXT,
    event_id INT,
    event_name TEXT,
    gps_validity INT,
    gps_satellites INT,
    gps_dop FLOAT,
    latitude FLOAT,
    longitude FLOAT,
    location TEXT,
    area_type TEXT,
    speed FLOAT,
    heading INT,
    odometer FLOAT,
    hourmeter FLOAT,
    total_fuel_used FLOAT,
    obc_hourmeter FLOAT,
    obc_odometer FLOAT,
    parameter_value TEXT,
    parameter_id INT,
    parameter_name TEXT,
    ralenti_band_time BIGINT,
    yellow_band_time BIGINT,
    efficient_handling_band_time BIGINT,
    red_band_time BIGINT,
    load_over_75_band_time BIGINT,
    inefficient_cruise_control_band_time BIGINT,
    engine_braking_time BIGINT,
    cartography_limit_speed FLOAT,
    gps_speed FLOAT,
    driver_name TEXT,
    driver_last_name TEXT,
    driver_document_type TEXT,
    driver_document_number TEXT,
    ignition BOOLEAN,
    ignition_date TIMESTAMPTZ,
    fecha_registro TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_reportes_device_id ON reportes(device_id);

INSERT INTO reportes (report_id, device_id, asset_name, event_name, latitude, longitude, speed) VALUES
('RPT-0001', 1, 'T-01', 'Encendido', -33.4489, -70.6693, 0),
('RPT-0002', 1, 'T-01', 'En Movimiento', -33.4500, -70.6700, 65.5)
ON CONFLICT (report_id) DO NOTHING;

-- Nota: la tabla "viajes" vive en su propia base de datos aislada
-- (ver hub-infra/db_operacion/init.sql) — Database per Service.

-- Acreditación: Clientes
CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    rut VARCHAR(20) UNIQUE,
    contacto VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_clientes_rut ON clientes(rut);

INSERT INTO clientes (nombre, rut, contacto) VALUES
('Minera Los Andes', '76111111-1', 'contacto@mineralosandes.cl'),
('Constructora del Sur', '76222222-2', 'contacto@constructorasur.cl')
ON CONFLICT (rut) DO NOTHING;

-- Acreditación: Requerimientos
CREATE TABLE IF NOT EXISTS requerimientos (
    id SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES clientes(id),
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    tipo_sujeto VARCHAR(20) NOT NULL CHECK (tipo_sujeto IN ('PERSONAL', 'VEHICULO')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_requerimientos_cliente_id ON requerimientos(cliente_id);

INSERT INTO requerimientos (cliente_id, nombre, descripcion, tipo_sujeto) VALUES
(1, 'Curso de Manejo Defensivo', 'Obligatorio para todo conductor que ingrese a faena', 'PERSONAL'),
(1, 'Revisión Técnica Vigente', 'Vehículo debe contar con revisión técnica al día', 'VEHICULO')
ON CONFLICT DO NOTHING;

-- Acreditación: Acreditaciones
CREATE TABLE IF NOT EXISTS acreditaciones (
    id SERIAL PRIMARY KEY,
    requerimiento_id INT REFERENCES requerimientos(id),
    sujeto_id INT NOT NULL,
    fecha_emision DATE,
    fecha_vencimiento DATE,
    link_documento VARCHAR(500),
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_acreditaciones_requerimiento_id ON acreditaciones(requerimiento_id);
CREATE INDEX idx_acreditaciones_sujeto_id ON acreditaciones(sujeto_id);

INSERT INTO acreditaciones (requerimiento_id, sujeto_id, fecha_emision, fecha_vencimiento, estado) VALUES
(1, 1, '2026-01-15', '2027-01-15', TRUE),
(2, 1, '2026-02-01', '2026-08-01', TRUE)
ON CONFLICT DO NOTHING;

-- Administración: Usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    ultima_conexion TIMESTAMP,
    estado BOOLEAN DEFAULT TRUE,
    permisos JSON DEFAULT '{}'
);

CREATE INDEX idx_usuarios_email ON usuarios(email);

-- Nota: los usuarios de prueba (admin@asdf.cl, rrhh@asdf.cl, etc.) los siembra
-- automáticamente modulo_administracion/src/utils/seeder.py al arrancar
-- (seed_admin_user), generando los password_hash con bcrypt en tiempo de
-- ejecución. No se insertan aquí para no duplicar/contradecir esa lógica.