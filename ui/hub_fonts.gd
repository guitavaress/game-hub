class_name HubFonts
extends RefCounted
## Fontes do hub (Barlow, licença OFL, em assets/fonts/barlow).
##
## A interface (HUD, avisos, telas) já usa a Barlow SemiBold automaticamente
## (project.godot > gui/theme/custom_font). Os textos 3D (Label3D) precisam
## receber a fonte uma a uma: use estas constantes.

## Texto comum: nomes, status.
const TEXT: Font = preload("res://assets/fonts/barlow/Barlow-SemiBold.ttf")
## Texto leve: linhas secundárias.
const LIGHT: Font = preload("res://assets/fonts/barlow/Barlow-Medium.ttf")
## Letreiros e placas: estreita, estilo sinalização urbana.
const SIGN: Font = preload("res://assets/fonts/barlow/BarlowCondensed-SemiBold.ttf")
