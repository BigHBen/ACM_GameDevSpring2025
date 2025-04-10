extends Control
class_name TestDebug

var target_player : CharacterBody3D = null : set = set_target_player
@onready var fps_toggle : CheckButton = $Panel/VBoxContainer/FPSmode 
@onready var ping_toggle : CheckButton = $Panel/VBoxContainer/PINGmode
@onready var game : Node

var panel_size : Vector2
var panel_initial : int = 50

var fps_meter : Label
var debug_active : bool = false : set = set_debug_active, get = get_debug_active
var fps_show : bool = false

var ping_meter : Label
var ping_show: bool = false

var labels = {}
var sliders = {}

signal fps_vis(active)
signal ping_vis(active)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_parent() is GameManager or get_parent() is GameManagerMultiplayer: game = get_parent()
	get_player_properties(null)
	$Panel.size_flags_vertical = SIZE_EXPAND | SIZE_FILL
	hide()
	fps_toggle.toggled.connect(_on_fps_show_toggle)
	if game is GameManagerMultiplayer:
		ping_toggle.toggled.connect(_on_ping_show_toggle)
	else: ping_toggle.hide()

func set_target_player(val):
	target_player = val

func get_player_properties(player):
	target_player = player
	if target_player or get_target_player() != null:
		if game is GameManagerMultiplayer:
			load_properties()
		elif game is GameManager:
			load_properties()
	else: 
		#printerr("Debug (Autoload): Current scene is not GameManager.. ")
		pass
	

# Searches scene tree and returns first character in 'Player' group
func get_target_player():
	var scene_root = get_tree().current_scene
	if scene_root.get_child_count() > 0:
		for character in find_characters_in_level(scene_root):
			if character.is_in_group("Player"):
				target_player = character
				return character
	if game and !game.players.is_empty(): 
		target_player = game.players.front()
		return game.players.front()
	return null

# Returns all character bodies from current level
func find_characters_in_level(root_scene):
	var level = root_scene.get_child(0)
	# Assume current scene is Level if root isn't GameManager
	if !level.is_in_group("Level"): level = get_tree().current_scene 
	var players = []
	for child in level.get_children():
		if child is CharacterBody3D:
			players.append(child)
	return players

func load_properties():
	if game is GameManagerMultiplayer:
		if is_multiplayer_authority():
			print("SERVER: ", self, " Loading player properties for ",target_player)
		else: print("CLIENT: ", self, " Loading player properties for ",target_player)
	var player_script = target_player.get_script()
	var properties = player_script.get_script_property_list()
	create_property_labels(target_player,properties)

func _process(_delta: float) -> void:
	#fps_meter.text = "FPS - " + str(Engine.get_frames_per_second())
	pass

func debug_pause_game():
	var scene_root = get_tree().current_scene
	if scene_root is GameManager: scene_root.game_paused = true

# Access @export variables from player node script
# Create sliders for each @export variable
# Currently uses float variables only

func create_property_labels(player,properties):
	# Iterate over the properties
	var total_height = $Panel/VBoxContainer.size.y
	var vboxseparation = $Panel/VBoxContainer.get_theme_constant("separation")
	for property in properties:
		if property.usage & PROPERTY_USAGE_STORAGE:
			var property_name : StringName = property.name
			var property_type = property.type
			
			if property_name in labels:
				labels[property_name].text = "%s - %.1f" % [property_name.capitalize(),player.get(property_name)]
				sliders[property_name][0].value = player.get(property_name)
			else:
				match property_type: 
					3: # Check if property (script variable) is float
						var label = Label.new()
						label.name = property_name
						label.text = "%s - %.1f" % [property_name.capitalize(), player.get(property_name)]
						label.size = Vector2(200, 20)
						$Panel/VBoxContainer.add_child(label)
						total_height += label.size.y + vboxseparation
						labels[property_name] = label
						var slider = HSlider.new()
						var range_values = property.hint_string.split(",")
						if range_values.size() == 2:
							var min_val = float(range_values[0].strip_edges())
							var max_val = float(range_values[1].strip_edges())
							slider.min_value = min_val
							slider.max_value = max_val
							var range_size = max_val - min_val
							if range_size < 1.0:
								slider.step = 0.0005
							elif range_size < 10.0:
								slider.step = 0.01
							elif range_size < 100.0:
								slider.step = 0.1
							else:
								slider.step = 1.0
						else:
							slider.min_value = 0.01
							slider.max_value = 100.0
							slider.step = 0.1
						slider.name = property_name + "_slider"
						slider.focus_mode = Control.FOCUS_ALL
						slider.mouse_filter = Control.MOUSE_FILTER_PASS
						slider.value = player.get(property_name)
						$Panel/VBoxContainer.add_child(slider)
						total_height += slider.size.y + vboxseparation
						sliders[property_name] = [slider,player]
						slider.value_changed.connect(_on_slider_value_changed.bind([property_name, label, player]))
	update_panel_size(total_height,vboxseparation)

func update_panel_size(vbox_height,separation):
	$Panel.size.y = vbox_height + separation

func _input(event: InputEvent) -> void:
	if game is GameManagerMultiplayer and !game.input_handling: return
	# Show/Hide Debug Interface
	if event.is_action_pressed("debug"):
		self.visible = !self.visible
		debug_active = !debug_active
		set_process(debug_active)

func set_debug_active(active : bool):
	debug_active = active
	if active: fps_toggle.grab_focus()

func get_debug_active() -> bool:
	return debug_active


# Change @export variables from debug slider nodes
func _on_slider_value_changed(value: float, prop_name: Array):
	var target : CharacterBody3D = null
	if prop_name.size() == 3: target = prop_name.back()
	#if is_multiplayer_authority():
		#print("SERVER: Attempting to change ", prop_name, " for ",target)
	#else: print("CLIENT: Attempting to change ", prop_name, " for ",target)
	target.set(prop_name[0],value)
	var property_label = $Panel/VBoxContainer.get_node_or_null(prop_name[1].get_path())
	property_label.text = "%s - %s" % [prop_name[0].capitalize(),value]


# Refresh target player after switch
func _on_player_target_switched():
	if get_target_player() != null:
		load_properties()

func _on_fps_show_toggle(active):
	fps_show = active
	fps_vis.emit(fps_show)
	#mouse_filter = MOUSE_FILTER_PASS if active else MOUSE_FILTER_STOP # Prevent Control node from blocking mouse movement (not working)

func _on_ping_show_toggle(active):
	ping_show = active
	ping_vis.emit(ping_show)
