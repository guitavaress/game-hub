class_name HomeCatalog
extends Resource
## O CATÁLOGO da casa (Fase 13): os temas, as disposições dos móveis e as
## cores prontas que o computador oferece. O primeiro tema e a primeira
## disposição são os padrões. Arquivo: profiles/home_catalog.tres.

## Os temas, em ordem (o primeiro é o padrão).
@export var homes: Array[HomeProfile] = []
## As disposições dos móveis, em ordem (a primeira é a padrão).
@export var layouts: Array[HomeLayout] = []
## Cores prontas para as paredes e para o néon.
@export var wall_palette: PackedColorArray = PackedColorArray()
@export var neon_palette: PackedColorArray = PackedColorArray()
