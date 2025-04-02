extends Control
class_name QuestPopMenu

# Purpose - Popup menu to display details for most recent active quest

# Node References
@onready var window : Panel = $Panel
@onready var quest_title_label = $Panel/VBoxContainer/Title
@onready var quest_desc_label : RichTextLabel = $Panel/VBoxContainer/Description2
@onready var quest_item_label = $Panel/VBoxContainer/DesiredItem
@onready var quest_checkbox := $Panel/CheckBox

@onready var quest_manager : QuestManager = get_node("/root/QuestManager")

var menu_active : bool = false : set = set_menu_active
var items_acquired : bool = false : set = set_items_acquired
var labels = {}
var sliders = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	window.visible = false

func toggle_quest_menu(open : bool):
	menu_active = open
	if open: animated_pop_up(open)
	else: await animated_pop_up(open)
	window.visible = open

func set_menu_active(active):
	menu_active = active
	
	if active:
		var active_quests_arr = quest_manager.active_quests
		var cur_quest_id = active_quests_arr.keys()[-1]
		var cur_quest = active_quests_arr[cur_quest_id]
		var quest_dict = quest_manager.get_quest_as_dict(cur_quest)
		
		quest_title_label.text = "Quest: "+str(quest_dict["title"])
		quest_desc_label.text = str(quest_dict["description"])

		var item_name = "Find " + quest_dict["desired_item"].get_item_type_name()
		var item_quantity = str(quest_dict["desired_item_quantity"])

		quest_item_label.text = item_name + " X " + item_quantity

func set_items_acquired(collected : bool):
	items_acquired = collected
	# Change label color when player has collected all quest items
	quest_item_label.modulate = Color.GREEN

func quest_completion():
	quest_title_label.modulate = Color.GREEN
	quest_desc_label.modulate = Color.GREEN
	quest_item_label.modulate = Color.GREEN
	quest_checkbox.button_pressed = true

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: pass
			MOUSE_BUTTON_RIGHT: 
				if window.mouse_entered: toggle_quest_menu(!window.visible)

func reset_window_prop():
	window.modulate = Color.WHITE
	quest_title_label.modulate = Color.WHITE
	quest_desc_label.modulate = Color.WHITE
	quest_item_label.modulate = Color.WHITE
	quest_checkbox.button_pressed = false

func animated_pop_up(open : bool):
	reset_window_prop()
	match open:
		true:
			window.scale = Vector2.ONE/8
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(window, "scale", Vector2.ONE, 0.1)
			await tween.finished
		false:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(window, "scale", Vector2.ONE/8, 0.1)
			await tween.finished
