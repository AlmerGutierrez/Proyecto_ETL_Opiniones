-- =====================================================================
-- Estructura física de archivos (equivalente MySQL a los filegroups de SQL Server)
--
--   C:/Data/OpinionesClientes/Primary/    -> tablespace ts_primary   : tablas maestras (cliente, producto, fuente_datos)
--   C:/Data/OpinionesClientes/Secondary/  -> tablespace ts_secondary : opiniones, subtipos y bitácora del ETL
--   C:/Data/OpinionesClientes/Log/        -> redo log, binary log y error log (se configura en my.ini, ver config/my.ini.ejemplo)
--
-- REQUISITOS (si falla, casi siempre es por alguno de estos):
--   1. MySQL 8.0.23 o superior (AUTOEXTEND_SIZE).
--   2. Las carpetas Primary y Secondary deben existir: MySQL no las crea.
--   3. Esas carpetas deben estar declaradas en innodb_directories (my.ini) y el servicio reiniciado.
--      Si no, aparece: ERROR 3121 The DATAFILE location must be in a known directory.
--   4. El usuario necesita el privilegio CREATE TABLESPACE.
--   5. Para usar otra ruta: reemplazar C:/Data/OpinionesClientes en este archivo (o usar --ruta-fisica en el ETL).
--   6. Ejecutar UNA sola vez: MySQL 8.0 no tiene CREATE TABLESPACE IF NOT EXISTS (el ETL ya lo controla).
-- AUTOEXTEND_SIZE = 64M: el archivo inicia en 64 MB y crece de 64 MB en 64 MB.
-- =====================================================================

CREATE TABLESPACE ts_primary
    ADD DATAFILE 'C:/Data/OpinionesClientes/Primary/ts_primary.ibd'
    AUTOEXTEND_SIZE = 64M
    ENGINE = InnoDB;

CREATE TABLESPACE ts_secondary
    ADD DATAFILE 'C:/Data/OpinionesClientes/Secondary/ts_secondary.ibd'
    AUTOEXTEND_SIZE = 64M
    ENGINE = InnoDB;
