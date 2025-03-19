extends Resource
class_name Quest

@export var id: int
@export var title: String
@export var description: String
@export var is_completed: bool = false
@export var objectives: Array[String]
@export var desired_item: BaseItem
@export var desired_item_quantity: int
@export var rewards: Dictionary

var player: PlayerCharacter
