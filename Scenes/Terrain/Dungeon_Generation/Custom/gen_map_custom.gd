@tool
extends GridMap
class_name GridMapMeshCustomizer

# User-specified meshes for each color type

@export var start : bool = false : set = set_start
@export var clear_fill : bool = false : set = set_clear
@export_category("GridMap Parameters")
@export var border_size : int = 20 : set = set_border_size
@export var source_gridmap : GridMap
@export var final_gridmap : GridMap
@export var grid_rotation : int = 0  # 0, 90, -90, 180 degrees rotation
@export_category("Mesh Parameters")
@export var mesh_lib : MeshLibrary
@export var floor_mesh_idx : int
@export var wall_mesh_idx : int
@export var corner_mesh_idx : int
@export var hallway_mesh_idx : int


# 6 tile types - used for mesh placement
enum TileType {
	ROOM,
	HALLWAY,
	DOOR,
	BORDER,
	HIGHLIGHT,
	WALL,
}

# Should find a better way to assign indexes
var tile_index_map = [
	0,  # ROOM
	2,  # HALLWAY
	3,  # DOOR
	5,  # BORDER
	1,  # HIGHLIGHT
	4,  # WALL
]

var center_x = 0 
var center_z = 0 
var mesh_map : Dictionary = {}
var orientation_map = {
	0: "Horizontal wall",
	1: "Vertical wall",
	2: "Corner wall (top left)",
	3: "Corner wall (top right)",
	4: "Isolated wall (edge case)",
	5: "Corner wall (bottom left)",
	6: "Corner wall (bottom right)",
	-1: "Unknown orientation"
}
var outline_shader_path = "res://Shaders/outline.gdshader"
var tile_count : int = 0

func _enter_tree() -> void:
	pass

func set_start(val:bool)->void:
	start = val
	if !start: 
		if source_gridmap and final_gridmap:
			final_gridmap.clear()
			source_gridmap.visible = true
			print(source_gridmap.name," Cleared")
	if Engine.is_editor_hint() and start:
		if mesh_lib and source_gridmap and final_gridmap:
			update_mesh_map()
			source_gridmap.visible = false
			await scan_floor_tiles()
			print(tile_count," Meshes loaded successfully (%s)" % [final_gridmap.name])
		else:
			printerr("GridMapMeshCustomizer: Missing mesh library, source, or final gridmap")

#func _ready() -> void:
	#if mesh_lib and final_gridmap:
		#update_mesh_map()
		#self.visible = false
		#await scan_floor_tiles()
	#else:
		#printerr("Missing mesh library or final gridmap")

func set_clear(val:bool)->void:
	clear_fill = val
	if Engine.is_editor_hint() and clear_fill:
		if mesh_lib and source_gridmap and final_gridmap:
			final_gridmap.clear()
			source_gridmap.visible = true
			clear_fill = false
		else: printerr("GridMapMeshCustomizer: Missing mesh library, source, or final gridmap")

# Gridmap (Self) contains simplified boxmeshes to represent dungeon areas (floor, etc)
# User selects meshes (types: floor, wall, hallway) from tiles.tres
# Simplified tiles from gridmap (self) will be scanned
# New user specified meshes will be generated on separate gridmap
func update_mesh_map():
	if mesh_lib:
		mesh_map["0"] = \
		[mesh_lib.get_item_mesh(floor_mesh_idx) if floor_mesh_idx >= 0 and floor_mesh_idx < mesh_lib.get_item_list().size() else null,
		 mesh_lib.get_item_name(floor_mesh_idx)]
		
		mesh_map["1"] = [mesh_library.get_item_mesh(1),mesh_library.get_item_name(1)]
		
		mesh_map["3"] = \
		[mesh_lib.get_item_mesh(wall_mesh_idx) if wall_mesh_idx >= 0 and wall_mesh_idx < mesh_lib.get_item_list().size() else null,
		 mesh_lib.get_item_name(wall_mesh_idx)]
		
		mesh_map["2"] = \
		[mesh_lib.get_item_mesh(hallway_mesh_idx) if hallway_mesh_idx >= 0 and hallway_mesh_idx < mesh_lib.get_item_list().size() else null,
		 mesh_lib.get_item_name(hallway_mesh_idx)]
		
		mesh_map["2"] = \
		[mesh_lib.get_item_mesh(hallway_mesh_idx) if hallway_mesh_idx >= 0 and hallway_mesh_idx < mesh_lib.get_item_list().size() else null,
		 mesh_lib.get_item_name(hallway_mesh_idx)]
		
		mesh_map["4"] = [mesh_library.get_item_mesh(1),mesh_library.get_item_name(1)]
		
		mesh_map["5"] = [mesh_library.get_item_mesh(1),mesh_library.get_item_name(1)]

func get_tile_index(tile_type: TileType) -> int:
	return tile_index_map[tile_type]

func set_border_size(val : int) -> void:
	border_size = val
	if source_gridmap:
		pass
	if Engine.is_editor_hint():
		visualize_border()

func visualize_border():
	if source_gridmap: 
		source_gridmap.clear()
		for i in range(-1, border_size+1):
			source_gridmap.set_cell_item(Vector3i(i,0,-1),get_tile_index(TileType.BORDER))
			source_gridmap.set_cell_item(Vector3i(i,0,border_size),get_tile_index(TileType.BORDER))
			source_gridmap.set_cell_item(Vector3i(border_size,0,i),get_tile_index(TileType.BORDER))
			source_gridmap.set_cell_item(Vector3i(-1,0,i),get_tile_index(TileType.BORDER))

func visualize_border_centered():
	if source_gridmap: 
		source_gridmap.clear()
		for i in range(-border_size, border_size + 1):
			source_gridmap.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), get_tile_index(TileType.BORDER))  # Top border
			source_gridmap.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), get_tile_index(TileType.BORDER))  # Bottom border
			source_gridmap.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), get_tile_index(TileType.BORDER))  # Left border
			source_gridmap.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), get_tile_index(TileType.BORDER))  # Right border

func scan_floor_tiles():
	#for x in range(-border_size + 1, border_size): # If centered
		#for z in range(-border_size + 1, border_size):
	var tile_index
	tile_count = 0
	for x in range(0, border_size): # If not centered
		for z in range(0, border_size):
			tile_index = source_gridmap.get_cell_item(Vector3(x, 0, z)) 
			if tile_index != -1:
				var pos = Vector3(x, 0, z)
				#var tile_name = mesh_library.get_item_name(tile_index)
				#var new_mesh = mesh_map[str(tile_index)]
				#set_cell_item(pos,get_tile_index(TileType.HIGHLIGHT)) # Testing
				#print("Tile Position: ", Vector3(x, 0, z), # Testing
				#" | Item ID: ", tile_index, 
				#" | Type: ", tile_name, 
				#" | New Mesh: ", new_mesh)
				if tile_index == get_tile_index(TileType.ROOM) || \
				   tile_index == get_tile_index(TileType.DOOR):
					var trans_rotation = Vector3(0, 90, 0)
					var some_basis = Basis.from_euler(trans_rotation)
					var orth_idx = get_orthogonal_index_from_basis(some_basis)
					final_gridmap.set_cell_item(pos, floor_mesh_idx,orth_idx)
				elif tile_index == get_tile_index(TileType.HALLWAY):
					var trans_rotation = Vector3(0, 0, 0)
					var some_basis = Basis.from_euler(trans_rotation)
					var orth_idx = get_orthogonal_index_from_basis(some_basis)
					final_gridmap.set_cell_item(pos, hallway_mesh_idx,orth_idx)
				elif tile_index == get_tile_index(TileType.WALL):
					var wall_orientation = get_wall_orientation(pos)
					#print("Orientation for ", 2*pos, ": ", orientation_map[wall_orientation])
					spawn_wall(pos, wall_orientation,final_gridmap)
				
				tile_count += 1
				#await get_tree().create_timer(0.001).timeout

# Get orientation wall based on neighboring tiles
func get_wall_orientation(cell_position: Vector3) -> int:
	
	var left = Vector3(cell_position.x - 1, 0, cell_position.z)
	var right = Vector3(cell_position.x + 1, 0, cell_position.z)
	var above = Vector3(cell_position.x, 0, cell_position.z - 1)
	var below = Vector3(cell_position.x, 0, cell_position.z + 1)
	var _neighbor_pos = [left,right,below,above]
	
	var neighbors = [
		source_gridmap.get_cell_item(left),  # Left
		source_gridmap.get_cell_item(right),  # Right
		source_gridmap.get_cell_item(below),  # Below
		source_gridmap.get_cell_item(above)   # Above
	]
	
	var has_left = neighbors[0] != -1 and neighbors[0] == get_tile_index(TileType.WALL)
	var has_right = neighbors[1] != -1 and neighbors[1] == get_tile_index(TileType.WALL)
	var has_below = neighbors[2] != -1 and neighbors[2] == get_tile_index(TileType.WALL)
	var has_above = neighbors[3] != -1 and neighbors[3] == get_tile_index(TileType.WALL)
	
	if cell_position.x == 4 and cell_position.z == 12: # Test case (top-left corner)
		#print("%s neighbors: %s" % [cell_position, neighbors])
		pass
	
	if has_right and has_below:
		return 2  # Top-left corner
	elif has_left and has_below:
		return 3  # Top-right corner
	elif has_right and has_above:
		return 4  # Bottom-left corner
	elif has_left and has_above:
		return 5  # Bottom-right corner
	elif has_left and has_right:
		# Horizontal wall should come after corners
		return 0  # Horizontal wall
	elif has_below and has_above:
		return 1  # Vertical wall
	elif !has_left and !has_right and !has_below and !has_above:
		return 6  # Single wall (no neighbors)
	else:
		return -1 

# Given wall orientation, rotate and spawn wall
func spawn_wall(cell_position: Vector3, orientation: int, new_gridmap: GridMap):
	
	var orth_idx : int
	var trans_rotation : Vector3
	match orientation:
		0: # Horizontal wall
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_mesh_idx,orth_idx)
		1: # Vertical wall
			trans_rotation = Vector3(0, PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_mesh_idx,orth_idx)
		2: # Corner wall (top left)
			trans_rotation = Vector3(0, PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			
			new_gridmap.set_cell_item(cell_position, corner_mesh_idx,orth_idx)
		3: # Corner wall (top right)
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_mesh_idx,orth_idx)
		4: # Corner wall (bottom left)
			trans_rotation = Vector3(0, PI, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_mesh_idx,orth_idx)
		5: # Corner wall (bottom right)
			trans_rotation = Vector3(0, -PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_mesh_idx,orth_idx)
		6: # Single isolated wall (edge case)
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_mesh_idx,orth_idx)
		_:  pass
