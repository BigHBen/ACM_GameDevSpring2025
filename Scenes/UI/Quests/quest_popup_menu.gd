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
var menu_active_quest : int = -1
var items_acquired : bool = false : set = set_items_acquired
var items_acquired_quest : int = -1
var quest_complete_id : int = -1
var labels = {}
var sliders = {}

var menu_windows : Dictionary = {}
var menu_windows_pos_y : float = 0.0 # Reposition each added quest window (y position only)

var menu_windows_tmp : Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	window.visible = false

@rpc("any_peer","call_local")
func toggle_quest_menu(open : bool,quest_id : int = -1):
	if quest_id != -1: menu_active_quest = quest_id
	menu_active = open
	if open: animated_pop_up(open)
	else: await animated_pop_up(open)
	if menu_active_quest != -1: check_if_quest_active(menu_active_quest,open)
	else: 
		for w in menu_windows.values():
			w.visible = open

#@rpc("any_peer","call_local")
#func toggle_quest_menu_remote(open : bool, quest_id : int = -1):
	#if quest_id != -1: menu_active_quest = quest_id
	#menu_active = open
	#if open: animated_pop_up(open)
	#else: await animated_pop_up(open)
	#if menu_active_quest != -1: check_if_quest_active(menu_active_quest, open)
	#else: 
		#for w in menu_windows.values():
			#w.visible = open

func check_if_quest_active(_quest_id,open):
	if menu_windows.keys().has(menu_active_quest):
		#print("Found popup window: ",menu_windows[menu_active_quest])
		menu_windows[menu_active_quest].visible = open
		
		if quest_manager.active_quests.has(menu_active_quest): 
			if quest_manager.active_quests[menu_active_quest].is_completed: pass
		else:
			#print("Deleting popup window: ",menu_active_quest)
			menu_windows_tmp = menu_windows.keys()
			menu_windows[menu_active_quest].queue_free()
			menu_windows.erase(menu_active_quest)
			adjust_other_windows()

func adjust_other_windows(): # Move every popup window positioned above deleted
	#print("Old %s -> New %s" % [menu_windows_tmp,menu_windows.keys()])
	var new_keys = menu_windows.keys()
	var deleted_key = null
	for key in menu_windows_tmp:
		if not new_keys.has(key):
			deleted_key = key
			break
	
	if deleted_key != null:
		var deleted_index = menu_windows_tmp.find(deleted_key)
		for i in range(deleted_index + 1, menu_windows_tmp.size()):
			var key = menu_windows_tmp[i]
			if new_keys.has(key):
				var node = menu_windows.get(key)
				if node:
					node.position.y += node.size.y + 10.0
					menu_windows_pos_y += node.size.y + 10.0

# Create a popup window for new quest
func set_menu_active(active):
	menu_active = active
	if active and !quest_manager.active_quests.is_empty(): 
		var active_quests_arr = quest_manager.active_quests
		if active_quests_arr.size() > 0 and menu_active_quest != -1:
			if menu_windows.keys().has(menu_active_quest): return
			var new_quest_window : Panel = window.duplicate()
			if active_quests_arr.size() == 1: menu_windows_pos_y = new_quest_window.position.y
			new_quest_window.position.y = menu_windows_pos_y
			menu_windows_pos_y -= new_quest_window.size.y + 10.0 # Next added quest window will be positioned higher
			add_child(new_quest_window)
			
			menu_windows[menu_active_quest] = new_quest_window
			var cur_quest_id = menu_active_quest
			var cur_quest = active_quests_arr[cur_quest_id]
			var quest_dict = quest_manager.get_quest_as_dict(cur_quest)
			var item_name = "Find " + quest_dict["desired_item"].get_item_type_name()
			var item_quantity = str(quest_dict["desired_item_quantity"])
			
			for i in range(new_quest_window.get_children().size()):
				var child = new_quest_window.get_child(i)
				for inner in child.get_children():
					if inner.is_in_group("ItemTitle"):
						inner.text = "Quest: "+str(quest_dict["title"])
					if inner.is_in_group("ItemDescription"):
						inner.text = str(quest_dict["description"])
					if inner.is_in_group("ItemLabel"):
						inner.text = item_name + " X " + item_quantity


func set_items_acquired(collected : bool):
	items_acquired = collected
	# Change label color when player has collected all quest items
	if items_acquired_quest != -1:
		if menu_windows.keys().has(items_acquired_quest):
			var menu_window_children : Array[Node] = menu_windows[items_acquired_quest].get_children()
			
			for i in range(menu_window_children.size()):
				var child = menu_windows[items_acquired_quest].get_child(i)
				for inner in child.get_children():
					if inner.is_in_group("ItemLabel"):
						inner.modulate = Color.GREEN
						break

# Change ALL label colorS when player talks to NPC w COMPLETED QUEST
func quest_completion():
	if quest_complete_id != -1:
		if menu_windows.keys().has(quest_complete_id):
			var menu_window_children : Array[Node] = menu_windows[quest_complete_id].get_children()
			for i in range(menu_window_children.size()):
				var child = menu_windows[quest_complete_id].get_child(i)
				if child is CheckBox: child.button_pressed = true
				for inner in child.get_children():
					if inner.is_in_group("ItemTitle"):
						inner.modulate = Color.GREEN
					if inner.is_in_group("ItemDescription"):
						inner.modulate = Color.GREEN
					if inner.is_in_group("ItemLabel"):
						inner.modulate = Color.GREEN

# Forgot what this is for
func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: pass
			MOUSE_BUTTON_RIGHT: 
				if window.mouse_entered: toggle_quest_menu(!window.visible)

# Change label colors to default (when opening/closing popup windows)
func reset_window_prop():
	if menu_active_quest != -1:
		var w = menu_windows[menu_active_quest]
		w.modulate = Color.WHITE
		for i in range(w.get_children().size()):
			var child = w.get_child(i)
			if child is CheckBox: child.button_pressed = false
			for inner in child.get_children():
				if inner.is_in_group("ItemTitle"):
					inner.modulate = Color.WHITE
				if inner.is_in_group("ItemDescription"):
					inner.modulate = Color.WHITE
				if inner.is_in_group("ItemLabel"):
					inner.modulate = Color.WHITE

@rpc("any_peer","call_local")
func reset():
	menu_active_quest = -1
	items_acquired = false
	items_acquired_quest = -1
	quest_complete_id = -1
	clear_quest_windows()
	menu_windows.clear()
	menu_windows_pos_y = 0.0 # Reposition each added quest window (y position only)
	menu_windows_tmp = []
	menu_active = false

func clear_quest_windows():
	for node in menu_windows.values():
		node.queue_free()

func animated_pop_up(open : bool):
	reset_window_prop()
	if menu_active_quest != -1:
		var w = menu_windows[menu_active_quest]
		match open:
			true:
				w.scale = Vector2.ONE/8
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_LINEAR)
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(w, "scale", Vector2.ONE, 0.1)
				await tween.finished
			false:
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_LINEAR)
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(w, "scale", Vector2.ONE/8, 0.1)
				await tween.finished
