class_name BaseItem extends Resource

enum ITEM_TYPE {COIN, POTION}

@export var value : int
@export var mesh : Mesh
@export var type : ITEM_TYPE

func add_value(player: Player):
	match type:
		ITEM_TYPE.COIN:
			player.moneyAmount += value
			player.update_ui()
		ITEM_TYPE.POTION:
			player.potionAmount += value
			player.update_ui()
