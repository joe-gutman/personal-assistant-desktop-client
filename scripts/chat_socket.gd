extends WebSocketClient

func _ready():
	connect_to("/ws/chat")

func _on_message(message):
	print("Chat message received:", message.get_string_from_utf8())
	# Add your chat-specific handling here (e.g., display message)
