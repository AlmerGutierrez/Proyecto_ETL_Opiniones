-- =====================================================================
-- Consultas de validación de la carga y de la integridad referencial
-- =====================================================================
USE opiniones_clientes;

-- 1) Registros cargados por tabla (procedimiento almacenado)
CALL sp_resumen_carga();

-- 2) Integridad referencial: opiniones con cliente informado que no existe en cliente (esperado: 0 filas)
SELECT COUNT(*) AS OpinionesConClienteInexistente
FROM opinion o
LEFT JOIN cliente c ON c.IdCliente = o.IdCliente
WHERE o.IdCliente IS NOT NULL AND c.IdCliente IS NULL;

-- 3) Integridad referencial: opiniones cuyo producto o fuente no existe (esperado: 0 filas)
SELECT COUNT(*) AS OpinionesConProductoOFuenteInexistente
FROM opinion o
LEFT JOIN producto p     ON p.IdProducto = o.IdProducto
LEFT JOIN fuente_datos f ON f.IdFuente   = o.IdFuente
WHERE p.IdProducto IS NULL OR f.IdFuente IS NULL;

-- 4) Especialización total y disjunta: cada opinión tiene EXACTAMENTE un subtipo (esperado: 0 filas)
SELECT COUNT(*) AS OpinionesSinSubtipoUnico
FROM (
    SELECT o.IdOpinion,
           (oe.IdOpinion IS NOT NULL) + (os.IdOpinion IS NOT NULL) + (ow.IdOpinion IS NOT NULL) AS Subtipos
    FROM opinion o
    LEFT JOIN opinion_encuesta oe ON oe.IdOpinion = o.IdOpinion
    LEFT JOIN opinion_social   os ON os.IdOpinion = o.IdOpinion
    LEFT JOIN opinion_web      ow ON ow.IdOpinion = o.IdOpinion
) t
WHERE Subtipos <> 1;

-- 5) Coherencia: TipoOrigen coincide con la subtabla donde está el detalle (esperado: 0 filas)
SELECT COUNT(*) AS OpinionesConTipoIncoherente
FROM opinion o
LEFT JOIN opinion_encuesta oe ON oe.IdOpinion = o.IdOpinion
LEFT JOIN opinion_social   os ON os.IdOpinion = o.IdOpinion
LEFT JOIN opinion_web      ow ON ow.IdOpinion = o.IdOpinion
WHERE (o.TipoOrigen = 'Encuesta' AND oe.IdOpinion IS NULL)
   OR (o.TipoOrigen = 'Social'   AND os.IdOpinion IS NULL)
   OR (o.TipoOrigen = 'Web'      AND ow.IdOpinion IS NULL);

-- 6) Duplicados: no existe más de una opinión con el mismo (TipoOrigen, IdOrigen) (esperado: 0 filas)
SELECT COUNT(*) AS GruposDuplicados
FROM (SELECT 1 FROM opinion GROUP BY TipoOrigen, IdOrigen HAVING COUNT(*) > 1) d;

-- 7) Transformación de IDs y anónimos: comentarios sociales sin cliente (esperado: 88 en este dataset)
SELECT COUNT(*) AS ComentariosAnonimos FROM opinion WHERE TipoOrigen = 'Social' AND IdCliente IS NULL;

-- 8) Cuadre archivo vs base: insertadas por origen frente a lo leído (6 + 200 + 200)
SELECT * FROM v_resumen_por_origen;

-- 9) Rechazos registrados en la bitácora, por archivo y motivo
SELECT Archivo, TipoError, Campo, COUNT(*) AS Registros
FROM etl_rechazo WHERE IdEjecucion = (SELECT MIN(IdEjecucion) FROM etl_rechazo)
GROUP BY Archivo, TipoError, Campo ORDER BY Archivo;

-- 10) Vista de negocio: opiniones completas de un cliente (procedimiento + vista)
CALL sp_opiniones_por_cliente(7);
