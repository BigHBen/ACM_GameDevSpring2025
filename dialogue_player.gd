extends CanvasLayer
class_name NPCDialogue

@export var d_file : JSON

var d_active : bool : set=set_chat_active

var talk_status : String # Determines dialogue thread
var dialogue = []
var dialogue_id : int = 0

var player_response_toggle : bool = false : set = set_response_focus
var player_response : bool = false 
var quest_lock : bool = false # Don't restart dialogue if player has accepted quest
var end_early : bool = false

func _ready() -> void:
	if d_file:
		d_active = false # Turn off chat
		dialogue = load_dialogue()
		
		$PlayerResponse/HBoxContainer/Accept.pressed.connect(_on_player_accept)
		$PlayerResponse/HBoxContainer/Reject.pressed.connect(_on_player_reject)

func load_dialogue():
	var file = d_file.resource_path
	var json_as_text = FileAccess.get_file_as_string(file)
	return JSON.parse_string(json_as_text)

func load_player_responses(line):
	var accept_text = line["accept"]
	var reject_text = line["reject"]
	$PlayerResponse/HBoxContainer/Accept.text = accept_text
	$PlayerResponse/HBoxContainer/Reject.text = reject_text

func load_npc_responses(line):
	var accepted_text = line["accepted"]
	var rejected_text = line["rejected"]
	if player_response: $NinePatchRect/Chatbox.text = accepted_text
	else: $NinePatchRect/Chatbox.text = rejected_text

func start():
	dialogue_id = 0
	talk_status = "quest_dialogue"
	end_early = false
	if get_parent().npc_quest:
		if get_parent().npc_quest.is_completed:
			if quest_lock: 
				talk_status = "return_dialogue"
				dialogue_id = get_return_dialogue_index("completed") 
			else: talk_status = "chat" 
		else:
			if quest_lock: 
				talk_status = "return_dialogue"
				dialogue_id = get_return_dialogue_index("in_progress")
			else: pass # will go to quest_dialogue
	$NinePatchRect/Name.text = dialogue[talk_status][dialogue_id]["name"]
	$NinePatchRect/Chatbox.text = dialogue[talk_status][dialogue_id]["text"]
	d_active = true

func progress():
	if dialogue_id < dialogue[talk_status].size()-1 and not end_early: dialogue_id += 1
	#if dialogue_id >= dialogue.size()-1: $ChatEndDelay.start()
	elif !$ChatEndDelay.is_stopped(): $ChatEndDelay.timeout.emit()
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
	elif dialogue[talk_status][dialogue_id].has("accept"): # Ask player a yes/no question
		load_player_responses(dialogue[talk_status][dialogue_id])
		$PlayerResponse.visible = true
	elif dialogue[talk_status][dialogue_id].has("accepted"): # Response after player decides
		load_npc_responses(dialogue[talk_status][dialogue_id])
		$PlayerResponse.visible = false
		return
	else: $PlayerResponse.visible = false
	$NinePatchRect/Name.text = dialogue[talk_status][dialogue_id]["name"]
	$NinePatchRect/Chatbox.text = dialogue[talk_status][dialogue_id]["text"]
		

func _input(event: InputEvent) -> void:
	if not d_active: return
	if event.is_action_pressed("ui_accept"):
		if dialogue[talk_status][dialogue_id].has("accept"): return
		progress()
	if event.is_action_pressed("left") || event.is_action_pressed("right"):
		if dialogue[talk_status][dialogue_id].has("accept"):
			player_response_toggle = !player_response_toggle

func get_return_dialogue_index(quest_status: String) -> int:
	var return_dialogue = dialogue["return_dialogue"]
	for i in range(return_dialogue.size()):
		if return_dialogue[i].get("quest_progress") == quest_status:
			return i 
	return -1

func set_chat_active(val):
	d_active = val
	if d_active: $NinePatchRect.visible = true
	else: $NinePatchRect.visible = false

func set_response_focus(val):
	player_response_toggle = val
	if $PlayerResponse.visible:
		if player_response_toggle: $PlayerResponse/HBoxContainer/Accept.grab_focus()
		else: $PlayerResponse/HBoxContainer/Reject.grab_focus()

func _on_player_accept():
	player_response = true
	var cur_line = dialogue[talk_status][dialogue_id]
	if cur_line.has("quest"):
		if cur_line.quest: 
			get_parent().quest_accepted.emit()
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

func _on_chat_timer_timeout() -> void:
	d_active = false
	if get_parent().is_in_group("NPC"):
		get_parent().chat_end.emit()
	
