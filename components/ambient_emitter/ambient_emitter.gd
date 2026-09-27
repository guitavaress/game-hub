class_name AmbientEmitter
extends AudioStreamPlayer3D
## Som ambiente em 3D: ouvido de perto e sumindo com a distância.
##
## Pode tocar:
##   - um LOOP contínuo (ex.: motor, vento): preencha loop_stream;
##   - sons AVULSOS de vez em quando (ex.: cartas, passarinhos): preencha
##     one_shots; a cada "interval" segundos (sorteado), toca um deles, com
##     um tom levemente diferente para não soar repetido.
## Preencha ANTES de adicionar à cena. Toca no canal "Ambiente".
##
## Com o hub dormindo (jogo aberto), o mundo pausa e o som para junto.

var loop_stream: AudioStream
var one_shots: Array[AudioStream] = []
## Tempo entre sons avulsos (mínimo, máximo), em segundos.
var interval: Vector2 = Vector2(3.0, 8.0)
## Variação de tom dos sons avulsos (mínimo, máximo). 1.0 = tom original.
var pitch_range: Vector2 = Vector2(0.9, 1.1)


func _ready() -> void:
	bus = &"Ambiente"
	if loop_stream != null:
		stream = looping(loop_stream)
		# Começa num ponto sorteado: dois motores iguais não tocam "em coro".
		play(randf() * loop_stream.get_length())
	elif not one_shots.is_empty():
		_schedule_next()


func _exit_tree() -> void:
	# Para o som ao sair da cena (ex.: ao fechar o hub), para o servidor de
	# áudio não ficar segurando um som que ninguém mais usa.
	stop()


func _schedule_next() -> void:
	# process_always = false: o tempo não corre com o mundo pausado.
	get_tree().create_timer(randf_range(interval.x, interval.y), false).timeout.connect(_play_one_shot)


func _play_one_shot() -> void:
	stream = one_shots.pick_random()
	pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	play()
	_schedule_next()


## Devolve uma cópia do som configurada para repetir sem parar.
## (Serve para OGG e WAV; outros formatos voltam como estão.)
static func looping(original: AudioStream) -> AudioStream:
	var copy := original.duplicate() as AudioStream
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return copy
