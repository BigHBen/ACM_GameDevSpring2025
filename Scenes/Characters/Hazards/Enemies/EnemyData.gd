class_name EnemyData extends Resource

enum ENEMY_TYPE {SKELETON_WARRIOR, SKELETON_MINION}
var item_type_map = [
	0,  # SKELETON_WARRIOR
	1,  # SKELETON_MINION
]
const ITEM_TYPE_NAMES := ["SKELETON_WARRIOR", "SKELETON_MINION"]

const MAX_HEALTH : int= 100
const MAX_SPEED : float = 7.5

@export var type : ENEMY_TYPE
@export var display_name : String
@export var description : String
@export_range(0,MAX_HEALTH) var hp : int
@export_range(0,MAX_SPEED) var speed : float
@export var icon : Texture2D

func get_item_type_name() -> String:
	return ITEM_TYPE_NAMES[type]
