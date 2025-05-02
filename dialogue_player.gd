extends CanvasLayer
class_name NPCDialogue

@export var d_file : JSON

# Child Nodes
@onready var chatbox : NinePatchRect = $DialogueContainer/NinePatchRect
@onready var response_buttons : Control = $DialogueContainer/PlayerResponse

# Test UI - For Multiplayer Sync
@onready var title_label : Label = $Test/PanelContainer/MarginContainer/VBoxContainer/title
@onready var current_label : Label = $Test/PanelContainer/MarginContainer/VBoxContainer/current
@onready var talk_status_label : Label = $Test/PanelContainer/MarginContainer/VBoxContainer/talk_status
@onready var id_label : Label = $Test/PanelContainer/MarginContainer/VBoxContainer/id
@onready var lock_label : Label = $Test/PanelContainer/MarginContainer/VBoxContainer/lock

# Debug 
@onready var dialogue_debug_ui : Control = $Test

var d_active : bool : set=set_chat_active

var talk_status : String : set=set_talk_status# Determines dialogue thread
var dialogue = []
var dialogue_id : int = 0 : set=set_dialogue_id

var player_response_toggle : bool = false : set = set_response_focus
var player_response : bool = false 
var quest_lock : bool = false : set=set_quest_lock # Don't restart dialogue if player has accepted quest
var end_early : bool = false

var quest_types : Dictionary =  {"shared"=0,"individual"=1}

func _ready() -> void:
	if d_file:
		d_active = false # Turn off chat
		if !is_multiplayer_authority(): $Test.hide()
		dialogue = load_dialogue()
		$DialogueContainer/PlayerResponse/HBoxContainer/Accept.pressed.connect(_on_player_accept)
		$DialogueContainer/PlayerResponse/HBoxContainer/Reject.pressed.connect(_on_player_reject)

# Setter functions
func set_dialogue_id(val):
	dialogue_id = val
	#if is_multiplayer_authority(): 
	set_dialogue_label(str(dialogue_id))
	#set_dialogue_label.rpc(str(dialogue_id))

#@rpc("any_peer","call_local") # Dialogue not synced anymore
func set_dialogue_label(val:String):
	id_label.text = "DIALOGUE_ID: "+str(val)

func set_talk_status(val):
	talk_status = val
	set_talk_label(talk_status)

#@rpc("call_local") # Dialogue not synced anymore
func set_talk_label(val:String):
	current_label.text = "TALKING TO: "+str(get_parent())
	talk_status_label.text = "TALK_STATUS: "+val

func set_quest_lock(val:bool):
	quest_lock = val
	set_lock_label(str(quest_lock).capitalize())

#@rpc("call_local") # Dialogue not synced anymore
func set_lock_label(val:String):
	lock_label.text = "QUEST LOCK: "+ val

func load_dialogue():
	var file = d_file.resource_path
	var json_as_text = FileAccess.get_file_as_string(file)
	return JSON.parse_string(json_as_text)

func load_player_responses(line):
	var accept_text = line["accept"]
	var reject_text = line["reject"]
	$DialogueContainer/PlayerResponse/HBoxContainer/Accept.text = accept_text
	$DialogueContainer/PlayerResponse/HBoxContainer/Reject.text = reject_text

func load_npc_responses(line):
	var accepted_text = line["accepted"]
	var rejected_text = line["rejected"]
	if player_response: $DialogueContainer/NinePatchRect/Chatbox.text = accepted_text
	else: $DialogueContainer/NinePatchRect/Chatbox.text = rejected_text

func move_dbox_tween(s,dbox_start, target_position,sec):
	if start: s.position = dbox_start
	var tween = create_tween()
	
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(s, "position", target_position, sec)
	await tween.finished

func start():
	dialogue_id = 0
	talk_status = "quest_dialogue"
	end_early = false
	if get_parent().npc_quest:
		if get_parent().npc_quest.is_completed:
			if quest_lock: 
				talk_status = "return_dialogue"
				dialogue_id = get_return_dialogue_index("completed") 
				check_next_return_dialogue()
			else: talk_status = "chat" 
		elif quest_lock:
			talk_status = "return_dialogue"
			dialogue_id = get_return_dialogue_index("in_progress")
			check_next_return_dialogue()
	$DialogueContainer/NinePatchRect/Name.text = dialogue[talk_status][dialogue_id]["name"]
	$DialogueContainer/NinePatchRect/Chatbox.text = dialogue[talk_status][dialogue_id]["text"]
	await get_tree().create_timer(0.01).timeout
	d_active = true

# Return dialogue section contains two dialogue types: in_progress, is_completed
# Prevent progression to is_completed dialogue lines (before quest is finished)
func check_next_return_dialogue():
	var cur_dialogue = dialogue[talk_status][dialogue_id]
	if talk_status == "return_dialogue" and quest_lock:
		if talk_status in dialogue and dialogue_id + 1 < len(dialogue[talk_status]):
			var next_dialogue = dialogue[talk_status][dialogue_id + 1]
			if cur_dialogue["quest_progress"] == "in_progress" and \
			next_dialogue["quest_progress"] == "completed": 
				end_early = true
				return false
	return true

func progress():
	if dialogue_id < dialogue[talk_status].size()-1 and not end_early: dialogue_id += 1
	else: $ChatEndDelay.start()
	var cur_dialogue = dialogue[talk_status][dialogue_id]
	if talk_status == "return_dialogue" and quest_lock:
		if talk_status in dialogue and dialogue_id + 1 < len(dialogue[talk_status]):
			var next_dialogue = dialogue[talk_status][dialogue_id + 1]
			if cur_dialogue["quest_progress"] == "in_progress" and \
			next_dialogue["quest_progress"] == "completed": 
				end_early = true
		elif cur_dialogue["quest_progress"] == "completed" and \
		dialogue_id == dialogue[talk_status].size()-1: 
			quest_lock = false
	elif dialogue[talk_status][dialogue_id].has("auto_accept") and !end_early: # Ask player a yes/no question
		quest_auto_accept()
		end_early = true
		return
	elif dialogue[talk_status][dialogue_id].has("accept"): # Ask player a yes/no question
		load_player_responses(dialogue[talk_status][dialogue_id])
		$DialogueContainer/PlayerResponse.visible = true
	elif dialogue[talk_status][dialogue_id].has("accepted"): # Response after player decides
		load_npc_responses(dialogue[talk_status][dialogue_id])
		$DialogueContainer/PlayerResponse.visible = false
		return
	else: $DialogueContainer/PlayerResponse.visible = false
	$DialogueContainer/NinePatchRect/Name.text = dialogue[talk_status][dialogue_id]["name"]
	$DialogueContainer/NinePatchRect/Chatbox.text = dialogue[talk_status][dialogue_id]["text"]

@rpc("any_peer")
func update_client_dialogue(status,id):
	dialogue_id = id
	talk_status = status

func _input(event: InputEvent) -> void:
	if not d_active or not get_parent().target: return
	if event.is_action_pressed("ui_accept"):
		if dialogue[talk_status][dialogue_id].has("accept"): return
		if !$ChatEndDelay.is_stopped(): 
			$ChatEndDelay.timeout.emit()
		else: 
			#if get_parent().name.contains("NPC"): print(get_parent(),": Is Progressing!") # NPC Debug
			progress()
	if event.is_action_pressed("left") || event.is_action_pressed("ui_left"):
		if dialogue[talk_status][dialogue_id].has("accept"):
			player_response_toggle = true
	if event.is_action_pressed("right") || event.is_action_pressed("ui_right"):
		if dialogue[talk_status][dialogue_id].has("accept"):
			player_response_toggle = false

func get_return_dialogue_index(quest_status: String) -> int:
	var return_dialogue = dialogue["return_dialogue"]
	for i in range(return_dialogue.size()):
		if return_dialogue[i].get("quest_progress") == quest_status:
			return i 
	return -1

func set_chat_active(val):
	d_active = val
	if d_active: 
		var tween_start = Vector2(0,DisplayServer.screen_get_size().y + $DialogueContainer/NinePatchRect.size.y)
		$DialogueContainer.position = tween_start
		move_dbox_tween($DialogueContainer,tween_start,Vector2.ZERO,0.25)
		chatbox.visible = true
		response_buttons.visible = false
	else: 
		var tween_end = Vector2(0,DisplayServer.screen_get_size().y + $DialogueContainer/NinePatchRect.size.y)
		await move_dbox_tween($DialogueContainer,Vector2.ZERO,tween_end,0.25)
		chatbox.visible = false
		response_buttons.visible = false
		#for child in self.get_children():
			#if child is NinePatchRect or child is Control:
				#if child.name.contains("Test"): continue
				#child.visible = false

func set_response_focus(val):
	player_response_toggle = val
	if $DialogueContainer/PlayerResponse.visible:
		if player_response_toggle: 
			$DialogueContainer/PlayerResponse/HBoxContainer/Reject.release_focus()
			$DialogueContainer/PlayerResponse/HBoxContainer/Accept.grab_focus()
		else: 
			$DialogueContainer/PlayerResponse/HBoxContainer/Accept.release_focus()
			$DialogueContainer/PlayerResponse/HBoxContainer/Reject.grab_focus()

# Ex: Locked Door -> Initiates key quest immediately
func quest_auto_accept():
	var cur_line = dialogue[talk_status][dialogue_id]
	#update_client_dialogue.rpc(talk_status,dialogue_id)
	if cur_line.has("quest"):
		if cur_line.quest: 
			if get_tree().current_scene is GameManagerMultiplayer and cur_line.has("quest_type"):
				var type = cur_line["quest_type"]
				if type == quest_types["shared"]: get_parent().quest_accepted.emit()
				#elif type == quest_types["individual"]: get_parent().quest_accepted_remote.emit()
			else: get_parent().quest_accepted.emit()
			quest_lock = true
	$DialogueContainer/NinePatchRect/Name.text = dialogue[talk_status][dialogue_id]["name"]
	$DialogueContainer/NinePatchRect/Chatbox.text = dialogue[talk_status][dialogue_id]["text"]

# When NPC asks player to accept or reject
func _on_player_accept():
	player_response = true
	var cur_line = dialogue[talk_status][dialogue_id]
	if cur_line.has("quest"):
		if cur_line.quest: 
			if get_tree().current_scene is GameManagerMultiplayer and cur_line.has("quest_type"):
				var type = cur_line["quest_type"]
				if type == quest_types["shared"]: get_parent().quest_accepted.emit()
				#elif type == quest_types["individual"]: get_parent().quest_accepted_remote.emit()
			else: get_parent().quest_accepted.emit()
			quest_lock = true
	progress()

func _on_player_reject():
	player_response = false
	var cur_line = dialogue[talk_status][dialogue_id]
	if cur_line.has("quest"):
		if cur_line.quest: 
			get_parent().quest_rejected.emit()
			quest_lock = false
	progress()

func cancel_dialogue():
	d_active = false
	print(get_parent(), ": Dialogue canceled!")

func _on_chat_timer_timeout() -> void:
	$ChatEndDelay.stop()
	d_active = false
	if get_parent().is_in_group("NPC"):
		get_parent().chat_end.emit()
	
