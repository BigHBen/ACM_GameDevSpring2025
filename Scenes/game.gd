extends Node
class_name GameManager

@export var debug : TestDebug


var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): change_level(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
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

func _ready() -> void:
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		get_tree().call_deferred("quit")
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
