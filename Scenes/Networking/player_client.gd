extends Node
class_name PlayerClient

# Client Script
var SERVER
var last_ping_time = 0.0

func _ready():
	ping()

func ping():
	last_ping_time = Time.get_unix_time_from_system()
	#$Server.ping.rpc() # Assuming you have a node named "Server" with an RPC function "ping"
