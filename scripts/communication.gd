extends Control

@onready var text_input = $TextInput
@onready var text_output = $TextOutput
@onready var send_button = $SendButton
@onready var cancel_button = $CancelButton
@onready var new_conversation_button = $NewConversation

var http: HTTPRequest
var url = "http://127.0.0.1:5000/api/"

func _ready():
	print_tree_pretty()

	send_button.pressed.connect(send_message)
	cancel_button.pressed.connect(clear_input_text)
	new_conversation_button.pressed.connect(clear_output_text)
	new_conversation_button.pressed.connect(clear_input_text)

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_response)


func clear_input_text():
	if text_input.text:
		text_input.text = ""
		text_input.grab_focus()

func clear_output_text():
	if text_output.text:
		text_output.text = ""
		text_input.grab_focus()

func send_message():
	print("Sending message: " + text_input.text)
	var message = text_input.text
	if message.strip_edges() == "":
		return
	text_output.text += "User: " + message + "\n"
	text_input.text = ""
	var response = get_response(message)


func get_response(message):
	var method = HTTPClient.METHOD_POST
	var headers = [
		"Content-Type: application/json",
	]
	var body = JSON.stringify({
		"user_id": 1,
		"message": message,
	})

	http.request(url + "chat/", headers, HTTPClient.METHOD_POST, body)

func _on_http_response(result, response_code, headers, body):
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result == OK:

		var response = json.get_data().response
		print("Received response:", response)

		if response_code == 200:
			text_output.text += "AI: " + response + "\n"
		
	else:
		print("Failed to parse JSON response: " + str(parse_result))

	text_input.text = ""
	text_input.grab_focus()
