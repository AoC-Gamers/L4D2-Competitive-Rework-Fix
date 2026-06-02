# l4d2_hybrid_scoremod_zone

## Estado

- `addons/sourcemod/scripting/include/l4d2_hybrid_scoremod_zone.inc`
- `addons/sourcemod/translations/l4d2_hybrid_scoremod.phrases.txt`
- `addons/sourcemod/translations/es/l4d2_hybrid_scoremod.phrases.txt`

La implementación fuente `addons/sourcemod/scripting/l4d2_hybrid_scoremod_zone.sp` fue eliminada.

La lógica de esta variante fue absorbida por:

- `addons/sourcemod/scripting/l4d2_hybrid_scoremod.sp`

## Motivo del Cambio

La variante `zone` y la variante `hybrid` compartían casi toda su implementación. La diferencia funcional relevante era la penalización adicional aplicada en eventos de incap y death. Para evitar mantener dos fuentes paralelas, esa diferencia pasó a controlarse por ConVar.

## Comportamiento Actual

- `smplus_zone_mode 1` reproduce el comportamiento que antes entregaba `l4d2_hybrid_scoremod_zone`
- `smplus_zone_mode 0` usa el comportamiento tradicional de `l4d2_hybrid_scoremod`
- el valor por defecto está pensado para cubrir los modos que antes cargaban `zone`

## Compatibilidad

- el include `l4d2_hybrid_scoremod_zone.inc` se conserva como referencia de compatibilidad documental
- la API pública expuesta por la antigua variante `zone` quedó absorbida por `l4d2_hybrid_scoremod`
- `spechud` fue migrado para consumir sólo `l4d2_hybrid_scoremod`
- los modos que antes cargaban `l4d2_hybrid_scoremod_zone.smx` deben cargar ahora `l4d2_hybrid_scoremod.smx`

## Migración de Configs

- modos tradicionales como `eq` y `acemodrv` deben declarar `confogl_addcvar smplus_zone_mode 0`
- modos que antes cargaban `zone` no necesitan `smplus_zone_mode 1` explícito si usan el valor por defecto
- en flujos donde el repo original se modifica antes de instalarse, el hook `sir.default.sh` de `Docker-L4D2-AoC` es el punto correcto para aplicar esta migración sin editar el upstream

## Referencia Histórica

- este documento queda como registro de la antigua variante separada
- cualquier cambio nuevo debe documentarse en `docs/l4d2_hybrid_scoremod.md`
