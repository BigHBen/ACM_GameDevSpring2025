class_name BaseItem extends Resource

enum ITEM_TYPE {COIN, POTION, KEY, QUEST_ITEM}

@export var value : int
@export var mesh : Mesh
@export var type : ITEM_TYPE

func add_value(player: PlayerCharacter):
	match type:
		ITEM_TYPE.COIN:
			player.moneyAmount += value
			player.update_ui()
		ITEM_TYPE.POTION:
			player.potionAmount += value
			player.update_ui()
		ITEM_TYPE.QUEST_ITEM:
			print("collected quest item")
