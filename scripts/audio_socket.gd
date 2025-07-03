extends WebSocketClient

var json = JSON.new()

func _ready():
	connect_to("/ws/audio")

func _on_message(message):
	print("Audio message received:", message.slice(0, 5))
	# You might decode binary or JSON audio control data here

func send_message(listening = false, audio_data = null):
	var message = {
		"status": "LISTENING" if listening else "STOPPED",
		"audio": null
	}

	if (audio_data):
		message["audio"] = Marshalls.raw_to_base64(audio_data)
	
	socket.send_text(json.stringify(message))
