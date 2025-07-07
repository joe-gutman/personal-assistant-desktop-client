extends Node

var ws: WebSocketClient
var generator: AudioStreamGenerator
var mic: Node
var player: AudioStreamPlayer
var audio_buffer: PackedFloat32Array
var buffer_position: int

var last_audio_received_time := 0.0
const SPEECH_TIMEOUT := 2.0  # seconds
const COMPACT_THRESHOLD := 132300  # bytes

func _ready():
	var WSClient = preload("res://scripts/websocket.gd")

	ws = WSClient.new()
	ws.setup("/ws", _on_message)
	ws.connect_to_ws()

	mic = $Mic
	mic.setup(on_mic_data)

	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050  # Match Piper's sample rate (adjust if needed)
	generator.buffer_length = 0.5  # Half a second buffer

	player = $AudioStreamPlayer
	player.stream = generator
	player.play()

	audio_buffer = PackedFloat32Array()
	buffer_position = 0

	# var playback = player.get_stream_playback()
	# if playback is AudioStreamGeneratorPlayback:
	# 	print("Filling initial buffer with test tone")
	# 	var freq = 440.0
	# 	var sample_rate = generator.mix_rate
	# 	for i in range(0, 200):
	# 		var sample = sin(2.0 * PI * freq * (i / sample_rate)) * 0.25
	# 		playback.push_frame(Vector2(sample, sample))

func _process(delta):
	ws.poll()
	
	var playback = player.get_stream_playback()
	if playback is AudioStreamGeneratorPlayback:
		var frames_available = playback.get_frames_available()
		var end = min(audio_buffer.size(), buffer_position + frames_available * 2)

		while buffer_position < audio_buffer.size() and playback.can_push_buffer(1):
			var sample = audio_buffer[buffer_position]
			playback.push_frame(Vector2(sample, sample))
			buffer_position += 1

		# var now = Time.get_ticks_msec() / 1000.0
		# var time_since_last_audio = now - last_audio_received_time
		# if buffer_position > 0 and (buffer_position > COMPACT_THRESHOLD or time_since_last_audio > SPEECH_TIMEOUT):
		# 	audio_buffer = audio_buffer.slice(buffer_position, audio_buffer.size() - buffer_position)
		# 	buffer_position = 0

func _on_message(message):
	if message.type == "AUDIO" and message.source == "SERVER" and message.timestamp:
		print("Received SPEAKING message")
		print("Status: ", message.content.status)
		var audio_bytes: PackedByteArray = Marshalls.base64_to_raw(message.content.audio)
		print("First 5 bytes of audio:", audio_bytes.slice(0, 5))
		print("SPEAKING")
		play_audio(Marshalls.base64_to_raw(message.content.audio))

func on_mic_data(payload: Dictionary):
	# confirm status and audio keys exist
	if not payload.has("status") or not payload.has("audio"):
		print("Invalid payload received from mic:", payload)
		return
	
	var status = payload.status
	var audio_data = null
	if payload.audio:
		audio_data = Marshalls.raw_to_base64(payload.audio)

	if status:
		ws.send_message("AUDIO", {"status": "LISTENING", "audio": audio_data})
	else:
		ws.send_message("AUDIO", {"status": "STOPPED", "audio": null})

func play_audio(audio_bytes: PackedByteArray):
	var samples = PackedFloat32Array()
	for i in range(0, audio_bytes.size(), 2):
		if i + 1 >= audio_bytes.size():
			break
		var lo = audio_bytes[i]
		var hi = audio_bytes[i + 1]
		var val = (hi << 8) | lo
		var sample = clamp(int16(val) / 32768.0, -1.0, 1.0)
		samples.append(sample)
	last_audio_received_time = Time.get_ticks_msec() / 1000.0
	audio_buffer.append_array(samples)

func int16(val):
	if val >= 0x8000:
		return val - 0x10000
	return val
