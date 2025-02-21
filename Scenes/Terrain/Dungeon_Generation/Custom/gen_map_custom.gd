extends GridMap

# User-specified meshes for each color type

@export_category("GridMap Parameters")
@export var border_size : int = 20 : set = set_border_size
@export var final_gridmap : GridMap
@export_category("Mesh Parameters")
@export var mesh_lib : MeshLibrary
@export var floor_mesh_idx : int
@export var wall_mesh_idx : int
@export var hallway_mesh_idx : int


var center_x = 0  # Assuming 0 is the center in the x direction
var center_z = 0  # Assuming 0 is the center in the z direction
var mesh_map : Dictionary = {}
var outline_shader_path = "res://Shaders/outline.gdshader"

func _ready() -> void:
	update_mesh_map()
	print(mesh_map)
	await scan_floor_tiles()

func update_mesh_map():
	mesh_map["floor"] = \
	[mesh_lib.get_item_mesh(floor_mesh_idx) if floor_mesh_idx >= 0 and floor_mesh_idx < mesh_lib.get_item_list().size() else null,
	 mesh_lib.get_item_name(floor_mesh_idx)]
	mesh_map["wall"] = \
	[mesh_lib.get_item_mesh(wall_mesh_idx) if wall_mesh_idx >= 0 and wall_mesh_idx < mesh_lib.get_item_list().size() else null,
	 mesh_lib.get_item_name(wall_mesh_idx)]
	mesh_map["hallway"] = \
	[mesh_lib.get_item_mesh(hallway_mesh_idx) if hallway_mesh_idx >= 0 and hallway_mesh_idx < mesh_lib.get_item_list().size() else null,
	 mesh_lib.get_item_name(hallway_mesh_idx)]

func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

func visualize_border():
	if self: 
		self.clear()
		for i in range(-border_size, border_size + 1):
			self.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), 1)  # Top border
			self.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), 1)  # Bottom border
			self.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), 1)  # Left border
			self.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), 1)  # Right border

func scan_floor_tiles():
	for x in range(-border_size + 1, border_size):
		for z in range(-border_size + 1, border_size):
			var tile_index = get_cell_item(Vector3(x, 0, z))
			if tile_index != -1:
				var tile_name = mesh_library.get_item_name(tile_index)
				var _mesh = mesh_library.get_item_mesh(tile_index)
				set_cell_item(Vector3(x, 0, z),1)
				print(Vector3(x, 0, z), " - item: ", tile_index, " | type: ", tile_name)
				await get_tree().create_timer(0.1).timeout
