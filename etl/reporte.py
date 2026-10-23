"""Estadísticas por archivo y resumen final."""
from collections import Counter
from dataclasses import dataclass, field


@dataclass
class Estadisticas:
    archivo: str
    leidos: int = 0
    insertados: int = 0
    rechazados: int = 0
    motivos: Counter = field(default_factory=Counter)
    error_fatal: str = ""


def imprimir_resumen(log, ejecucion, estadisticas, segundos):
    linea = "=" * 78
    log.info(linea)
    log.info(f" RESUMEN DE LA CARGA  (ejecución {ejecucion})")
    log.info(linea)
    log.info(f" {'Archivo':<24}{'Leídos':>10}{'Insertados':>13}{'Rechazados':>13}")
    log.info(" " + "-" * 60)
    t_l = t_i = t_r = 0
    for e in estadisticas:
        log.info(f" {e.archivo:<24}{e.leidos:>10}{e.insertados:>13}{e.rechazados:>13}")
        t_l, t_i, t_r = t_l + e.leidos, t_i + e.insertados, t_r + e.rechazados
    log.info(" " + "-" * 60)
    log.info(f" {'TOTAL':<24}{t_l:>10}{t_i:>13}{t_r:>13}")
    hay_motivos = any(e.motivos for e in estadisticas)
    if hay_motivos:
        log.info("")
        log.info(" Motivos de rechazo:")
        for e in estadisticas:
            for motivo, n in e.motivos.most_common():
                log.info(f"   [{e.archivo}] {motivo}: {n}")
    for e in estadisticas:
        if e.error_fatal:
            log.info(f" ARCHIVO NO PROCESADO [{e.archivo}]: {e.error_fatal}")
    log.info("")
    log.info(f" Duración: {segundos:.2f} s")
    log.info(linea)
    return t_l, t_i, t_r
