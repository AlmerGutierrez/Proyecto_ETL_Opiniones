"""Configuración central. Los valores de conexión se leen de variables de entorno."""
import os
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Carpeta base de la estructura física (ver sql/00_almacenamiento_fisico.sql). Usar barras normales.
RUTA_FISICA_DEFECTO = os.getenv("DB_RUTA_FISICA", "C:/Data/OpinionesClientes")
RUTA_EN_SCRIPT = "C:/Data/OpinionesClientes"   # texto literal de sql/00_almacenamiento_fisico.sql
TABLESPACES = ("ts_primary", "ts_secondary")

# Supuesto documentado: ningún CSV de opiniones trae IdFuente. Se asocia cada archivo
# a la primera fuente (menor IdFuente) de fuente_datos cuyo TipoFuente corresponda.
TIPO_FUENTE_POR_ARCHIVO = {
    "surveys_part1.csv": "CSV",
    "social_comments.csv": "Red Social",
    "web_reviews.csv": "Web",
}

# Columnas que debe traer cada archivo (validación de estructura)
COLUMNAS_REQUERIDAS = {
    "fuente_datos.csv": ["IdFuente", "TipoFuente", "FechaCarga"],
    "clients.csv": ["IdCliente", "Nombre", "Email"],
    "products.csv": ["IdProducto", "Nombre", "Categoría"],
    "surveys_part1.csv": ["IdOpinion", "IdCliente", "IdProducto", "Fecha", "Comentario",
                          "Clasificación", "PuntajeSatisfacción", "Fuente"],
    "social_comments.csv": ["IdComment", "IdCliente", "IdProducto", "Fuente", "Fecha", "Comentario"],
    "web_reviews.csv": ["IdReview", "IdCliente", "IdProducto", "Fecha", "Comentario", "Rating"],
}

TIPOS_FUENTE = {"Web", "CSV", "Red Social"}
CLASIFICACIONES = {"Positiva", "Negativa", "Neutra"}
CANALES = {"Facebook", "Instagram", "Twitter"}


@dataclass
class ConfigBD:
    host: str
    port: int
    usuario: str
    clave: str
    nombre: str

    @classmethod
    def desde_entorno(cls):
        return cls(
            host=os.getenv("DB_HOST", "127.0.0.1"),
            port=int(os.getenv("DB_PORT", "3306")),
            usuario=os.getenv("DB_USER", "root"),
            clave=os.getenv("DB_PASSWORD", ""),
            nombre=os.getenv("DB_NAME", "opiniones_clientes"),
        )
