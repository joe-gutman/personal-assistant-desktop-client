extends Node

@onready var mic: AudioStreamPlayer
var record_effect: AudioEffectRecord
# var audio_socket_node: Node

var listening := false
var audio_windows_avg: Array = []
var max_window_count := 10
var speaking_threshold := 0.01
var silence_threshold := 0.001
var file_count := 0

func _ready():
	mic = get_parent().get_node("AudioStreamPlayer")
	AudioServer.input_device = "Microphone (NVIDIA Broadcast)"
	print("Input device:", AudioServer.input_device)
	print("Available mics:", AudioServer.get_input_device_list())

	# audio_socket_node = get_parent().get_node("WebSockets/AudioSocket")
	var bus_idx = AudioServer.get_bus_index("MicInput")
	record_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectRecord

	if record_effect == null:
		push_error("AudioEffectRecord not found on 'MicInput' bus.")
		return

	record_effect.set_recording_active(true)

	var mic_stream = AudioStreamMicrophone.new()
	mic.stream = mic_stream
	mic.bus = "MicInput"
	mic.play()

	print("Mic stream started on bus:", AudioServer.get_bus_name(bus_idx))
	print("Mix rate:", AudioServer.get_mix_rate())
	print("Input rate:", AudioServer.get_input_mix_rate())

func _on_Timer_timeout() -> void:
	if !record_effect.is_recording_active():
		return

	var wav: AudioStreamWAV = record_effect.get_recording()
	if wav == null or wav.get_data().is_empty():
		return

	var raw_data := wav.get_data()
	var total_amplitude := 0.0
	var sample_count := raw_data.size() / 2.0

	for i in range(0, raw_data.size(), 2):
		var sample := raw_data[i] | (raw_data[i + 1] << 8)
		if sample >= 32768:
			sample -= 65536
		var amplitude : float = abs(float(sample) / 32768.0)
		total_amplitude += amplitude

	var avg_amplitude := total_amplitude / sample_count
	audio_windows_avg.append(avg_amplitude)
	if audio_windows_avg.size() > max_window_count:
		audio_windows_avg.pop_front()

	if !listening and avg_amplitude > speaking_threshold:
		listening = true
		# audio_socket_node.send_message(true, null)
		print("Started listening")

	var all_below := audio_windows_avg.size() == max_window_count and audio_windows_avg.all(func(a): return a < silence_threshold)

	if listening and all_below:
		# audio_socket_node.send_message(false, null)
		print("Stopped listening")
		save_recording(wav)
		listening = false
		record_effect.set_recording_active(false)
		record_effect.set_recording_active(true)

func save_recording(wav: AudioStreamWAV) -> void:
	var dir := DirAccess.open("user://logs/mic")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://logs/mic")

	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_input_mix_rate()
	wav.stereo = false

	var path = "user://logs/mic/audio_%d.wav" % file_count
	file_count += 1
	var ok = wav.save_to_wav(path)
	print("Saved WAV:", path, "Success:", ok)
