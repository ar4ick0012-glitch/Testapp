class_name DungeonSound
extends Node
## Small original cues, synthesized locally; no downloaded music or audio dependency.
## All gain is local to these players. Muting never changes Godot's master bus.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 3
const OUTPUT_GAIN_DB := -6.0
const CUE_IDS := ["start", "click", "confirm", "tutorial", "error"]

var volume := 0.35:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_update_players()
var muted := false:
	set(value):
		muted = value
		_update_players()

var cue_streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
# Headless builds have no listener. Audio tests opt in to exercise the Dummy
# driver explicitly, then allow its asynchronous disposal queue to drain.
var allow_headless_playback := false
var _next_voice := 0


func _ready() -> void:
	for id in CUE_IDS:
		cue_streams[id] = _make_cue(id)
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "GentleCue%d" % index
		add_child(player)
		voices.append(player)
	_update_players()


func _exit_tree() -> void:
	# Release the playback and its generated PCM before the audio server exits.
	# This also covers an immediate scene replacement while a cue is playing.
	for player in voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	voices.clear()
	cue_streams.clear()


func set_volume(value: float) -> void:
	volume = value


func get_volume() -> float:
	return volume


func set_muted(value: bool) -> void:
	muted = value


func is_muted() -> bool:
	return muted


func apply_settings(value: float, should_mute: bool) -> void:
	volume = value
	muted = should_mute


func play_cue(id: String) -> void:
	if muted or volume <= 0.0 or voices.is_empty() or not cue_streams.has(id):
		return
	if DisplayServer.get_name() == "headless" and not allow_headless_playback:
		return
	# Three short voices allow a confirmation to finish under the introduction,
	# while bounding simultaneous gain if a player clicks many times quickly.
	var player: AudioStreamPlayer = voices[_next_voice]
	_next_voice = (_next_voice + 1) % voices.size()
	player.stream = cue_streams[id]
	player.play()


func _update_players() -> void:
	var silent := muted or volume <= 0.0
	for player in voices:
		player.volume_db = -80.0 if silent else OUTPUT_GAIN_DB + linear_to_db(volume)
		if silent:
			player.stop()


func _make_cue(id: String) -> AudioStreamWAV:
	var duration := 1.08
	var notes: Array = []
	# [onset, length, frequency, amplitude]. Pentatonic intervals keep these
	# short sounds warm and quiet, without borrowing any game's sound assets.
	match id:
		"start":
			notes = [[0.0, 0.72, 220.0, 0.27], [0.18, 0.68, 330.0, 0.21], [0.38, 0.68, 440.0, 0.15]]
		"click":
			duration = 0.095
			notes = [[0.0, 0.09, 440.0, 0.15]]
		"confirm":
			duration = 0.38
			notes = [[0.0, 0.25, 330.0, 0.21], [0.09, 0.28, 440.0, 0.18]]
		"tutorial":
			duration = 0.54
			notes = [[0.0, 0.35, 440.0, 0.18], [0.13, 0.40, 550.0, 0.14]]
		"error":
			duration = 0.28
			notes = [[0.0, 0.18, 220.0, 0.15], [0.08, 0.19, 196.0, 0.13]]
	var samples := int(ceil(duration * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	for sample_index in range(samples):
		var t := float(sample_index) / SAMPLE_RATE
		var signal_value := 0.0
		for note in notes:
			var elapsed: float = t - float(note[0])
			var length: float = note[1]
			if elapsed < 0.0 or elapsed >= length:
				continue
			# A rounded onset and tail avoid audible clicks at sample boundaries.
			var attack := minf(0.025, length * 0.22)
			var envelope := sin(minf(elapsed / attack, 1.0) * PI * 0.5)
			envelope *= pow(maxf(0.0, 1.0 - elapsed / length), 2.0)
			var phase: float = TAU * float(note[2]) * elapsed
			var tone := sin(phase) * 0.9 + sin(phase * 2.0) * 0.075 + sin(phase * 3.0) * 0.025
			signal_value += tone * envelope * float(note[3])
		pcm.encode_s16(sample_index * 2, int(round(clampf(signal_value, -0.95, 0.95) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream
