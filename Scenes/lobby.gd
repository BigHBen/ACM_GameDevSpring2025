extends Node
class_name Lobby

var game_root : GameManagerMultiplayer

const DEFAULT_IP = '127.0.0.1' # Localhost
const PORT = 9999
var peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var player_idx : int = 0
var player_info = {"name": "Name"}

var active_players = {}
var players_loaded = 0

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

func _ready():
	if get_tree().current_scene is GameManagerMultiplayer: game_root = get_tree().current_scene
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_host():
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(create_player)
	create_player(multiplayer.get_unique_id())

func _on_connect():
	if !game_root.ip_entry.text.is_empty(): 
		var EXTERNAL_IP = game_root.ip_entry.text
		print("Connecting to %s..." % [EXTERNAL_IP])
		peer.create_client(EXTERNAL_IP, PORT)
	else: peer.create_client(DEFAULT_IP, PORT)
	multiplayer.multiplayer_peer = peer

func create_player(peer_id):
	var player = load(game_root.players_scenes[player_idx].resource_path).instantiate()
	player.name = str(peer_id)
	
	game_root.add_child(player)
	print("Created player with peer ID: ", str(peer_id))

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		
		print("Player loaded - New Player Count: ", str(players_loaded))
		if players_loaded == game_root.players_scenes.size():
			pass
			#print("Max player count reached")
			#start_game()
			#players_loaded = 0

func _on_player_connected(id):
	player_info["name"] = game_root.name_entry.text if !game_root.name_entry.text.is_empty() else id
	_register_player.rpc_id(id, player_info)

# When a peer connects, set their info from player_info
# When name entry is set, other player peers are informed
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	active_players[new_player_id] = new_player_info
	if multiplayer.is_server():
		print("HOST: Setting Info for Player[%s]: %s" % [new_player_id,active_players[new_player_id]])
	else: print("CLIENT: Setting Info for Player[%s]: %s" % [new_player_id,active_players[new_player_id]])
	player_connected.emit(new_player_id, new_player_info)

@rpc("authority")
func is_name_available(info : Dictionary):
	print(info)
	rpc_id(multiplayer.get_remote_sender_id(),"name_verified")

@rpc("authority")
func name_verified():
	var sender = get_tree().get_rpc_sender_id()
	var _approved : bool = false
	print("Name verification for sender: ", sender)

func _on_player_disconnected(id):
	active_players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	active_players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	printerr("Peer Connection Failed")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	active_players.clear()
	server_disconnected.emit()
