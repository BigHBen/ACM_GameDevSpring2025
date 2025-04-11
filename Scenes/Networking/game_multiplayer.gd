extends Node
class_name  GameManagerMultiplayer

# Autoload scene
@export var debug : TestDebug

@onready var level_container : Node = $Level
var cur_level : Node3D = null :
	set(val):
		cur_level = val
		debug.load_dialogue_nodes()

var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): 
			var scene_name = get_scene_name(levels[level_itr].resource_path)
			print(self.name, ": Preparing to load ",level_itr," ", scene_name)
			change_level(levels[level_itr],level_itr)
			#if multiplayer.is_server(): request_level_change.rpc(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@export var players : Array[CharacterBody3D]
@export var players_scenes : Array[PackedScene]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]

# UI Nodes
@onready var pause_menu : Control = $UI/PauseMenu
@onready var stats_display : Control = $UI/StatsDisplay
@onready var direct_menu : PanelContainer = $Multiplayer_UI/UI/PanelContainer
@onready var address_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var ip_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var name_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/NameEntry
@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

# Sync
#@onready var multi_sync : MultiplayerSynchronizer = $MultiplayerSynchronizer

# Conditions
var input_handling : bool = false
var multiplayer_pvp : bool = false
#const PORT = 9999
#var peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
#var player_idx : int = 0
#var player_info = {"name": "Name"}
#
#var players_loaded = 0

signal _on_game_paused(is_paused : bool)
var game_paused : bool = false :
	set(val):
		game_paused = val
		#get_tree().paused = game_paused # No pausing in multiplayer
		if multiplayer.has_multiplayer_peer(): update_pause_state.rpc(val)
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

signal _on_player_defeat(p_defeat_info : Array)
var player_defeat : Array = []:
	set(val):
		if val.size() > 1: player_defeat = [val[0],val[1]]
		else: player_defeat = []
		_on_player_defeat.emit(player_defeat)
	get:
		return player_defeat

@rpc("any_peer") #*Not Used*
func update_pause_state(_val):
	var sender_id = multiplayer.get_remote_sender_id()
	var _player = find_player(str(sender_id))
	#if player.process_mode == 1: get_tree().paused = true

func _ready() -> void:
	multiplayer_setup()
	multiplayer_ui_setup()
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		#get_tree().call_deferred("quit") # Removed for multiplayer testing
	#else: load_first_level()

func get_scene_name(node_path : String):
	return node_path.right(-node_path.rfind("/") - 1).left(-5)

func _input(event: InputEvent) -> void:
	if !input_handling: return
	if event.is_action_pressed("pause_game"):
		game_paused = !game_paused
	if event.is_action_pressed("test_level_skip"): # Autoskip levels - Testing
		if level_itr >= 0: 
			if multiplayer.is_server():
				next_level() # SERVER LEVEL SKIP
			else: request_next_level.rpc() # CLIENT LEVEL SKIP
		else: load_first_level()
#@rpc
#func request_level_change(level: PackedScene):
	#for peer in get_tree().network_peer.get_peers():
		#change_level.rpc_id(peer, level)

func change_level(new_level_scene: PackedScene,_idx):
	var current_level = level_container.get_child(0) if level_container.get_child_count() > 0 else null
	if current_level and current_level.is_in_group("Level"):
		print(self.name,": deleting ", current_level)
		current_level.call_deferred("queue_free")
	
	var path = new_level_scene.resource_path
	var _scene_name = get_scene_name(path)
	var new_level : Node3D = load(path).instantiate()
	
	#new_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	for player in players: 
		if player != null:
			player.update_spawn_position.rpc(new_level.player_spawn_point)
			#player.position = new_level.player_spawn_point
			player.interact.entered_areas.clear()
	
	level_container.add_child(new_level, true)
	new_level.owner = get_tree().current_scene
	#new_level.name = scene_name
	
	#self.move_child(new_level,0)
	print(self,": Added ",new_level)
	#sync_level(new_level.get_path())
	after_level_loaded.rpc()

@rpc("any_peer","call_local")
func after_level_loaded():
	self.ui_control.ui_fade_reset(1.0) # Undo UI fade effect

@rpc("any_peer","call_local")
func request_next_level():
	print("REQUEST: ",multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		print("switching level via client")
		next_level()


func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1

func multiplayer_setup():
	pass

func multiplayer_ui_setup():
	pause_menu.tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds

# Multiplayer section
func _on_host_pressed() -> void:
	direct_menu.hide()
	lobby._on_host()
	input_handling = true
	
	if level_itr > 0: next_level()
	else: load_first_level()
	#peer.create_server(PORT)
	#multiplayer.multiplayer_peer = peer
	#
	#multiplayer.peer_connected.connect(create_player)
	#create_player(multiplayer.get_unique_id())

func _on_connect_pressed() -> void:
	direct_menu.hide()
	lobby._on_connect()
	input_handling = true
	#peer.create_client("localhost", PORT)
	#multiplayer.multiplayer_peer = peer

#func create_player(peer_id):
	#print(player_idx)
	#var player = load(players_scenes[player_idx].resource_path).instantiate()
	#player.name = str(peer_id)
	#
	#add_child(player)
	#print("Created player with peer ID:", str(peer_id))

#@rpc("any_peer", "call_local", "reliable")
#func player_loaded():
	#if multiplayer.is_server():
		#players_loaded += 1
		#if players_loaded == players.size():
			#start_game()
			#players_loaded = 0

func find_player(player_name : String):
	for player in players:
		if player != null and player.name == player_name:
			return player
	return null

func get_players():
	return players

func get_npcs():
	var npcs : Array
	if cur_level: 
		for child in cur_level.get_children():
			if child.is_in_group("NPC"):
				npcs.append(child)
	return npcs

func _on_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Player"):
		players.append(node)
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		stats_display.show()
		lobby.player_loaded.rpc_id(node.name.to_int())

func _on_child_exiting_tree(node: Node) -> void:
	if node.is_in_group("Player"):
		players.erase(node)
		stats_display.hide()


func _on_level_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Level"):
		cur_level = node

func setup_debug(player):
	if debug: debug.get_player_properties(player)

func _on_name_entry_text_submitted(_new_text: String) -> void:
	pass

# MultiplayerSpawner - spawn nodes between host/client players
func _on_multiplayer_spawner_spawned(_node: Node) -> void:
	pass
	#print("Spawner: Node spawned of type:", node.name, " on peer:", multiplayer.get_unique_id())
	#print("Spawner: Spawned node name:", node.name)

func _on_level_spawner_spawned(_node: Node) -> void:
	pass
	#print(self,": Spawned ", node)
	#print(players)
