class_name WeatherSpec
extends Resource
## Como um lugar mostra o tempo do mundo (parte do DistrictProfile, Fase 7.6, e
## do BiomeSpec). Desde a Fase 19.6, quem decide o tempo é o WeatherDirector
## (o mesmo para a cidade toda: limpo, nublado, chuva fraca, chuva forte); este
## perfil só diz o que CAI aqui quando o mundo chove:
##   "garoa"   chuva (o nome ficou da garoa da Fase 7: trocar quebraria o .tres);
##   "neve"    neve, e nevasca na chuva forte (a montanha);
##   "folhas"  chuva com folhas caindo (a floresta);
##   "poeira"  poeira levada pelo vento, sem chuva (o deserto).
## Um bairro sem perfil mostra a chuva da cidade.

@export_enum("garoa", "neve", "folhas", "poeira") var kind: String = "garoa"
## Quantidade de partículas (1.0 = normal). A qualidade gráfica ainda reduz isso.
@export_range(0.0, 2.0, 0.05) var intensity: float = 1.0
