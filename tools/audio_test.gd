extends SceneTree
## Verify original PCM output and local volume/mute controls using Dummy audio.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var sound := DungeonSound.new()
	root.add_child(sound)
	await process_frame
	check(is_equal_approx(sound.get_volume(), 0.35), "Default sound level should be subdued.")
	check(not sound.is_muted(), "Sound should be enabled on first launch.")
	check(sound.cue_streams.size() == DungeonSound.CUE_IDS.size(), "Every documented cue should exist.")
	for player in sound.voices:
		check(not player.playing, "Creating sound must not autoplay before saved settings are applied.")
	if DisplayServer.get_name() == "headless":
		sound.play_cue("start")
		for player in sound.voices:
			check(not player.playing, "A normal headless run should not start inaudible playback.")
	sound.allow_headless_playback = true
	var master_index := AudioServer.get_bus_index("Master")
	var master_gain := AudioServer.get_bus_volume_db(master_index)
	for id in DungeonSound.CUE_IDS:
		var stream: AudioStreamWAV = sound.cue_streams[id]
		check(stream.mix_rate == DungeonSound.SAMPLE_RATE and not stream.stereo, "%s must use supported mono PCM." % id)
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s must use signed 16-bit samples." % id)
		check(stream.get_length() >= 0.09 and stream.get_length() <= 1.10, "%s should be a short cue." % id)
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s should finish naturally." % id)
		var peak := 0.0
		var squares := 0.0
		var sample_count := stream.data.size() / 2
		for sample_index in range(sample_count):
			var value := float(stream.data.decode_s16(sample_index * 2)) / 32767.0
			peak = maxf(peak, absf(value))
			squares += value * value
		var rms := sqrt(squares / sample_count)
		check(peak > 0.05 and peak < 0.45, "%s should contain sound without a loud peak or clipping." % id)
		check(rms > 0.005 and rms < 0.14, "%s should have a low average level." % id)
		check(stream.data.decode_s16(0) == 0 and abs(stream.data.decode_s16(stream.data.size() - 2)) <= 1, "%s should start and finish silently." % id)
		print("AUDIO_CUE ", id, " duration=", stream.get_length(), " peak=", peak, " rms=", rms)
	sound.play_cue("start")
	await process_frame
	check(sound.voices[0].playing, "A start cue should play after settings are applied.")
	var old_gain := sound.voices[0].volume_db
	sound.set_volume(0.15)
	check(sound.voices[0].volume_db < old_gain, "Volume should update an already playing cue.")
	sound.set_muted(true)
	check(sound.is_muted(), "Muting should be observable by the UI.")
	for player in sound.voices:
		check(not player.playing, "Muting should stop every active cue immediately.")
	sound.play_cue("confirm")
	check(not sound.voices[1].playing, "A muted component should not start new cues.")
	sound.apply_settings(0.0, false)
	sound.play_cue("confirm")
	for player in sound.voices:
		check(not player.playing, "Zero volume should remain silent, including after unmuting.")
	sound.apply_settings(0.35, false)
	sound.play_cue("confirm")
	await process_frame
	check(sound.voices[1].playing, "Sound may play again when explicitly enabled.")
	sound.set_volume(4.0)
	check(is_equal_approx(sound.get_volume(), 1.0), "Volume must be limited to 100%.")
	sound.set_volume(-1.0)
	check(is_zero_approx(sound.get_volume()), "Negative volume must be clamped to silence.")
	sound.play_cue("missing")
	check(is_equal_approx(AudioServer.get_bus_volume_db(master_index), master_gain), "Local sound controls must not modify the global master bus.")
	print("AUDIO_CHECKS checks=", checks, " failures=", failures)
	sound.free()
	# Godot 4.3 queues WAV disposal on its mixer thread; the main loop needs
	# another update after that tick before an immediate test-process exit.
	await create_timer(0.08).timeout
	await process_frame
	quit(1 if failures else 0)
