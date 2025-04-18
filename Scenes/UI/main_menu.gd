extends Node


@onready var title : Label = $CanvasLayer/Main/Title
@onready var single_player_button : Button = $CanvasLayer/Main/VBoxContainer/SinglePlayer
@onready var multiplayer_button : Button = $CanvasLayer/Main/VBoxContainer/Multiplayer
@onready var option_button : Button = $CanvasLayer/Main/VBoxContainer/Options
@onready var quit_button : Button = $CanvasLayer/Main/VBoxContainer/Exit

@onready var anim_player : AnimationPlayer = $CanvasLayer/Main/AnimationPlayer

# Level Loading
@export var levels : Array[PackedScene]

# Settings Menu
@onready var settings_menu : Panel = $CanvasLayer/Settings
@onready var settings_back : Button = $CanvasLayer/Settings/VBoxContainer/Back_to_Main
@onready var res_options_button : OptionButton = $CanvasLayer/Settings/VBoxContainer/Window_Select/OptionButton
@onready var fs_checkbox : CheckBox = $CanvasLayer/Settings/VBoxContainer/Fullscreen_Select/FullscreenCheck

@onready var titlecard : Control = $CanvasLayer/TitleCard

var button_default_fpntsize = 50.0
var button_pop_fontsize = 75.0
var button_pop_duration = 0.15

# Title Label Stuff
var default_pos
var dragging := false :
	set(val):
		dragging = val
		
		if !dragging:
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(title, "position", default_pos, 1)

var drag_offset := Vector2.ZERO
var time := 0.0
var wobble_strength := 10.0  # How far it moves
var wobble_speed := 8.0      # How fast it wobbles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if levels.size() > 0:
		if !levels[0]: 
			printerr("First levels[Array[PackedScene]] Index MUST be GameManager (SinglePlayer)")
			return
		if !levels[1]: 
			printerr("Second levels[Array[PackedScene]] Index MUST be GameManagerMultiplayer (Multiplayer)")
			return
	setup_settings(settings_menu)
	
	
	$CanvasLayer/Main.hide()
	load_titlecard()
	
	default_pos = title.position
	
	single_player_button.pressed.connect(_on_single_player_pressed)
	single_player_button.mouse_entered.connect(_on_singleplayer_hovered)
	single_player_button.mouse_exited.connect(_on_singleplayer_unhovered)
	
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	multiplayer_button.mouse_entered.connect(_on_multiplayer_hovered)
	multiplayer_button.mouse_exited.connect(_on_multiplayer_unhovered)
	
	option_button.pressed.connect(_on_options_pressed)
	option_button.mouse_entered.connect(_on_options_hovered)
	option_button.mouse_exited.connect(_on_options_unhovered)
	
	quit_button.pressed.connect(_on_exit_game)
	quit_button.mouse_entered.connect(_on_quit_hovered)
	quit_button.mouse_exited.connect(_on_quit_unhovered)
	
	settings_back.pressed.connect(_on_back_button_pressed)

func load_titlecard():
	$CanvasLayer/TitleCard.show()
	$CanvasLayer/TitleCard/TextureRect.modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property($CanvasLayer/TitleCard/TextureRect, "modulate", Color.WHITE, 1.0)
	await get_tree().create_timer(3).timeout
	if titlecard.visible: close_titlecard()

func close_titlecard():
	var tween2 = create_tween()
	tween2.set_trans(Tween.TRANS_LINEAR)
	tween2.set_ease(Tween.EASE_IN_OUT)
	tween2.tween_property($CanvasLayer/TitleCard, "modulate", Color(1,1,1,0), 1.0)
	
	$CanvasLayer/Main.show()
	$CanvasLayer/Main.modulate = Color(1,1,1,0)
	var tween3 = create_tween()
	tween3.set_trans(Tween.TRANS_LINEAR)
	tween3.set_ease(Tween.EASE_IN_OUT)
	tween3.tween_property($CanvasLayer/Main, "modulate", Color.WHITE, 1.0)
	await tween2.finished
	titlecard.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time += delta/2 
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and title.mouse_entered:
		dragging = true
		drag_offset = get_viewport().get_mouse_position() - title.size/2
	else: 
		dragging = false
	
	if dragging: title.position = drag_offset
	
	var offset_x = sin(time * 6.5) * 12
	var offset_y = cos(time * 8) * 6
	title.position = Vector2(offset_x, offset_y+150)
	title.scale = Vector2(1 + sin(time * 5) * 0.05, 1 + cos(time * 7) * 0.05)
	title.rotation = sin(time * 3) * 0.1

func move_out_of_frame(s,dist : float, target_position):
	var tween = create_tween()
	if target_position == null: target_position = Vector2(s.position.x,DisplayServer.screen_get_size().y + dist)  # Move completely off the screen to the left
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(s, "position", target_position, 0.5)
	
	#fade_in($settings.get_child(0),0.25)
	await tween.finished
	

func move_into_frame(s,start, target_position):
	if start: s.position = start
	var tween = create_tween()
	
	#var target_position = Vector2(0, 0)  # Move completely off the screen to the left
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(s, "position", target_position, 0.5)
	

func tween_font_size_property(node: Node,target_value: float, duration: float):
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "theme_override_font_sizes/font_size", target_value, duration)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and titlecard.visible: close_titlecard()
	if Input.is_action_just_pressed("pause_game"):
		if settings_menu.visible: 
			# Switch back to main
			var settings_end = Vector2(0, 0)
			move_into_frame($CanvasLayer/Main,null,settings_end)
			await move_out_of_frame(settings_menu, 100,Vector2(251,-DisplayServer.screen_get_size().y))
			close_settings(settings_menu)

func _on_back_button_pressed() -> void:
	# Switch back to main
	var settings_end = Vector2(0, 0)
	move_into_frame($CanvasLayer/Main,null,settings_end)
	await move_out_of_frame(settings_menu, 100,Vector2(251,-DisplayServer.screen_get_size().y))
	close_settings(settings_menu)

func on_resolution_selected(index: int) -> void:
	DisplayServer.window_set_size(res_options_button.RESOLUTION_DICT.values()[index])

func fade_out(s,sec:float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(s, "color", Color(0, 0, 0, 1), sec)
	await tween.finished

func setup_settings(cont):
	fs_checkbox.toggled.connect(_on_fullscreen_toggle)
	res_options_button.add_resolution_items()
	res_options_button.item_selected.connect(on_resolution_selected)
	cont.visible = false

func open_settings(cont):
	cont.visible = true

func close_settings(cont):
	cont.visible = false

# Signal
func _on_single_player_pressed():
	var game_manager = levels[0]
	await fade_out($CanvasLayer/Main/Change_Fade,2.0)
	get_tree().change_scene_to_packed(game_manager)

func _on_multiplayer_pressed():
	var game_manager_multiplayer = levels[1]
	await fade_out($CanvasLayer/Main/Change_Fade,2.0)
	get_tree().change_scene_to_packed(game_manager_multiplayer)


func _on_fullscreen_toggle(toggled_on):
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_options_pressed():
	if !settings_menu.visible:
		move_out_of_frame($CanvasLayer/Main, 100,null)
		open_settings(settings_menu)
		var settings_start = Vector2(251,-DisplayServer.screen_get_size().y)
		var settings_end = Vector2(251, 191)
		move_into_frame(settings_menu,settings_start,settings_end)

func _on_singleplayer_hovered():
	tween_font_size_property(single_player_button,button_pop_fontsize,button_pop_duration)

func _on_multiplayer_hovered():
	tween_font_size_property(multiplayer_button,button_pop_fontsize,button_pop_duration)

func _on_options_hovered():
	tween_font_size_property(option_button,button_pop_fontsize,button_pop_duration)

func _on_singleplayer_unhovered():
	tween_font_size_property(single_player_button,button_default_fpntsize,button_pop_duration)

func _on_multiplayer_unhovered():
	tween_font_size_property(multiplayer_button,button_default_fpntsize,button_pop_duration)

func _on_options_unhovered():
	tween_font_size_property(option_button,button_default_fpntsize,button_pop_duration)

func _on_quit_hovered():
	tween_font_size_property(quit_button,button_pop_fontsize,button_pop_duration)

func _on_quit_unhovered():
	tween_font_size_property(quit_button,button_default_fpntsize,button_pop_duration)

func _on_exit_game():
	get_tree().quit()

func _on_title_mouse_exited() -> void:
	print("erm")
