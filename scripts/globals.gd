extends Node

const SERVER_IP := "172.20.74.164"
const WS_PORT = 5000
var WS_BASE_URL := "ws://%s:%d" % [SERVER_IP, WS_PORT]
