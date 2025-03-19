class_name InventorySlot extends Button

var item : BaseItem
var quantity : int
@onready var item_icon : TextureRect = $TextureRect
@onready var quantity_text : Label = $Quantity
@onready var slot_options = $Options
@onready var inventory : Inventory = get_node("/root/PlayerInventory")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.pressed.connect(_on_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_item(new_item : BaseItem):
	item = new_item
	quantity = new_item.value if item else 1
	if item == null: item_icon.visible = false
	else:
		set_item_animation(item)
		set_item_options(item)
	update_quantity_text()

func set_item_animation(new_item : BaseItem):
	item_icon.visible = true
	item_icon.texture = new_item.icon
	item_icon.scale = Vector2.ONE/8
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item_icon, "scale", Vector2.ONE, 0.25)

func remove_item_animation():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item_icon, "scale", Vector2.ONE/8, 0.1)
	await tween.finished

func set_item_options(new_item : BaseItem):
	if new_item.usable: pass
	else: slot_options.get_child(0).disabled = true
	if new_item.removeable: pass
	else: slot_options.get_child(1).disabled = true

func add_item():
	quantity += 1
	update_quantity_text()

func remove_item():
	quantity -= 1
	update_quantity_text()
	if quantity == 0: 
		await remove_item_animation()
		set_item(null)
	if slot_options.visible: toggle_slot_options(false)

func update_quantity_text():
	if quantity <= 1: quantity_text.text = ""
	else: quantity_text.text = str(quantity)
	

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: pass
				# left button clicked
			MOUSE_BUTTON_RIGHT: 
				if mouse_entered and item != null: toggle_slot_options(!slot_options.visible)

func toggle_slot_options(open: bool):
	slot_options.visible = open

func _on_pressed():
	if item == null: return
	if item.usable:
		var remove_after_use = item.use(inventory.player_ref)
		if remove_after_use: remove_item()
