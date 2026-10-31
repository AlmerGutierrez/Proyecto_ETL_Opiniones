-- =====================================================================
-- Consultas que responden las preguntas del enunciado (Actividad 3.1 - Opiniones)
-- Los porcentajes de sentimiento se calculan sobre las opiniones CLASIFICADAS (sk_sentimiento <> 4),
-- porque los comentarios de redes sociales no traen puntaje.
-- =====================================================================
USE opiniones_dw;

-- 1) Análisis general: total de comentarios y promedio de satisfacción
SELECT SUM(cantidad) AS total_comentarios, ROUND(AVG(puntaje), 2) AS promedio_puntaje, COUNT(puntaje) AS opiniones_con_puntaje
FROM fact_opinion;

-- 2) Comentarios por fuente y canal
SELECT d.tipo_fuente, d.canal, SUM(f.cantidad) AS comentarios
FROM fact_opinion f JOIN dim_fuente d ON d.sk_fuente = f.sk_fuente
GROUP BY d.tipo_fuente, d.canal ORDER BY comentarios DESC;

-- 3) Opiniones por sentimiento y su porcentaje (sobre el total)
SELECT s.nombre AS sentimiento, SUM(f.cantidad) AS comentarios,
       ROUND(100 * SUM(f.cantidad) / SUM(SUM(f.cantidad)) OVER (), 1) AS pct_del_total
FROM fact_opinion f JOIN dim_sentimiento s ON s.sk_sentimiento = f.sk_sentimiento
GROUP BY s.sk_sentimiento, s.nombre ORDER BY s.sk_sentimiento;

-- 4) Porcentaje de positivas, neutras y negativas sobre las opiniones clasificadas
SELECT ROUND(100 * AVG(es_positiva), 1) AS pct_positivas,
       ROUND(100 * AVG(es_neutra), 1)   AS pct_neutras,
       ROUND(100 * AVG(es_negativa), 1) AS pct_negativas
FROM fact_opinion WHERE sk_sentimiento <> 4;

-- 5) Productos con más comentarios (Top 5)
SELECT p.nombre AS producto, p.categoria, SUM(f.cantidad) AS comentarios
FROM fact_opinion f JOIN dim_producto p ON p.sk_producto = f.sk_producto
GROUP BY p.sk_producto, p.nombre, p.categoria ORDER BY comentarios DESC, p.nombre LIMIT 5;

-- 6) Productos con mejor calificación promedio (al menos 5 opiniones con puntaje)
SELECT p.nombre AS producto, ROUND(AVG(f.puntaje), 2) AS promedio_puntaje, COUNT(f.puntaje) AS opiniones_con_puntaje
FROM fact_opinion f JOIN dim_producto p ON p.sk_producto = f.sk_producto
GROUP BY p.sk_producto, p.nombre HAVING COUNT(f.puntaje) >= 5
ORDER BY promedio_puntaje DESC, p.nombre LIMIT 5;

-- 7) Productos con más opiniones negativas (Top 5)
SELECT p.nombre AS producto, SUM(f.es_negativa) AS opiniones_negativas
FROM fact_opinion f JOIN dim_producto p ON p.sk_producto = f.sk_producto
GROUP BY p.sk_producto, p.nombre HAVING SUM(f.es_negativa) > 0
ORDER BY opiniones_negativas DESC, p.nombre LIMIT 5;

-- 8) Porcentaje de satisfacción por producto (positivas / clasificadas), Top 5
SELECT p.nombre AS producto, ROUND(100 * AVG(f.es_positiva), 1) AS pct_satisfaccion, COUNT(*) AS clasificadas
FROM fact_opinion f JOIN dim_producto p ON p.sk_producto = f.sk_producto
WHERE f.sk_sentimiento <> 4
GROUP BY p.sk_producto, p.nombre HAVING COUNT(*) >= 5
ORDER BY pct_satisfaccion DESC, p.nombre LIMIT 5;

-- 9) Tendencia mensual: comentarios y promedio de puntaje por mes
SELECT t.anio, t.mes, t.nombre_mes, SUM(f.cantidad) AS comentarios, ROUND(AVG(f.puntaje), 2) AS promedio_puntaje
FROM fact_opinion f JOIN dim_tiempo t ON t.sk_tiempo = f.sk_tiempo
GROUP BY t.anio, t.mes, t.nombre_mes ORDER BY t.anio, t.mes;

-- 10) Comparativa entre canales: porcentaje de negativas sobre lo clasificado
SELECT d.canal, COUNT(*) AS clasificadas, ROUND(100 * AVG(f.es_negativa), 1) AS pct_negativas
FROM fact_opinion f JOIN dim_fuente d ON d.sk_fuente = f.sk_fuente
WHERE f.sk_sentimiento <> 4 GROUP BY d.canal ORDER BY pct_negativas DESC;

-- 11) Clientes que más comentan (solo identificados)
SELECT c.nombre AS cliente, SUM(f.cantidad) AS comentarios
FROM fact_opinion f JOIN dim_cliente c ON c.sk_cliente = f.sk_cliente
WHERE f.sk_cliente <> 0 GROUP BY c.sk_cliente, c.nombre ORDER BY comentarios DESC, c.nombre LIMIT 5;
