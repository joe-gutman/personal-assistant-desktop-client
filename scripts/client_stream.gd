extends WebSocketClient

func _ready():
	connect_to("/ws/client")

func _on_message(message):
	# write a warning this should not be receiving messages as it is for sending messages from the client
	print("Warning: Client stream received a message, this should not happen. Message:", message.get_string_from_utf8())


func send_message(listening = false, audio_data = null):
	var message = {
		"status": "LISTENING" if listening else "STOPPED",
		"audio": null
	}

	if (audio_data):
		message["audio"] = Marshalls.raw_to_base64(audio_data)
	
	socket.send_text(JSON.stringify(message))
