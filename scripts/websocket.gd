extends Node

class_name WebSocketClient

var socket := WebSocketPeer.new()
var url := ""
var is_connected := false
var state

func connect_to(endpoint: String) -> void:
	assert(endpoint != "", "Websocket endpoint cannot be blank.") 
	
	url = Globals.WS_BASE_URL.rstrip("/") + "/" + endpoint.lstrip("/")
	print("Connecting to:", url)
	socket.connect_to_url(url)

func _process(_delta: float) -> void:
	socket.poll()
	state = socket.get_ready_state()
	if (state == WebSocketPeer.STATE_OPEN):
		if not is_connected:
			is_connected = true
			_on_open()
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			_on_message(packet)
	elif (state == WebSocketPeer.STATE_CLOSED):
		if is_connected:
			is_connected = false
			_on_close(socket.get_close_code(), socket.get_close_reason())

func _on_open():
	print( name, "WebSocket connected!")

func _on_close(code, reason):
	print("[%s] WebSocket closed with Code: %d Reason: %s" % [name, code, reason])

# Private virtual methods
func _on_message(message): pass
func _send_message(): pass
