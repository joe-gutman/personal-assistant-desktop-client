extends Node

@onready var mic: AudioStreamPlayer = $MicStreamPlayer
var capture: AudioEffectCapture

var all_audio_bytes: PackedByteArray = PackedByteArray()
var audio_windows_avg = []
var max_window_count = 10
var speaking_threshold = .01
var silence_threshold = .001
var listening = false
var file_count = 0
var mic_data_callback = null

func setup(callback: Callable):
	mic_data_callback = callback
	$Timer.start()

func save_audio_to_wav():
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.stereo = false
	wav.data = all_audio_bytes
	var path = "user://logs/mic/audio_%d.wav" % file_count
	file_count += 1
	print("Godot mix rate:", AudioServer.get_mix_rate())
	wav.save_to_wav(path)
	print("Saved audio to: ", path)

func convert_audio(frames: PackedVector2Array) -> PackedByteArray:
	var pcm := PackedByteArray()
	for frame in frames:
		# Use only the left channel (frame.x) for mono input
		# var mono := clamp(frame.x * 0.8, -1.0, 1.0)  # 80% headroom, prevent overflow
		var int_sample : int = int(round(frame.x * 32767.0))
		pcm.append(int_sample & 0xff)           # LSB
		pcm.append((int_sample >> 8) & 0xff)    # MSB
	return pcm

func _ready():
	AudioServer.input_device = "Microphone (NVIDIA Broadcast)"
	var mic_list := AudioServer.get_input_device_list()
	print("Available mics:", mic_list)

	print("Current input device:", AudioServer.input_device)

	print("Mic after change:", AudioServer.input_device)


	mic_data_callback = get_parent().get_node("WebSockets/ClientStream")
	print(mic_data_callback)
	var bus_idx = AudioServer.get_bus_index("MicInput")
	capture = AudioServer.get_bus_effect(bus_idx, 0)

	var mic_stream = AudioStreamMicrophone.new()
	mic.stream = mic_stream
	mic.bus = "MicInput"
	mic.play()

	# print("Mic stream started on bus:", AudioServer.get_bus_name(bus_idx))
	# print("Godot mix rate:", AudioServer.get_mix_rate())

func _on_Timer_timeout() -> void:
	var frames
	var available = capture.get_frames_available()
	if available == 0:
		return
	else:
		frames = capture.get_buffer(available)
		# Now 'frames' contains all available audio frames

	var speech_detected = false
	var listen_idx = 0


	# var print_frames = []
	for i in range(frames.size()):
		# if i < 5:
		# 	print_frames.append(frames[i])
		# elif i > 5: 
		# 	print(print_frames);
		var amplitude = max(abs(frames[i].x), abs(frames[i].y))
		if amplitude > speaking_threshold:
			speech_detected = true
			listen_idx = i
			break

	if !listening and speech_detected:
		print("Started Listening")
		listening = true

		audio_windows_avg.clear()

			
	if listening:
		var total_amplitude = 0
		var frame_count = 0
		var speech_frames:= PackedVector2Array()

		# Get average amplitude of all frames containing speech, save as audio window
		var pre_speech_frames = 1024
		var speech_start = max(0, listen_idx - pre_speech_frames)
		for i in range(speech_start, frames.size()):
			total_amplitude += max(abs(frames[i].x), abs(frames[i].y))
			frame_count += 1
			speech_frames.append(frames[i])

		var avg_amplitude = total_amplitude / frame_count;
		audio_windows_avg.append(avg_amplitude)

		if audio_windows_avg.size() > max_window_count:
			audio_windows_avg.pop_front()

		# when audio window queue is full, check if all windows are silent
		var all_below = false
		if audio_windows_avg.size() == max_window_count:
			all_below = true;
			for amplitude in audio_windows_avg:
				if amplitude > silence_threshold:
					all_below = false
					break
			if all_below:
				listening = false
				mic_data_callback.call({
					"status": listening,
					"audio": null
				})
				print("Stopped Listening")
				save_audio_to_wav()
				all_audio_bytes.clear()

		# if all windows are not silent handle audio
		if !all_below: 
			var bytes := convert_audio(speech_frames)
			
			mic_data_callback.call({
				"status": listening,
				"audio": bytes
			})
			print("Audio sent with size: ", bytes.size())
			all_audio_bytes.append_array(bytes)
		
