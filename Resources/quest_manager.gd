extends Node

var active_quests: Dictionary = {} : set = set_active_quests # Stores accepted quests by ID
var completed_quests: Dictionary = {}
var id_count = 0

var rewards_json : String = "res://Resources/npc_rewards.json"

func accept_quest(quest: Quest):
	if quest.id not in active_quests: active_quests[quest.id] = quest
	print("\nYou Accepted Quest -> ",get_quest_as_dict(quest), "\n")

func quest_finish(quest_id: int):
	if quest_id in active_quests:
		var quest = active_quests[quest_id]
		quest.is_completed = true
		completed_quests[quest_id] = quest
		active_quests.erase(quest_id)
		print("Completed quest: ", quest.title)
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
