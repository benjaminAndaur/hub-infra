-- Base de datos aislada de modulo_facturacion (Database per Service)

-- Facturación: Facturas
CREATE TABLE IF NOT EXISTS facturas (
    id SERIAL PRIMARY KEY,
    cliente VARCHAR(100) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total FLOAT NOT NULL,
    estado VARCHAR(50) DEFAULT 'Emitida'
);

INSERT INTO facturas (cliente, total, estado) VALUES
('Minera Los Andes', 1500000, 'Pagada'),
('Constructora del Sur', 850000, 'Emitida'),
('Agricola Central', 420000, 'Vencida'),
('Transportes Unidos', 2100000, 'Emitida')
ON CONFLICT DO NOTHING;
