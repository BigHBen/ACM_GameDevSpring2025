extends Node
class_name Lobby

var game_root : GameManagerMultiplayer
var server : PackedScene = preload("res://Scenes/Networking/server.tscn")
var client : PackedScene = preload("res://Scenes/Networking/client.tscn")


const DEFAULT_IP = '127.0.0.1' # Localhost
const PORT = 9999
var peer : ENetMultiplayerPeer# = ENetMultiplayerPeer.new()
var player_idx : int = 0
var player_info = {"name": "Name"}
var name_entry = ""

var name_exchange_log = {}
var connected_players = {}
var players_loaded = 0

# These signals can be connected to by a UI lobby scene or the game scene.
signal players_registered()
#signal player_connected()
signal player_disconnected(peer_id)
signal server_disconnected

var multiplayer_active : bool = false
var player_ids : Array[int] = []
var player_one_name_set : bool = false

var connected_emitted_by : Array[int] = []
var last_ping_time = 0.0

func _ready():
	#if get_tree().current_scene is GameManagerMultiplayer: game_root = get_tree().current_scene
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

@rpc("any_peer","call_local")
func set_game():
	if get_tree().current_scene is GameManagerMultiplayer: # Reference to GameManager
		game_root = get_tree().current_scene
		game_root.peer_id = multiplayer.get_unique_id()

func _on_host():
	peer = ENetMultiplayerPeer.new()
	
	var err = peer.create_server(PORT)
	if err != OK: 
		printerr("Server creation failed")
		return
	#peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER) # Breaks connection for some reason -> Fix Later
	multiplayer.multiplayer_peer = peer
	set_game.rpc() # Get reference to Game Scene
	
	# Add the host itself to connected players dict
	player_loaded(multiplayer.get_unique_id())
	set_name_entry()
	#_add_connected_player(multiplayer.get_unique_id())
	print("Player(%s) Connected" % [multiplayer.get_unique_id()])
	print("Waiting for Other Players!")
	
	#if !multiplayer.peer_connected.is_connected(create_player): # Disable for player selection
		#multiplayer.peer_connected.connect(create_player)
	#print("Server created: ", err, ", ", peer)
	#create_player(multiplayer.get_unique_id())

func _on_connect(ip):
	peer = ENetMultiplayerPeer.new()
	
	if !ip.is_empty(): 
		var EXTERNAL_IP = ip
		#print("Connecting to %s..." % [EXTERNAL_IP])
		peer.create_client(EXTERNAL_IP, PORT) # Join w External IP Address (IPv4)
	else: peer.create_client(DEFAULT_IP, PORT) # Join w default IP (127.0.0.1)
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "call_remote", "reliable")
func player_character_chosen(id, scene_path):
	if not multiplayer.is_server():
		return  # Only the server should process this
	
	connected_players[id] = {"player_scene": scene_path}
	sync_connected_players.rpc(connected_players)
	create_player(id)

func create_player(peer_id):
	#print(multiplayer.get_unique_id(), ": connected_players[%s] - %s" % [peer_id,connected_players[peer_id]])
	#print(multiplayer.get_unique_id(), ": connected_players count: ",connected_players.size())
	#var player = load(game_root.players_scenes[player_idx].resource_path).instantiate() # Old
	#player.name = str(peer_id)
	
	if game_root != null and game_root.has_node(str(peer_id)):
		print("Player already exists: ", peer_id)
		return
	
	var player = load(connected_players[peer_id]["player_scene"]).instantiate()
	player.name = str(peer_id)
	
	if multiplayer.is_server():
		var new_server = server.instantiate() # Add server node child
		new_server.name = str(peer_id)
		add_child(new_server)
	
	
	game_root.add_child(player)
	
	#for child in game_root.get_children():
		#if child.is_in_group("Player"):
			#print(multiplayer.get_unique_id(),": ",child.name)
	print(multiplayer.get_unique_id(),": Added child player with peer ID: ", str(peer_id))

@rpc("any_peer", "call_remote", "reliable")
func remove_player(peer_id):
	if game_root != null and game_root.has_node(str(peer_id)):
		var player : PlayerCharacter = game_root.find_player(str(peer_id))
		if player != null:
			player.process_mode = Node.PROCESS_MODE_DISABLED
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(player, "scale", Vector3.ONE/8, 0.25)
			await tween.finished
			if player != null: 
				player.queue_free()
				print(multiplayer.get_unique_id(),": Removed child player with peer ID: ", str(peer_id))


# This gets called on server AND clients
func _on_player_connected(id):
	set_game.rpc() # Get reference to Game Scene
	if multiplayer.is_server(): 
		print("Player(",str(id), ") Connected")
		if game_root: game_root.after_level_loaded.rpc()
	
	if id != 1: 
		player_loaded(id)
		set_name_entry.rpc()
		#_register_player.rpc_id(id, player_info) # Send connecting player's info to others already connected
	
@rpc("any_peer","reliable")
func set_name_entry():
	var id = multiplayer.get_unique_id()
	var label_text = game_root.name_entry.text.capitalize() \
	 if !game_root.name_entry.text.is_empty() else str(id)
	name_entry = label_text
	#print("Server received label from Player[%s]: %s" % [id, label_text])
	
	player_info["name"] = label_text
	if id == 1: 
		_register_player(player_info)
		if connected_players[1].keys().has("player_scene"): connected_players[1].erase("player_scene")
	else: 
		rpc_id(1,"_register_player",player_info)
	#_add_connected_player(id)

func get_display_name(peer_id: int) -> String:
	if connected_players.has(peer_id):
		return connected_players[peer_id].get("name", "Unknown")
	return "Unknown"

#@rpc("any_peer", "call_local", "reliable")
func player_loaded(id):
	if multiplayer.is_server():
		players_loaded += 1
		player_ids.append(id)
		#print("Player loaded - New Player Count: ", str(players_loaded))
		if players_loaded == game_root.players_scenes.size():
			pass
			#print("Max player count reached")
			#start_game()
			#players_loaded = 0

# When a peer connects, set their info from player_info
# When name entry is set, other player peers are informed
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	if new_player_id == 0: new_player_id = 1
	name_exchange_log[new_player_id] = new_player_info
	
	if multiplayer.is_server():
		connected_players[new_player_id] = new_player_info # Issue - Can reset player scene paths from other clients
		if new_player_id == 1 and connected_players[1].keys().has("player_scene"):
			connected_players[1].erase("player_scene")
		if game_root and game_root.has_node(str(new_player_id)): # If this happens, manually add back player scene path
			if connected_players.keys().has(new_player_id):
				if !connected_players[new_player_id].keys().has("player_scene"):
					connected_players[new_player_id]["player_scene"] = game_root.get_node(str(new_player_id)).scene_file_path
		if connected_players.size() == players_loaded: 
			if has_duplicate_names(connected_players): return
			if new_player_id in connected_emitted_by: return
			players_registered.emit()
			connected_emitted_by.append(new_player_id)
		#connected_players[new_player_id] = new_player_info
		sync_connected_players.rpc(connected_players) # Sync after connecting
		#print("SERVER: Sending Info to Player[%s]: %s" % [new_player_id,name_exchange_log[new_player_id]])
	#else: print("CLIENT: Sending Info to Player[%s]: %s" % [new_player_id,name_exchange_log[new_player_id]])
	#if game_root: game_root._on_player_active.rpc(multiplayer.get_unique_id())

@rpc("any_peer","call_remote")
func sync_connected_players(dict:Dictionary):
	#print(multiplayer.get_unique_id(), ": connected_players - %s" % [dict])
	connected_players = dict.duplicate()

func has_duplicate_names(my_dict: Dictionary) -> bool:
	var seen_names := {}
	for key in my_dict:
		var display_name = my_dict[key].get("name")
		if display_name in seen_names:
			return true
		seen_names[display_name] = true
	return false

@rpc("any_peer","call_local")
func reset_values():
	player_info = {"name": "Name"}
	name_entry = ""
	name_exchange_log.clear()
	connected_players.clear()
	players_loaded = 0


# Client Ping Function - Send ping and record time it takes to receive
func do_ping():
	last_ping_time = Time.get_unix_time_from_system()
	ping.rpc() # Assuming you have a node named "Server" with an RPC function "ping"

# Server Ping Functions
@rpc("any_peer")
func ping():
	var sender_id = get_multiplayer().get_remote_sender_id()
	print_ping.rpc(sender_id)

@rpc("any_peer")
func print_ping(_sender_id):
	var pong_time = Time.get_unix_time_from_system() # Receive ping
	var rtt = pong_time - last_ping_time # Get wait time between ping & pong
	var rtt_ms = rtt * 1000 # Convert to ms
	
	if game_root:
		if multiplayer.is_server(): 
			game_root.stats_display.ping.hide()
			return # Don't display ping on host
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			if id == multiplayer.get_unique_id(): 
				game_root.stats_display.ping_val = ceil(rtt_ms)
				break

@rpc("any_peer")
func change_player_name(player,id):
	player.name_label.text = str(id)

@rpc("any_peer")
func request_player_disconnect(id):
	if multiplayer.is_server():
		_on_player_disconnected(id)

func _on_player_disconnected(id):
	#print(multiplayer.get_unique_id(),": Player[%s] Disconnected" % \
	#[connected_players[id]["name"] if connected_players.keys().has(id) else str(id)])
	
	

	
	connected_players.erase(id)
	sync_connected_players.rpc(connected_players) # Sync after disconnecting
	name_exchange_log.erase(id)
	player_disconnected.emit(id)
	remove_player(id)

# Runs when a client connects (only on client)
func _on_connected_ok():
	pass
	#set_game.rpc()
	#player_info["name"] = game_root.name_entry.text if !game_root.name_entry.text.is_empty() else str(peer_id)
	#connected_players[peer_id] = player_info
	
	#name_exchange_log[peer_id] = player_info
	#player_connected.emit()

# Runs when a client fails to connect (only on client)
func _on_connected_fail():
	printerr("Peer Connection Failed")
	multiplayer.multiplayer_peer = null

func stop_server():
	if multiplayer.multiplayer_peer:
		# Ensure all players are removed
		connected_players.clear()
		sync_connected_players.rpc(connected_players)  # Sync disconnection with clients
		multiplayer.multiplayer_peer.close()  # Close the connection gracefully
		multiplayer.multiplayer_peer = null
		_on_server_disconnected()  # Handle further disconnection logic
		print("Server stopped")

func restart():
	var offline_peer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline_peer
	print(self, ": Server Reset | Multiplayer_Peer: ", multiplayer.multiplayer_peer)
	connected_players.clear()
	connected_emitted_by.clear()
	players_loaded = 0
	sync_connected_players.rpc(connected_players)
	name_exchange_log.erase(1)
	#_on_server_started()

func _on_server_started():
	print("Server Restarted - Waiting for Players")


@rpc("any_peer")
func notify_server_shutdown():
	print("Server has shut down, returning to menu")
	#get_tree().multiplayer.close()
	if game_root != null: game_root.switch_to_main_menu()


func _on_server_disconnected():
	print("Server Disconnected")
	if multiplayer.multiplayer_peer: 
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	name_exchange_log.clear()
	server_disconnected.emit()
