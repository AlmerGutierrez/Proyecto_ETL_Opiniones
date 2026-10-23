-- =====================================================================
-- Procedimientos almacenados
-- Cada sp_registrar_* inserta la superclase (opinion) y su subtipo.
-- La transaccion la controla el ETL (commit o rollback por fila).
-- =====================================================================
USE opiniones_clientes;

DROP PROCEDURE IF EXISTS sp_registrar_opinion_encuesta;
DROP PROCEDURE IF EXISTS sp_registrar_opinion_social;
DROP PROCEDURE IF EXISTS sp_registrar_opinion_web;
DROP PROCEDURE IF EXISTS sp_opiniones_por_cliente;
DROP PROCEDURE IF EXISTS sp_resumen_carga;

DELIMITER //

CREATE PROCEDURE sp_registrar_opinion_encuesta(
    IN p_origen VARCHAR(20), IN p_cliente INT, IN p_producto INT, IN p_fuente VARCHAR(10),
    IN p_fecha DATE, IN p_comentario TEXT, IN p_clasificacion VARCHAR(10), IN p_puntaje TINYINT)
BEGIN
    INSERT INTO opinion (IdOrigen, IdCliente, IdProducto, IdFuente, Fecha, Comentario, TipoOrigen)
    VALUES (p_origen, p_cliente, p_producto, p_fuente, p_fecha, p_comentario, 'Encuesta');
    INSERT INTO opinion_encuesta (IdOpinion, Clasificacion, PuntajeSatisfaccion)
    VALUES (LAST_INSERT_ID(), p_clasificacion, p_puntaje);
END //

CREATE PROCEDURE sp_registrar_opinion_social(
    IN p_origen VARCHAR(20), IN p_cliente INT, IN p_producto INT, IN p_fuente VARCHAR(10),
    IN p_fecha DATE, IN p_comentario TEXT, IN p_canal VARCHAR(20))
BEGIN
    INSERT INTO opinion (IdOrigen, IdCliente, IdProducto, IdFuente, Fecha, Comentario, TipoOrigen)
    VALUES (p_origen, p_cliente, p_producto, p_fuente, p_fecha, p_comentario, 'Social');
    INSERT INTO opinion_social (IdOpinion, Canal) VALUES (LAST_INSERT_ID(), p_canal);
END //

CREATE PROCEDURE sp_registrar_opinion_web(
    IN p_origen VARCHAR(20), IN p_cliente INT, IN p_producto INT, IN p_fuente VARCHAR(10),
    IN p_fecha DATE, IN p_comentario TEXT, IN p_rating TINYINT)
BEGIN
    INSERT INTO opinion (IdOrigen, IdCliente, IdProducto, IdFuente, Fecha, Comentario, TipoOrigen)
    VALUES (p_origen, p_cliente, p_producto, p_fuente, p_fecha, p_comentario, 'Web');
    INSERT INTO opinion_web (IdOpinion, Rating) VALUES (LAST_INSERT_ID(), p_rating);
END //

CREATE PROCEDURE sp_opiniones_por_cliente(IN p_cliente INT)
BEGIN
    SELECT * FROM v_opiniones_completas WHERE IdCliente = p_cliente ORDER BY Fecha;
END //

CREATE PROCEDURE sp_resumen_carga()
BEGIN
    SELECT 'cliente' AS Tabla, COUNT(*) AS Registros FROM cliente
    UNION ALL SELECT 'producto', COUNT(*) FROM producto
    UNION ALL SELECT 'fuente_datos', COUNT(*) FROM fuente_datos
    UNION ALL SELECT 'opinion', COUNT(*) FROM opinion
    UNION ALL SELECT 'opinion_encuesta', COUNT(*) FROM opinion_encuesta
    UNION ALL SELECT 'opinion_social', COUNT(*) FROM opinion_social
    UNION ALL SELECT 'opinion_web', COUNT(*) FROM opinion_web
    UNION ALL SELECT 'etl_rechazo', COUNT(*) FROM etl_rechazo;
END //

DELIMITER ;
