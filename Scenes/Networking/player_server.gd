extends Node


@rpc("any_peer")
func ping():
	var sender_id = get_multiplayer().get_remote_sender_id()
	print_ping.rpc(sender_id)

@rpc("any_peer")
func print_ping(_sender_id):
	var _pong_time = Time.get_unix_time_from_system()
	#var rtt = pong_time - last_ping_time
	#print("Ping delay: ", rtt)
