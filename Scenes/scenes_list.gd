class_name ScenesList extends Node

enum SCENES {MAIN_MENU, SINGLE_PLAYER, MULTIPLAYER}
var item_type_map = [
	0,  # MAIN_MENU
	1,  # SINGLE_PLAYER
	2,  # MULTIPLAYER
]

@export var main_menu_scene : PackedScene
@export var player_selection_scene : PackedScene
@export var single_player_scene : PackedScene
@export var multi_player_scene : PackedScene
@export var loading_screen : PackedScene

var scenes_packed := {}
var scene_paths := {}
const SCENES_LIST_NAMES := ["MAIN_MENU", "SELECTION", "SINGLE_PLAYER", "MULTIPLAYER"]

var target_scene_path := ""
var loading_screen_inst = null

var skip_titlecard : bool = false :
	set(val): skip_titlecard = val
	get(): return skip_titlecard

func _ready() -> void:
	
	scenes_packed = {
		SCENES.MAIN_MENU: main_menu_scene,
		SCENES.SINGLE_PLAYER: single_player_scene,
		SCENES.MULTIPLAYER: multi_player_scene,
	}
	scene_paths = {
		SCENES.MAIN_MENU: main_menu_scene.resource_path,
		SCENES.SINGLE_PLAYER: single_player_scene.resource_path,
		SCENES.MULTIPLAYER: multi_player_scene.resource_path,
	}

func change_scene_with_loading(scene_path: String,_args: Array = []):
	loading_screen_inst = loading_screen.instantiate()
	loading_screen_inst._initialize(scene_path)
	loading_screen_inst.scene_loading_finished.connect(_on_scene_loaded)
	add_child(loading_screen_inst)

func _on_scene_loaded():
	#get_tree().current_scene.queue_free()
	if loading_screen_inst: loading_screen_inst.queue_free()
