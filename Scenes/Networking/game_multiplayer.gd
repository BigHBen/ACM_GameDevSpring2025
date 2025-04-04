extends Node
class_name  GameManagerMultiplayer

# Autoload scene
@export var debug : TestDebug

var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): 
			var scene_name = get_scene_name(levels[level_itr].resource_path)
			print(self.name, ": Preparing to load ", scene_name)
			change_level(levels[level_itr])
			#if multiplayer.is_server(): request_level_change.rpc(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@export var players : Array[CharacterBody3D]
@export var players_scenes : Array[PackedScene]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]

# Multiplayer Section

# UI Nodes
@onready var pause_menu : Control = $UI/PauseMenu
@onready var stats_display : Control = $UI/StatsDisplay
@onready var direct_menu : PanelContainer = $Multiplayer_UI/UI/PanelContainer
@onready var address_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var ip_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var name_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/NameEntry
@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

# Sync
@onready var multi_sync : MultiplayerSynchronizer = $MultiplayerSynchronizer

var input_handling : bool = false
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
		get_tree().paused = game_paused
		if multiplayer.has_multiplayer_peer(): update_pause_state.rpc(val)
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

@rpc("any_peer")
func update_pause_state(_val):
	var sender_id = multiplayer.get_remote_sender_id()
	var _player = find_player(str(sender_id))
	#if player.process_mode == 1: get_tree().paused = true

func _ready() -> void:
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
	if event.is_action_pressed("ui_accept"):
		if level_itr > 0: next_level()
		else: load_first_level()
#@rpc
#func request_level_change(level: PackedScene):
	#for peer in get_tree().network_peer.get_peers():
		#change_level.rpc_id(peer, level)

func change_level(new_level_scene: PackedScene):
	var current_level = get_child(0)
	if current_level.is_in_group("Level"):
		print(self.name,": deleting ", current_level)
		current_level.call_deferred("queue_free")
	
	var path = new_level_scene.resource_path
	var scene_name = get_scene_name(path)
	var new_level : Node3D = load(path).instantiate()
	
	new_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	for player in players: 
		player.position = new_level.player_spawn_point
		player.interact.entered_areas.clear()
	connect_debug_properties(new_level)
	self.add_child(new_level, true)
	new_level.owner = get_tree().current_scene
	#new_level.name = scene_name
	self.move_child(new_level,0)
	print(self.name," Added ",new_level)
	
	sync_level(new_level.get_path())

func sync_level(new_level):
	var replication_config = SceneReplicationConfig.new()
	replication_config.add_property(new_level)
	#print(replication_config.get_properties())
	#multi_sync.replication_config = replication_config
	#multi_sync.set_multiplayer_authority(str().to_int())
	#print("MultiplayerSynchronizer for unit", unit.get_name(), ":", multiplayer_synchronizer)

func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1

func multiplayer_ui_setup():
	pause_menu.tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds

# Set up a signal for when player spawns in level - Load its properties on debug menu
func connect_debug_properties(from) -> bool:
	for child in from.get_children():
		if child.is_in_group("Player"): 
			var _player : PlayerCharacter = child
			child.queue_free()
			#player.ready.connect(debug.get_player_properties.bind(player))
			return true
	return false

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
		if player.name == player_name:
			return player
	return null

func _on_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Player"):
		players.append(node)
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		stats_display.show()
		lobby.player_loaded.rpc_id(node.name.to_int())

func setup_debug(player):
	if debug: debug.get_player_properties(player)

func _on_name_entry_text_submitted(_new_text: String) -> void:
	pass
