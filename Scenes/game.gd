extends Node
class_name GameManager

@export var debug : TestDebug
@onready var quests_popup : QuestPopMenu = get_node("/root/QuestPopupMenu")
@onready var scene_manager : ScenesList = get_node("/root/SceneManager")
@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

@onready var level_container : Node = $Level
var cur_level : Node3D = null :
	set(val):
		cur_level = val
		debug.load_dialogue_nodes()

var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): change_level(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@onready var pause_menu : Control = $UI/PauseMenu
@export var players : Array[CharacterBody3D]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]

signal _on_game_paused(is_paused : bool)
var game_paused : bool = false :
	set(val):
		game_paused = val
		get_tree().paused = game_paused
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

var dialogue_debug_active : bool = false

signal _on_player_defeat(p_defeat_info : Array)
var player_defeat : Array = []:
	set(val):
		if val.size() > 1: player_defeat = [val[0],val[1]]
		else: player_defeat = []
		_on_player_defeat.emit(player_defeat)
	get:
		return player_defeat

func _ready() -> void:
	# Set multiplayer_active here so the autoload knows which mode we're in.
	# Both scenes use lobby autoload, so we need to set it when the scene starts.
	lobby.multiplayer_active = false 
	ui_setup()
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		get_tree().call_deferred("quit")
	#else: load_first_level()

func ui_setup():
	pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds

func initialize(player_scene : PackedScene):
	var player = player_scene.instantiate()
	add_child(player)
	self.move_child(player,1)
	players[0] = player
	start_game()

func start_game():
	load_first_level()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		game_paused = !game_paused
	if event.is_action_pressed("test_level_skip"): # Autoskip levels - Testing
		if level_itr >= 0: next_level()
		else: load_first_level()

func change_level(new_level_scene: PackedScene):
	var current_level = level_container.get_child(0) if level_container.get_child_count() > 0 else null
	if current_level and current_level.is_in_group("Level"):
		current_level.call_deferred("queue_free")
	
	var new_level : Node3D = load(new_level_scene.resource_path).instantiate()
	new_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	for player in players:
		if player != null: 
			player.position = new_level.player_spawn_point
			player.interact_manager.entered_areas.clear()
	
	level_container.add_child(new_level)
	new_level.owner = get_tree().current_scene
	#self.move_child(new_level,0)
	after_level_loaded()

func after_level_loaded():
	for player in players:
		if debug: debug.get_player_properties(player)
	self.ui_control.ui_fade_reset(1.0) # Undo UI fade effect
	quests_popup.reset() # Close any quest popup windows
	quests_popup.toggle_quest_menu(false)

func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1

func switch_to_main_menu(): # Resets game
	var main_menu_scene = scene_manager.scenes_packed[scene_manager.SCENES.MAIN_MENU]
	scene_manager.skip_titlecard = true
	print(self,": Returning to Main Menu...")
	get_tree().change_scene_to_packed(main_menu_scene)

func find_player(player_name : String):
	for player in players:
		if player != null and player.name == player_name:
			return player
	return null

func get_npcs():
	var npcs : Array
	if cur_level: 
		for child in cur_level.get_children():
			if child.is_in_group("NPC"):
				npcs.append(child)
	return npcs


func get_players():
	return players


func _on_level_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Level"):
		cur_level = node
