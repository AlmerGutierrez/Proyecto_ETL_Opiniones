-- =====================================================================
-- Sistema de Análisis de Opiniones de Clientes - Esquema (MySQL 8 / MariaDB 10.5+)
-- =====================================================================
CREATE DATABASE IF NOT EXISTS opiniones_clientes
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE opiniones_clientes;

-- ---------- Tablas maestras (tablespace ts_primary, carpeta Primary) ----------
CREATE TABLE IF NOT EXISTS cliente (
    IdCliente   INT PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    UNIQUE KEY uq_cliente_email (Email)
) ENGINE=InnoDB TABLESPACE=ts_primary;

CREATE TABLE IF NOT EXISTS producto (
    IdProducto  INT PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL,
    Categoria   VARCHAR(50) NOT NULL
) ENGINE=InnoDB TABLESPACE=ts_primary;

CREATE TABLE IF NOT EXISTS fuente_datos (
    IdFuente    VARCHAR(10) PRIMARY KEY,
    TipoFuente  ENUM('Web', 'CSV', 'Red Social') NOT NULL,
    FechaCarga  DATE NOT NULL
) ENGINE=InnoDB TABLESPACE=ts_primary;

-- ---------- Superclase: opinion (tablespace ts_secondary, carpeta Secondary) ----------
CREATE TABLE IF NOT EXISTS opinion (
    IdOpinion    INT AUTO_INCREMENT PRIMARY KEY,
    IdOrigen     VARCHAR(20) NOT NULL,
    IdCliente    INT NULL,
    IdProducto   INT NOT NULL,
    IdFuente     VARCHAR(10) NOT NULL,
    Fecha        DATE NOT NULL,
    Comentario   TEXT NOT NULL,
    TipoOrigen   ENUM('Encuesta', 'Social', 'Web') NOT NULL,
    UNIQUE KEY uq_opinion_origen (TipoOrigen, IdOrigen),
    CONSTRAINT fk_opinion_cliente  FOREIGN KEY (IdCliente)  REFERENCES cliente(IdCliente),
    CONSTRAINT fk_opinion_producto FOREIGN KEY (IdProducto) REFERENCES producto(IdProducto),
    CONSTRAINT fk_opinion_fuente   FOREIGN KEY (IdFuente)   REFERENCES fuente_datos(IdFuente)
) ENGINE=InnoDB TABLESPACE=ts_secondary;

-- ---------- Subtipos (PK = FK hacia opinion) ----------
CREATE TABLE IF NOT EXISTS opinion_encuesta (
    IdOpinion            INT PRIMARY KEY,
    Clasificacion        ENUM('Positiva', 'Negativa', 'Neutra') NOT NULL,
    PuntajeSatisfaccion  TINYINT NOT NULL,
    CONSTRAINT ck_encuesta_puntaje CHECK (PuntajeSatisfaccion BETWEEN 1 AND 5),
    CONSTRAINT fk_encuesta_opinion FOREIGN KEY (IdOpinion) REFERENCES opinion(IdOpinion) ON DELETE CASCADE
) ENGINE=InnoDB TABLESPACE=ts_secondary;

CREATE TABLE IF NOT EXISTS opinion_social (
    IdOpinion  INT PRIMARY KEY,
    Canal      ENUM('Facebook', 'Instagram', 'Twitter') NOT NULL,
    CONSTRAINT fk_social_opinion FOREIGN KEY (IdOpinion) REFERENCES opinion(IdOpinion) ON DELETE CASCADE
) ENGINE=InnoDB TABLESPACE=ts_secondary;

CREATE TABLE IF NOT EXISTS opinion_web (
    IdOpinion  INT PRIMARY KEY,
    Rating     TINYINT NOT NULL,
    CONSTRAINT ck_web_rating CHECK (Rating BETWEEN 1 AND 5),
    CONSTRAINT fk_web_opinion FOREIGN KEY (IdOpinion) REFERENCES opinion(IdOpinion) ON DELETE CASCADE
) ENGINE=InnoDB TABLESPACE=ts_secondary;

-- ---------- Bitácora de registros rechazados por el ETL ----------
CREATE TABLE IF NOT EXISTS etl_rechazo (
    IdRechazo    INT AUTO_INCREMENT PRIMARY KEY,
    IdEjecucion  CHAR(14) NOT NULL,
    Archivo      VARCHAR(50) NOT NULL,
    Fila         INT NOT NULL,
    TipoError    VARCHAR(60) NOT NULL,
    Campo        VARCHAR(40) NOT NULL,
    Detalle      VARCHAR(255) NOT NULL,
    Registro     TEXT,
    FechaRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB TABLESPACE=ts_secondary;
