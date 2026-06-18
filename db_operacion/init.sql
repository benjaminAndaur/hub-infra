-- Base de datos aislada de modulo_operacion (Database per Service)

-- Operación: Viajes
CREATE TABLE IF NOT EXISTS viajes (
    id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    estado VARCHAR(50) DEFAULT 'IDA',
    tipo_operativo VARCHAR(50),
    conductor_id INT,
    tracto_id INT,
    rampla_id INT,
    cliente_id INT,
    conductor_nombre VARCHAR(200),
    tracto_patente VARCHAR(20),
    rampla_patente VARCHAR(20),
    cliente_nombre VARCHAR(200),
    servicio VARCHAR(100),
    fecha_carga DATE,
    origen VARCHAR(200),
    fecha_descarga DATE,
    destino VARCHAR(200),
    valor_viaje NUMERIC(12, 2) DEFAULT 0,
    observaciones TEXT,
    pernoctacion BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_viajes_fecha ON viajes(fecha);
CREATE INDEX idx_viajes_conductor_id ON viajes(conductor_id);
CREATE INDEX idx_viajes_tracto_id ON viajes(tracto_id);
CREATE INDEX idx_viajes_rampla_id ON viajes(rampla_id);
CREATE INDEX idx_viajes_cliente_id ON viajes(cliente_id);

INSERT INTO viajes (fecha, estado, tipo_operativo, conductor_id, tracto_id, conductor_nombre, tracto_patente, servicio, origen, destino, valor_viaje) VALUES
('2026-05-01', 'IDA', 'Operativo', 1, 1, 'Juan Perez', 'AB-CD-12', 'Transporte de carga', 'Lampa', 'Antofagasta', 1200000),
('2026-05-03', 'RETORNO', 'Operativo', 1, 1, 'Juan Perez', 'AB-CD-12', 'Transporte de carga', 'Antofagasta', 'Lampa', 1200000)
ON CONFLICT DO NOTHING;
