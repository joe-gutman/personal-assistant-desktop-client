extends Node

@onready var player: AudioStreamPlayer = $AudioPlayer

var audio_capture: AudioEffectCapture
var recording = false
var buffer = PackedVector2Array()
var record_time = 0.0
var duration = 5.0  # Seconds



func _ready():
	AudioServer.input_device = "Default"
	var bus_index = AudioServer.get_bus_index("Record")
	audio_capture = AudioServer.get_bus_effect(bus_index, 0)

	if audio_capture:
		print("🎤 Mic is ready!")
		start_recording()
	else:
		print("❌ Mic setup failed")

func _process(delta):
	if recording and audio_capture and audio_capture.can_get_buffer(512):
		var chunk = audio_capture.get_buffer(512)
		buffer.append_array(chunk)
		record_time += delta

		if chunk.size() > 0:
			print("📈 Sample peek: ", chunk[0])

		if record_time >= duration:
			stop_recording()


func start_recording():
	print("🔴 Recording started")
	recording = true
	buffer = PackedVector2Array()
	record_time = 0.0

func stop_recording():
	print("🛑 Recording stopped. Saving to disk...")
	recording = false
	var path = "user://recorded_audio.wav"
	save_wav_file(path)
	play_wav(path)

func save_wav_file(path: String):
	var byte_data = convert_to_pcm(buffer)
	var wav_data = build_wav(byte_data, 16000)  # 16 kHz sample rate
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(wav_data)
	file.close()
	print("✅ Saved to ", path)

func play_wav(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = file.get_buffer(file.get_length())
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.stereo = false
		stream.mix_rate = 16000  # Sample rate used in save
		stream.data = data
		player.stream = stream
		player.play()
		print("▶️ Playing audio")

func convert_to_pcm(samples: PackedVector2Array) -> PackedByteArray:
	var pcm = PackedByteArray()
	for i in samples.size():
		var s = samples[i]
		var mono = (s.x + s.y) * 0.5  # Mix stereo to mono
		var clamped = clamp(mono, -1.0, 1.0)
		var int_sample = int(clamped * 32767.0)
		if int_sample < 0:
			int_sample += 65536  # Convert to unsigned for little endian
		pcm.append(int_sample & 0xFF)
		pcm.append((int_sample >> 8) & 0xFF)
	return pcm

func build_wav(pcm: PackedByteArray, sample_rate: int) -> PackedByteArray:
	var header = PackedByteArray()

	var byte_rate = sample_rate * 2  # Mono, 16-bit
	var block_align = 2
	var subchunk2_size = pcm.size()
	var chunk_size = 36 + subchunk2_size

	header.append_array("RIFF".to_ascii_buffer())
	header.append_array(to_le32(chunk_size))
	header.append_array("WAVE".to_ascii_buffer())
	header.append_array("fmt ".to_ascii_buffer())
	header.append_array(to_le32(16))  # Subchunk1Size (PCM)
	header.append_array(to_le16(1))   # AudioFormat (PCM)
	header.append_array(to_le16(1))   # NumChannels (mono)
	header.append_array(to_le32(sample_rate))
	header.append_array(to_le32(byte_rate))
	header.append_array(to_le16(block_align))
	header.append_array(to_le16(16))  # BitsPerSample
	header.append_array("data".to_ascii_buffer())
	header.append_array(to_le32(subchunk2_size))
	header.append_array(pcm)

	return header

func to_le16(value: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.append(value & 0xFF)
	b.append((value >> 8) & 0xFF)
	return b

func to_le32(value: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.append(value & 0xFF)
	b.append((value >> 8) & 0xFF)
	b.append((value >> 16) & 0xFF)
	b.append((value >> 24) & 0xFF)
	return b

	
