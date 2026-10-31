-- =====================================================================
-- Carga de la estrella desde la base transaccional (opiniones_clientes)
-- Recarga completa: vacía las tablas y vuelve a poblarlas. Se puede repetir sin duplicar datos.
-- Requisito: haber ejecutado antes el ETL (python main.py) y el script 06.
-- =====================================================================
USE opiniones_dw;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE fact_opinion;
TRUNCATE TABLE dim_tiempo;
TRUNCATE TABLE dim_producto;
TRUNCATE TABLE dim_cliente;
TRUNCATE TABLE dim_fuente;
TRUNCATE TABLE dim_sentimiento;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------- Catálogos fijos ----------
INSERT INTO dim_sentimiento (sk_sentimiento, nombre, rango_puntaje) VALUES
    (1, 'Positiva', '4-5'),
    (2, 'Neutra', '3'),
    (3, 'Negativa', '1-2'),
    (4, 'Sin clasificar', 'Sin puntaje');

INSERT INTO dim_fuente (sk_fuente, tipo_fuente, canal, ambito) VALUES
    (1, 'Encuesta', 'EncuestaInterna', 'Interno'),
    (2, 'Reseña web', 'SitioWeb', 'Interno'),
    (3, 'Red social', 'Facebook', 'Externo'),
    (4, 'Red social', 'Instagram', 'Externo'),
    (5, 'Red social', 'Twitter', 'Externo');

-- ---------- Calendario (ajustar el rango si llegan fechas fuera de él: la clave foránea lo impediría) ----------
INSERT INTO dim_tiempo (sk_tiempo, fecha, anio, trimestre, mes, nombre_mes, dia, dia_semana)
WITH RECURSIVE d AS (
    SELECT DATE('2024-01-01') AS f
    UNION ALL
    SELECT f + INTERVAL 1 DAY FROM d WHERE f < DATE('2025-12-31')
)
SELECT CAST(DATE_FORMAT(f, '%Y%m%d') AS UNSIGNED), f, YEAR(f), QUARTER(f), MONTH(f),
       ELT(MONTH(f), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'),
       DAY(f),
       ELT(WEEKDAY(f) + 1, 'Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo')
FROM d;

-- ---------- Dimensiones desde la base transaccional ----------
INSERT INTO dim_producto (sk_producto, nombre, categoria)
SELECT IdProducto, Nombre, Categoria FROM opiniones_clientes.producto;

INSERT INTO dim_cliente (sk_cliente, nombre) VALUES (0, 'Anónimo');
INSERT INTO dim_cliente (sk_cliente, nombre)
SELECT IdCliente, Nombre FROM opiniones_clientes.cliente;

-- ---------- Hechos ----------
-- Sentimiento: encuestas = clasificación original; reseñas web = Rating (1-2 negativa, 3 neutra, 4-5 positiva);
-- redes sociales = Sin clasificar.
INSERT INTO fact_opinion (id_opinion, id_origen, sk_tiempo, sk_producto, sk_cliente, sk_fuente,
                          sk_sentimiento, puntaje, es_positiva, es_neutra, es_negativa, cantidad)
SELECT x.id_opinion, x.id_origen, x.sk_tiempo, x.sk_producto, x.sk_cliente, x.sk_fuente,
       x.sk_sentimiento, x.puntaje,
       (x.sk_sentimiento = 1), (x.sk_sentimiento = 2), (x.sk_sentimiento = 3), 1
FROM (
    SELECT o.IdOpinion AS id_opinion,
           o.IdOrigen  AS id_origen,
           CAST(DATE_FORMAT(o.Fecha, '%Y%m%d') AS UNSIGNED) AS sk_tiempo,
           o.IdProducto AS sk_producto,
           COALESCE(o.IdCliente, 0) AS sk_cliente,
           CASE o.TipoOrigen WHEN 'Encuesta' THEN 1 WHEN 'Web' THEN 2 ELSE f.sk_fuente END AS sk_fuente,
           CASE
               WHEN o.TipoOrigen = 'Encuesta' THEN CASE oe.Clasificacion WHEN 'Positiva' THEN 1 WHEN 'Neutra' THEN 2 ELSE 3 END
               WHEN o.TipoOrigen = 'Web'      THEN CASE WHEN ow.Rating >= 4 THEN 1 WHEN ow.Rating = 3 THEN 2 ELSE 3 END
               ELSE 4
           END AS sk_sentimiento,
           COALESCE(oe.PuntajeSatisfaccion, ow.Rating) AS puntaje
    FROM opiniones_clientes.opinion o
    LEFT JOIN opiniones_clientes.opinion_encuesta oe ON oe.IdOpinion = o.IdOpinion
    LEFT JOIN opiniones_clientes.opinion_social   os ON os.IdOpinion = o.IdOpinion
    LEFT JOIN opiniones_clientes.opinion_web      ow ON ow.IdOpinion = o.IdOpinion
    LEFT JOIN dim_fuente f ON f.canal = os.Canal
) x;
