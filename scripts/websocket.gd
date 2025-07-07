class_name WebSocketClient

var connected_at := 0.0

var socket: WebSocketPeer
var url := ""
var is_connected := false
var state
var on_message_func = null

func setup(endpoint: String, callback: Callable):
	socket = WebSocketPeer.new()
	url = Globals.WS_BASE_URL.rstrip("/") + "/" + endpoint.lstrip("/")
	on_message_func = callback

func connect_to_ws():
	print("Connecting to:", url)
	socket.connect_to_url(url)

func poll() -> void:
	socket.poll()
	state = socket.get_ready_state()


	if state == WebSocketPeer.STATE_OPEN:
		# print("WebSocket state: OPEN")
		if not is_connected:
			is_connected = true
			_on_open()
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			_on_message(packet)
	elif state == WebSocketPeer.STATE_CLOSED:
		# print("WebSocket state: CLOSED")
		if is_connected:
			is_connected = false
			_on_close(socket.get_close_code(), socket.get_close_reason())

func _on_open():
	print("WebSocket connected!")
	connected_at = Time.get_unix_time_from_system()

func _on_close(code, reason):
	print("WebSocket closed with Code: %d Reason: %s" % [code, reason])

func _on_message(raw_message):
	var json_result = JSON.parse_string(raw_message.get_string_from_utf8())
	if on_message_func != null:
		if json_result is Dictionary:
			on_message_func.call(json_result)
		else:
			print("Websocket Warning: Message result is not a Dictionary")

func send_message(type, content):
	if state == WebSocketPeer.STATE_OPEN:
		print("WebSocket is open. Can send message.")

	var time = Time.get_datetime_dict_from_system()
	var time_str = "%02d-%02d-%02d %02d:%02d:%02d" % [
		time["year"], time["month"], time["day"], # Date
		time["hour"], time["minute"], time["second"] # Time
	]

	var msg = {
		"source": "CLIENT",
		"source_id": null,
		"target_id": null,
		"timestamp": time_str,
		"type": type,
		"content": content
	}

	msg = JSON.stringify(msg)
	socket.send_text(msg)

	var printed_msg = msg.substr(0, 100)
	# print("Sending message: %s" % [printed_msg])
