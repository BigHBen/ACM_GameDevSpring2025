@tool
extends GridMap
class_name GridMapMeshCustomizer

# User-specified meshes for each color type

@export var start : bool = false : set = set_start
@export var clear_fill : bool = false : set = set_clear
@export_category("GridMap Parameters")
@export var border_size : int = 20 : set = set_border_size
@export var source_gridmap : GridMap
@export var final_floor_gridmap : GridMap
@export var final_wall_gridmap : GridMap
@export var final_wall_2_gridmap : GridMap # For Extra wall tiles (ex: fences)
@export var final_under_gridmap :GridMap
@export var grid_rotation : int = 0  # 0, 90, -90, 180 degrees rotation

@export_category("Mesh Parameters")
@export var mesh_lib : MeshLibrary
@export var floor_mesh_idx : int
@export var wall_mesh_idx : int
@export var wall_2_mesh_idx : int
@export var corner_mesh_idx : int
@export var corner_2_mesh_idx : int
@export var hallway_mesh_idx : int


# 6 tile types - used for mesh placement
enum TileType {
	ROOM,
	HALLWAY,
	DOOR,
	BORDER,
	HIGHLIGHT,
	WALL,
	WALL2,
}

# Should find a better way to assign indexes
var tile_index_map = [
	0,  # ROOM
	2,  # HALLWAY
	3,  # DOOR
	5,  # BORDER
	1,  # HIGHLIGHT
	4,  # WALL
	4,  # WALL 2
]

@export_category("Level Gen Parameters")
enum MeshPresetChoice { DEFAULT, STONE_GRAVEYARD }
@export var MESH_PRESET : MeshPresetChoice = MeshPresetChoice.DEFAULT :
	set(val):
		MESH_PRESET = val
		if get_parent() is LevelGen:
			mesh_presets_refresh()
			#print(self,": Mesh Preset Selected: ",current_mesh_preset)
			clear_fill = true
			start = true
		else: printerr(self,": LevelGen required to change mesh presets")
var current_mesh_preset : Dictionary

# Default mesh preset - wood loor, dungeon walls
var mesh_preset_1 = { 
	"name": "Default",
	"mesh_items":
			[ 
		0, # Wood Floor
		7, # Dungeon Wall
		18, # Dungeon Wall Corner
		0, # Same wood floor
	],
	"shuffle_floor": false,
	"floor_under": [false],
}

var mesh_preset_2 = {
	"name": "Stone Graveyard",
	"mesh_items":
		[
		6, # Stone Floor
		6, # Stone floor (for wall tiles)
		6, # Stone Floor (for corner tiles)
		6, # Same stone floor
		14, # Iron Fences (spawn on top of wall tiles)
		17, # Stone Pillars
	],
	"shuffle_floor": true,
	"floor_under": [true, 1, 4],
	"walls": true
}

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
var floor_tile_count : int = 0
var wall_tile_count : int = 0

func _enter_tree() -> void:
	if get_parent() is LevelGen:
		mesh_presets_refresh()

func set_start(val:bool)->void:
	start = val
	if !start: 
		if source_gridmap and final_floor_gridmap:
			final_floor_gridmap.clear()
			source_gridmap.visible = true
			print(self,": ",source_gridmap.name," Cleared")
		if source_gridmap and final_wall_gridmap and final_under_gridmap:
			final_wall_gridmap.clear()
			final_under_gridmap.clear()
		
	if Engine.is_editor_hint() and start:
		if mesh_lib and source_gridmap and final_floor_gridmap:
			update_mesh_map()
			source_gridmap.visible = false
			await scan_floor_tiles()
			print(final_floor_gridmap,": ", floor_tile_count," Meshes loaded successfully")
			print(final_wall_gridmap,": ", wall_tile_count," Meshes loaded successfully")
		else:
			printerr("GridMapMeshCustomizer: Missing mesh library, source, or final gridmaps")
	start = false

#func _ready() -> void:
	#if mesh_lib and final_floor_gridmap:
		#update_mesh_map()
		#self.visible = false
		#await scan_floor_tiles()
	#else:
		#printerr("Missing mesh library or final gridmap")

func set_clear(val:bool)->void:
	clear_fill = val
	if Engine.is_editor_hint() and clear_fill:
		self.clear()
		if mesh_lib and source_gridmap and final_floor_gridmap:
			final_floor_gridmap.clear()
			if final_wall_gridmap: final_wall_gridmap.clear()
			if final_under_gridmap: final_under_gridmap.clear()
			if final_wall_2_gridmap: final_wall_2_gridmap.clear()
			source_gridmap.visible = true
			clear_fill = false
		else: printerr("GridMapMeshCustomizer: Missing mesh library, source, or final gridmap")

func mesh_presets_refresh():
	set_mesh_presets()
	load_mesh_presets(current_mesh_preset)


func set_mesh_presets():
	match MESH_PRESET:
		MeshPresetChoice.DEFAULT:
			current_mesh_preset = mesh_preset_1
		MeshPresetChoice.STONE_GRAVEYARD:
			current_mesh_preset = mesh_preset_2


func load_mesh_presets(preset : Dictionary):
	for mesh_idx in preset["mesh_items"]:
		if !mesh_lib.get_item_list().has(mesh_idx): return
	floor_mesh_idx = preset["mesh_items"][0]
	wall_mesh_idx = preset["mesh_items"][1]
	corner_mesh_idx = preset["mesh_items"][2]
	hallway_mesh_idx = preset["mesh_items"][3]
	if preset["mesh_items"].size() > 4:
		wall_2_mesh_idx = preset["mesh_items"][4]
		if preset["mesh_items"].size() > 5: corner_2_mesh_idx = preset["mesh_items"][5]

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
	if get_parent() is LevelGen:
		if current_mesh_preset and current_mesh_preset.keys().has("floor_under"):
			if current_mesh_preset["floor_under"].size() == 3 and current_mesh_preset["floor_under"][0]:
				final_under_gridmap.position.y = current_mesh_preset["floor_under"][1]
	#for x in range(-border_size + 1, border_size): # If centered
		#for z in range(-border_size + 1, border_size):
	var tile_index
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
				
				var trans_rotation = Vector3.ZERO
				var shuffled_orientation = -1
				if get_parent() is LevelGen:
					if current_mesh_preset and current_mesh_preset.keys().has("shuffle_floor"):
						if current_mesh_preset.has("shuffle_floor") and current_mesh_preset["shuffle_floor"]:
							shuffled_orientation = get_shuffled_orientation()
					if tile_index == get_tile_index(TileType.ROOM) || \
						tile_index == get_tile_index(TileType.DOOR):
						
						if shuffled_orientation == -1:
							var some_basis = Basis.from_euler(trans_rotation)
							var orth_idx = get_orthogonal_index_from_basis(some_basis)
							final_floor_gridmap.set_cell_item(pos, floor_mesh_idx,orth_idx)
						else:
							final_floor_gridmap.set_cell_item(pos, floor_mesh_idx,shuffled_orientation)
						
						floor_tile_count += 1
					elif tile_index == get_tile_index(TileType.HALLWAY):
						trans_rotation = Vector3(0, 0, 0)
						var some_basis = Basis.from_euler(trans_rotation)
						var orth_idx = get_orthogonal_index_from_basis(some_basis)
						final_floor_gridmap.set_cell_item(pos, hallway_mesh_idx,orth_idx)
						floor_tile_count += 1
					elif tile_index == get_tile_index(TileType.WALL) and final_wall_gridmap:
						var wall_orientation = get_wall_orientation(pos)
						#print("Orientation for ", 2*pos, ": ", orientation_map[wall_orientation])
						spawn_wall(pos, wall_orientation,final_wall_gridmap)
						wall_tile_count += 1
					
					# Add extra from mesh preset (ex: Ground tiles for Stone Graveyard preset)
					if MESH_PRESET == MeshPresetChoice.STONE_GRAVEYARD and current_mesh_preset:
						
						# Spawn fences
						if tile_index == get_tile_index(TileType.WALL) and final_wall_2_gridmap:
							var wall_orientation = get_wall_orientation(pos)
							spawn_wall(pos, wall_orientation,final_wall_2_gridmap,true)
						
						# Spawn tiles under floor
						if current_mesh_preset.keys().has("floor_under"):
							if current_mesh_preset["floor_under"].size() == 3 and current_mesh_preset["floor_under"][0] == true:
								var floor_mesh_lib : MeshLibrary = final_floor_gridmap.mesh_library
								var mesh : Mesh = floor_mesh_lib.get_item_mesh(tile_index)
								var mesh_height = mesh.get_aabb().size.y
								
								#var pos_y = pos.y - current_mesh_preset["floor_under"][1]
								var height = current_mesh_preset["floor_under"][2]
								spawn_floor_under(pos,mesh_height,height)
						


func get_shuffled_orientation() -> int:
	var angles = [0, 90, 180, 270]
	var random_angle = angles[randi() % angles.size()]
	var rotation_rad = deg_to_rad(random_angle)
	var new_basis = Basis(Vector3.UP, rotation_rad)
	return get_orthogonal_index_from_basis(new_basis)
	

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
		return 0  # Horizontal
	elif has_below and has_above:
		return 1  # Vertical
	elif !has_left and !has_right and !has_below and !has_above:
		return 6  # Single
	else:
		return -1 

# Given wall orientation, rotate and spawn wall
func spawn_wall(cell_position: Vector3, orientation: int, new_gridmap: GridMap,wall2=false):
	var orth_idx : int
	var trans_rotation : Vector3
	var wall_idx : int = wall_mesh_idx
	var corner_idx : int = corner_mesh_idx
	if wall2: 
		wall_idx = wall_2_mesh_idx
		corner_idx = corner_2_mesh_idx
	match orientation:
		0: # Horizontal wall
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_idx,orth_idx)
		1: # Vertical wall
			trans_rotation = Vector3(0, PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_idx,orth_idx)
		2: # Corner wall (top left)
			trans_rotation = Vector3(0, PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			
			new_gridmap.set_cell_item(cell_position, corner_idx,orth_idx)
		3: # Corner wall (top right)
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_idx,orth_idx)
		4: # Corner wall (bottom left)
			trans_rotation = Vector3(0, PI, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_idx,orth_idx)
		5: # Corner wall (bottom right)
			trans_rotation = Vector3(0, -PI / 2, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, corner_idx,orth_idx)
		6: # Single isolated wall (edge case)
			trans_rotation = Vector3(0, 0, 0)
			var some_basis = Basis.from_euler(trans_rotation)
			orth_idx = get_orthogonal_index_from_basis(some_basis)
			new_gridmap.set_cell_item(cell_position, wall_idx,orth_idx)
		_:  pass

func spawn_walls_preset():
	pass

func spawn_floor_under(pos : Vector3, _start_height, height):
	if !final_under_gridmap: return
	#var wall_mesh = mesh_library.get_item_mesh(get_tile_index(TileType.WALL))
	#var total_height = -start + wall_mesh.get_aabb().size.y/2
	
	var start_pos = pos
	start_pos.y -= 1

	for y in range(height):
		var current_pos = Vector3i(start_pos) - Vector3i(0, y, 0)
		final_under_gridmap.set_cell_item(current_pos, get_tile_index(TileType.WALL))
