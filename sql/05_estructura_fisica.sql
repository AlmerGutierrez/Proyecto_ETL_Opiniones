-- =====================================================================
-- Evidencia de la estructura física (equivale a "Database Properties > Files" de SQL Server)
-- =====================================================================

-- 1) Tablespaces: archivo físico, tamaño y crecimiento
SELECT ts.NAME AS Tablespace, f.FILE_NAME AS ArchivoFisico,
       ROUND(ts.FILE_SIZE/1024/1024, 1) AS TamanoMB,
       ROUND(ts.AUTOEXTEND_SIZE/1024/1024, 1) AS CrecimientoMB
FROM information_schema.INNODB_TABLESPACES ts
JOIN information_schema.FILES f ON f.TABLESPACE_NAME = ts.NAME
WHERE ts.NAME LIKE 'ts\_%';

-- 2) En qué tablespace quedó cada tabla
SELECT SUBSTRING_INDEX(t.NAME, '/', -1) AS Tabla, ts.NAME AS Tablespace
FROM information_schema.INNODB_TABLES t
JOIN information_schema.INNODB_TABLESPACES ts ON ts.SPACE = t.SPACE
WHERE t.NAME LIKE 'opiniones\_clientes/%'
ORDER BY ts.NAME, Tabla;

-- 3) Carpeta de logs y carpetas conocidas por InnoDB
SHOW VARIABLES WHERE Variable_name IN
  ('datadir', 'innodb_directories', 'innodb_log_group_home_dir', 'log_bin_basename', 'log_error');
