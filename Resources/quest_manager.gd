extends Node

@onready var pop_menu : QuestPopMenu = get_node("/root/QuestPopupMenu")

var active_quests: Dictionary = {} : set = set_active_quests # Stores accepted quests by ID
var completed_quests: Dictionary = {}
var id_count = 0

var rewards_json : String = "res://Resources/npc_rewards.json"

func accept_quest(quest: Quest,peer_id: int = -1) -> bool:
	if quest.id not in active_quests: active_quests[quest.id] = quest
	else: return false
	if peer_id != -1:
		print(self.name,": ", "[",peer_id,"]"," Accepted Quest -> ",get_quest_as_dict(quest)['title'])
	else:
		print(self.name,": ", "[",quest.player,"]"," Accepted Quest -> ",get_quest_as_dict(quest)['title'])
	return true

#@rpc("any_peer")
#func accept_quest_multiplayer(quest: Quest,peer_id: int = -1) -> bool:
	#if quest.id not in active_quests: active_quests[quest.id] = quest
	#else: return false
	#if peer_id != -1:
		#print(self.name,": ", "[",peer_id,"]"," Accepted Quest -> ",get_quest_as_dict(quest)['title'])
	#else:
		#print(self.name,": ", "[",quest.player,"]"," Accepted Quest -> ",get_quest_as_dict(quest)['title'])
	#return true

func quest_finish(quest_id: int, player):
	if quest_id in active_quests and player:
		var quest = active_quests[quest_id]
		quest.is_completed = true
		completed_quests[quest_id] = quest
		active_quests.erase(quest_id)
		#if pop_menu.window.visible: 
		if pop_menu.menu_windows.has(quest_id):
			if pop_menu.menu_windows[quest_id].visible:
				pop_menu.quest_complete_id = quest_id
				pop_menu.quest_completion()
		print(self.name,": Player[%s]" % [player.name.capitalize()], " Completed Quest: ", quest.title.to_upper())
		#give_rewards(quest.player,quest.rewards)

func give_rewards(to: PlayerCharacter, rewards: Dictionary):
	for reward in rewards.values():
		if reward is BaseItem: reward.add_value(to)

func get_next_quest_id():
	var id := randi_range(10, 99)
	var existing_ids := []
	for key in active_quests.keys():
		existing_ids.append(active_quests[key].id)
	while id in existing_ids:
		id = randi_range(10, 99)
	return id

func set_active_quests(quests : Dictionary):
	active_quests = quests

func get_quest(quest_id: int):
	if quest_id in active_quests:
		return active_quests[quest_id]
	return null

func get_rewards() -> Dictionary:
	var file = rewards_json
	var json_as_text = FileAccess.get_file_as_string(file)
	return JSON.parse_string(json_as_text)

func load_reward(reward_name : String) -> Dictionary:
	var file = rewards_json
	var json_text = FileAccess.get_file_as_string(file)
	var json_array = JSON.parse_string(json_text)
	for i in range(json_array.size()-1):
		if json_array[i].name.contains(reward_name):
			return json_array[i]
	return {}

func get_quest_as_dict(quest : Quest) -> Dictionary:
	var quest_dict = {}
	var script = quest.get_script()
	for prop in script.get_script_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var prop_name = prop.name
			var prop_value = quest.get(prop_name)
			quest_dict[prop_name] = prop_value
	return quest_dict

func has_quest(quest_id: int) -> bool:
	return active_quests.has(quest_id)

func quest_check(item : BaseItem):
	for quest in active_quests.values():
		if quest.desired_item == item:
			quest_progress_update(quest)
			if quest.progress >= quest.desired_item_quantity:
				pop_menu.items_acquired_quest = quest.id
				pop_menu.items_acquired = true

	#var detected_q_items : int = inventory.get_number_of_item(npc_quest.desired_item)
	#if detected_q_items == npc_quest.desired_item_quantity:
		#player_inventory.remove_item(npc_quest.desired_item)

func quest_progress_update(quest : Quest) -> void:
	quest.progress += 1

@rpc("any_peer","call_local")
func reset():
	active_quests.clear()
	completed_quests.clear()
	id_count = 0
