-- =====================================================================
-- Actividad 3.1 - Modelo en estrella: base de datos analítica de opiniones
-- Motor: MySQL 8 (CHECK exige 8.0.16 o superior)
-- Hecho: fact_opinion (una fila por opinión, de cualquier fuente)
-- Dimensiones: dim_tiempo, dim_producto, dim_cliente, dim_fuente, dim_sentimiento
-- =====================================================================
CREATE DATABASE IF NOT EXISTS opiniones_dw
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE opiniones_dw;

-- ---------- Dimensiones ----------
CREATE TABLE IF NOT EXISTS dim_tiempo (
    sk_tiempo   INT PRIMARY KEY,                 -- AAAAMMDD
    fecha       DATE NOT NULL,
    anio        SMALLINT NOT NULL,
    trimestre   TINYINT NOT NULL,
    mes         TINYINT NOT NULL,
    nombre_mes  VARCHAR(12) NOT NULL,
    dia         TINYINT NOT NULL,
    dia_semana  VARCHAR(12) NOT NULL,
    UNIQUE KEY uq_dim_tiempo_fecha (fecha)
);

CREATE TABLE IF NOT EXISTS dim_producto (
    sk_producto  INT PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    categoria    VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_cliente (
    sk_cliente  INT PRIMARY KEY,                 -- 0 = cliente anónimo
    nombre      VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_fuente (
    sk_fuente    INT PRIMARY KEY,
    tipo_fuente  VARCHAR(20) NOT NULL,           -- Encuesta, Reseña web, Red social
    canal        VARCHAR(20) NOT NULL,           -- EncuestaInterna, SitioWeb, Facebook, Instagram, Twitter
    ambito       VARCHAR(10) NOT NULL,           -- Interno o Externo
    UNIQUE KEY uq_dim_fuente_canal (canal)
);

CREATE TABLE IF NOT EXISTS dim_sentimiento (
    sk_sentimiento  TINYINT PRIMARY KEY,
    nombre          VARCHAR(15) NOT NULL,        -- Positiva, Neutra, Negativa, Sin clasificar
    rango_puntaje   VARCHAR(15) NOT NULL,        -- regla de clasificación
    UNIQUE KEY uq_dim_sentimiento_nombre (nombre)
);

-- ---------- Tabla de hechos ----------
-- La clave primaria es compuesta (sk_tiempo, id_opinion): en InnoDB la clave primaria es el índice
-- agrupado (clustered), así las filas quedan ordenadas físicamente por fecha.
CREATE TABLE IF NOT EXISTS fact_opinion (
    id_opinion      INT NOT NULL,                -- IdOpinion de la base transaccional
    id_origen       VARCHAR(20) NOT NULL,        -- ID original del CSV (trazabilidad)
    sk_tiempo       INT NOT NULL,
    sk_producto     INT NOT NULL,
    sk_cliente      INT NOT NULL,
    sk_fuente       INT NOT NULL,
    sk_sentimiento  TINYINT NOT NULL,
    puntaje         TINYINT NULL,                -- 1 a 5; vacío en redes sociales
    es_positiva     TINYINT NOT NULL,
    es_neutra       TINYINT NOT NULL,
    es_negativa     TINYINT NOT NULL,
    cantidad        TINYINT NOT NULL DEFAULT 1,

    PRIMARY KEY (sk_tiempo, id_opinion),
    UNIQUE KEY uq_fact_id_opinion (id_opinion),

    -- Índices secundarios sobre las demás claves foráneas (el de sk_tiempo lo cubre la clave primaria)
    KEY ix_fact_producto    (sk_producto),
    KEY ix_fact_cliente     (sk_cliente),
    KEY ix_fact_fuente      (sk_fuente),
    KEY ix_fact_sentimiento (sk_sentimiento),

    CONSTRAINT fk_fact_tiempo      FOREIGN KEY (sk_tiempo)      REFERENCES dim_tiempo(sk_tiempo),
    CONSTRAINT fk_fact_producto    FOREIGN KEY (sk_producto)    REFERENCES dim_producto(sk_producto),
    CONSTRAINT fk_fact_cliente     FOREIGN KEY (sk_cliente)     REFERENCES dim_cliente(sk_cliente),
    CONSTRAINT fk_fact_fuente      FOREIGN KEY (sk_fuente)      REFERENCES dim_fuente(sk_fuente),
    CONSTRAINT fk_fact_sentimiento FOREIGN KEY (sk_sentimiento) REFERENCES dim_sentimiento(sk_sentimiento),
    CONSTRAINT ck_fact_puntaje     CHECK (puntaje IS NULL OR puntaje BETWEEN 1 AND 5)
);
