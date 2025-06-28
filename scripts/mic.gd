extends Node

@onready var mic: AudioStreamPlayer = $AudioStreamPlayer
var capture: AudioEffectCapture

var audio_socket_node: Node
var audio_windows_avg = []
var max_window_count = 10
var speaking_threshold = 0.01
var silence_threshold = 0.001
var listening = false

func handle_audio(frames: PackedVector2Array):
	var pcm := PackedByteArray()
	for f in frames:
		var mono = (f.x + f.y) / 2.0;
		var sample = int(clamp(mono, -1, 1) * 32767)
		pcm.append(sample & 0xff)
		pcm.append((sample >> 8) & 0xff)

	audio_socket_node.send_message(pcm)

func _ready():
	audio_socket_node = get_parent().get_node("WebSockets/AudioSocket")
	print(audio_socket_node)
	var bus_idx = AudioServer.get_bus_index("MicInput")
	capture = AudioServer.get_bus_effect(bus_idx, 0)

	var mic_stream = AudioStreamMicrophone.new()
	mic.stream = mic_stream
	mic.bus = "MicInput"
	mic.play()

	print("🎧 Mic stream started on bus:", AudioServer.get_bus_name(bus_idx))


# func _process(_delta):
#     var frames = capture.get_buffer(128)
#     if frames.size() > 0:
#         draw_waveform(frames)

func _on_Timer_timeout() -> void:
	var frames = capture.get_buffer(4096)

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
		print("🔉Started Listening")
		listening = true
		audio_windows_avg.clear()

			
	if listening:
		var total_amplitude = 0
		var frame_count = 0
		var speech_frames:= PackedVector2Array()

		# Get average amplitude of all frames containing speech, save as audio window
		for i in range(listen_idx, frames.size()):
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
				print("⛔ Stopped Listening")
				listening = false

		# if all windows are not silent handle audio
		if !all_below: 
			handle_audio(speech_frames)
		
