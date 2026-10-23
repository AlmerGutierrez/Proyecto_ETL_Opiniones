-- =====================================================================
-- Vistas
-- =====================================================================
USE opiniones_clientes;

CREATE OR REPLACE VIEW v_opiniones_completas AS
SELECT o.IdOpinion, o.TipoOrigen, o.IdOrigen, o.Fecha, o.Comentario,
       c.IdCliente, COALESCE(c.Nombre, 'Anonimo') AS Cliente,
       p.IdProducto, p.Nombre AS Producto, p.Categoria,
       f.IdFuente, f.TipoFuente,
       oe.Clasificacion, oe.PuntajeSatisfaccion, os.Canal, ow.Rating
FROM opinion o
JOIN producto p      ON p.IdProducto = o.IdProducto
JOIN fuente_datos f  ON f.IdFuente   = o.IdFuente
LEFT JOIN cliente c  ON c.IdCliente  = o.IdCliente
LEFT JOIN opinion_encuesta oe ON oe.IdOpinion = o.IdOpinion
LEFT JOIN opinion_social   os ON os.IdOpinion = o.IdOpinion
LEFT JOIN opinion_web      ow ON ow.IdOpinion = o.IdOpinion;

CREATE OR REPLACE VIEW v_resumen_por_producto AS
SELECT p.IdProducto, p.Nombre AS Producto, p.Categoria,
       COUNT(o.IdOpinion)                         AS TotalOpiniones,
       COALESCE(SUM(o.TipoOrigen = 'Encuesta'),0) AS Encuestas,
       COALESCE(SUM(o.TipoOrigen = 'Social'),0)   AS Sociales,
       COALESCE(SUM(o.TipoOrigen = 'Web'),0)      AS Web,
       ROUND(AVG(ow.Rating), 2)                   AS RatingPromedioWeb,
       ROUND(AVG(oe.PuntajeSatisfaccion), 2)      AS PuntajePromedioEncuesta
FROM producto p
LEFT JOIN opinion o           ON o.IdProducto = p.IdProducto
LEFT JOIN opinion_web ow      ON ow.IdOpinion = o.IdOpinion
LEFT JOIN opinion_encuesta oe ON oe.IdOpinion = o.IdOpinion
GROUP BY p.IdProducto, p.Nombre, p.Categoria;

CREATE OR REPLACE VIEW v_resumen_por_origen AS
SELECT TipoOrigen, COUNT(*) AS Total,
       SUM(IdCliente IS NULL) AS Anonimas,
       MIN(Fecha) AS PrimeraFecha, MAX(Fecha) AS UltimaFecha
FROM opinion
GROUP BY TipoOrigen;
