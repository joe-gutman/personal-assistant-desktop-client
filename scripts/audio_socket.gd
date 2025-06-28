extends WebSocketClient

func _ready():
	connect_to("/ws/audio")

func _on_message(message):
	print("Audio message received:", message.slice(0, 5))
	# You might decode binary or JSON audio control data here
