class_name InventorySlot extends Button

var item : BaseItem
var quantity : int
@onready var item_icon : TextureRect = $TextureRect
@onready var quantity_text : Label = $Quantity
var inventory : Inventory

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.pressed.connect(_on_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_item(new_item : BaseItem):
	item = new_item
	quantity = 1
	if item == null: icon.visible = false
	else:
		icon.visible = true
		icon.texture = item.icon
	update_quantity_text()

func add_item():
	quantity += 1
	update_quantity_text()

func remove_item():
	quantity -= 1
	update_quantity_text()
	if quantity == 0: set_item(null)

func update_quantity_text():
	if quantity <= 1: quantity_text.text = ""
	else: quantity_text.text = str(quantity)

func _on_pressed():
	print(item)
	if item == null: return
	var remove_after_use = item._on_use(inventory.get_parent())
	if remove_after_use: remove_item()
