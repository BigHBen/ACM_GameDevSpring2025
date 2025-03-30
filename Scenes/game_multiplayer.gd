extends Node
class_name  GameManagerMultiplayer

# Autoload scene
@onready var debug : TestDebug = get_node("/root/Debug")

var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): change_level(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@export var players : Array[CharacterBody3D]
@export var players_scenes : Array[PackedScene]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]

# Multiplayer Section

# UI Nodes
@onready var direct_menu : PanelContainer = $Multiplayer_UI/UI/PanelContainer
@onready var address_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Options/Remote
@onready var name_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Options/NameEntry
@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

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
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

func _ready() -> void:
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		#get_tree().call_deferred("quit") # Removed for multiplayer testing
	else: load_first_level()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		game_paused = !game_paused

func change_level(new_level_scene: PackedScene):
	var current_level = get_child(0)
	if current_level.is_in_group("Level"):
		current_level.call_deferred("queue_free")
	
	var new_level : Node3D = load(new_level_scene.resource_path).instantiate()
	connect_debug_properties(new_level)
	for player in players: 
		player.position = new_level.player_spawn_point
		player.interact.entered_areas.clear()
	self.add_child(new_level)
	new_level.owner = get_tree().current_scene
	self.move_child(new_level,0)


func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1

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
	#peer.create_server(PORT)
	#multiplayer.multiplayer_peer = peer
	#
	#multiplayer.peer_connected.connect(create_player)
	#create_player(multiplayer.get_unique_id())

func _on_connect_pressed() -> void:
	direct_menu.hide()
	lobby._on_connect()
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

func _on_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Player"): 
		lobby.player_loaded.rpc_id(node.name.to_int())


func _on_name_entry_text_submitted(_new_text: String) -> void:
	pass
