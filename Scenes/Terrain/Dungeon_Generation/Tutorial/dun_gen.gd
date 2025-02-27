@tool
extends Node3D
class_name DunGen

@export var grid_map : GridMap
@export var level : Node3D
@export var start : bool = false : set = set_start
@export var load_meshes : bool = false
@export var wallgrid_spawn : bool = false
@export var print_info : bool = false

@export_category("GridMap Parameters")
@export_range(0,1) var survival_chance : float = 0.25
@export var border_size : int = 20 : set = set_border_size
@export var mesh_customizer : GridMapMeshCustomizer
@export var wallgrid_spawner : WallGridSpawner

@export_category("Room Parameters")
@export var room_number : int = 4
@export var room_margin : int = 1

@export var room_recursion : int = 15
@export var min_room_size : int = 2
@export var max_room_size : int = 4
@export_category("Hallway Parameters")
@export var min_hallway_width : int = 4
@export var max_hallway_width : int = 8
@export_category("Seed")
@export_multiline var custom_seed : String = "" : set = set_seed

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
var hallway_graph : AStar2D

func set_seed(val:String)-> void:
		custom_seed = val
		seed(val.hash())

var room_tiles : Array[PackedVector3Array] = []
var hallway_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		load_meshes = false

func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint() and start and grid_map:
		if mesh_customizer: 
			mesh_customizer.start = false
		generate()
		print("Dungeon Generated")
		start = false
		if mesh_customizer and load_meshes: # If enabled, load desired meshes over source gridmap
			mesh_customizer.start = true
		if wallgrid_spawner: # If enabled, generate walls
			if wallgrid_spawn:
				wallgrid_spawner.start = true
			else: wallgrid_spawner.clear_fill = true
		
		# Lastly, move player into first room
		var player_pos = Vector3(room_positions[0].x * 2,2,room_positions[0].z * 2)
		var npc_pos = Vector3(room_positions[1].x * 2,1,room_positions[1].z * 2)
		if level.is_in_group("Level"):
			for child in level.get_children():
				if child.is_in_group("Player"):
					child.position = player_pos
				if child.is_in_group("NPC"):
					child.position = npc_pos
					break
func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		if grid_map: visualize_border()
		if mesh_customizer: mesh_customizer.border_size = val
		if wallgrid_spawner: wallgrid_spawner.border_size = val - 10

func visualize_border():
	if grid_map: grid_map.clear()
	for i in range(-1, border_size+1):
		grid_map.set_cell_item(Vector3i(i,0,-1),get_tile_index(TileType.BORDER))
		grid_map.set_cell_item(Vector3i(i,0,border_size),get_tile_index(TileType.BORDER))
		grid_map.set_cell_item(Vector3i(border_size,0,i),get_tile_index(TileType.BORDER))
		grid_map.set_cell_item(Vector3i(-1,0,i),get_tile_index(TileType.BORDER))

func visualize_border_centered():
	if grid_map: grid_map.clear()
	for i in range(-border_size, border_size + 1):
		grid_map.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), get_tile_index(TileType.BORDER))  # Top border
		grid_map.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), get_tile_index(TileType.BORDER))  # Bottom border
		grid_map.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), get_tile_index(TileType.BORDER))  # Left border
		grid_map.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), get_tile_index(TileType.BORDER))  # Right border

func get_tile_index(tile_type: TileType) -> int:
	return tile_index_map[tile_type]

# Heavily modified code from Procedural Dungeons in Godot 4 - https://youtu.be/h64U6j_sFgs
# Modifications - Added variable hallway widths, added wall tiles that generate around rooms and hallways, 
# Added highlight tile for testing, integrated with GridMapMeshCustomizer and WallGridSpawner
func generate():
	room_tiles.clear()
	hallway_tiles.clear()
	room_positions.clear()
	if custom_seed : set_seed(custom_seed)
	visualize_border()
	for i in room_number:
		make_room(room_recursion)
	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	for p in room_positions: # For each generated room, create node point
		rpv2.append(Vector2(p.x,p.z))
		del_graph.add_point(del_graph.get_available_point_id(),Vector2(p.x,p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(),Vector2(p.x,p.z))
	
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	if room_positions.size() <= 2: # Breaks if two or less rooms (idk)
		print("Room count too small to create MST!")
		place_border_around_tiles(room_tiles,hallway_tiles,get_tile_index(TileType.WALL))
		return null
	for i in float(delaunay.size())/3.0: # Scan for triangles -> Create delauney graph connections
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1,p2)
		del_graph.connect_points(p2,p3)
		del_graph.connect_points(p1,p3)
	
	# Testing
	# For each room node in delauney graph, print its position and connections to other rooms
	if print_info:
		for id in del_graph.get_point_ids():
			print("Point ID: ", id, " Position: ", del_graph.get_point_position(id), " Connections: ", \
			del_graph.get_point_connections(id))
			
			# Testing
			var test_pos_x = del_graph.get_point_position(id).x * grid_map.cell_size.x
			var test_pos_z = del_graph.get_point_position(id).y * grid_map.cell_size.z
			var _test_pos = Vector3(test_pos_x,0,test_pos_z)
			#$Marker3D.position = test_pos
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi()% room_positions.size())
	
	# Not quite sure what's going on here
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections : Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp,c]
					possible_connections.append(con)
		
		var connection = possible_connections.pick_random()
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
		
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0],connection[1])
		del_graph.disconnect_points(connection[0], connection[1])
	
	hallway_graph = mst_graph
	
	# Iterate through all points and their connections in delauney graph 
	# For each connection, Randomly decide whether to connect the points in MST based on survival_chance
	for p in del_graph.get_point_ids():
		for c in del_graph.get_point_connections(p):
			if c>p:
				var kill : float = randf()
				if survival_chance > kill:
					hallway_graph.connect_points(p,c)
	
	var _path = hallway_graph.get_point_path(0, hallway_graph.get_point_count()-1)
	
	create_hallways(hallway_graph)
	print("Generating....")
	place_border_around_tiles(room_tiles,hallway_tiles,get_tile_index(TileType.WALL))
	#print(room_positions)

func create_hallways(h_graph:AStar2D):
	var hallways : Array = []
	var hall_widths = {}
	for p in h_graph.get_point_ids():
		for c in h_graph.get_point_connections(p):
			if c>p: # Directed MST Graph -> run once per edge
				# MST Graph - Print Room Nodes and edges
				if print_info: print("ID: ",p," Connection: ", c, " | [%s->%s]" % [p,c])
				var room_from : PackedVector3Array= room_tiles[p]
				var room_to : PackedVector3Array= room_tiles[c]
				
				# Old - Calculate shortest tile (1 tile hallway width)
				#var tile_from : Vector3 = room_from[0]
				#var tile_to : Vector3 = room_to[0]
				
				# New - Calculate shortest set of tiles (variable hallway width)
				var tiles_from : PackedVector3Array = []
				var tiles_to : PackedVector3Array = []
				
				# Calculate minimum room size between two rooms
				# Set limits for random hallway width
				var min_room_edge_length = min(min(get_room_dimensions(room_from).x, get_room_dimensions(room_from).y),
					min(get_room_dimensions(room_to).x, get_room_dimensions(room_to).y))
				
				var adjusted_width = min(max_hallway_width, min_room_edge_length)
				if print_info: print("Min hallway width: ", min_room_edge_length)
				
				var random_width = randi_range(min_hallway_width, adjusted_width)
				# Select four tiles for each room
				tiles_from = select_shortest_tiles(room_from, room_positions[c], random_width)
				tiles_to = select_shortest_tiles(room_to, room_positions[p], random_width)
				
				# Print set of tiles (shortest distance)
				if print_info:
					print("Shortest Tiles from: ", tiles_from)
					print("Shortest Tiles to: ", tiles_to)
				for tile in tiles_from:
					# Place door tiles connecting to room_to
					grid_map.set_cell_item(Vector3i(tile), get_tile_index(TileType.DOOR))
				for tile in tiles_to:
					# Place door tiles connecting from room_from
					grid_map.set_cell_item(Vector3i(tile), get_tile_index(TileType.DOOR))
				
				var hallway = [tiles_from, tiles_to]
				hall_widths[str(tiles_from,tiles_to)] = random_width
				hallways.append(hallway) # Set of hallway tiles stored for later
	# After 
	create_wide_hallways(hallways,hall_widths)

func create_wide_hallways(hallways : Array, widths: Dictionary):
	
	var hall_widths = widths
	if print_info: print("Creating AStarGrid2D...")
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.update()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	if print_info: print("Setting point solid..")
	for t in grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x,t.z))
	
	if print_info: print("Iterating through hallways")
	var h_tiles : PackedVector3Array = []
	for h in hallways:
		
		var tiles_from = h[0]  # List of tiles from
		var tiles_to = h[1]    # List of tiles to
		
		var hallway_width = hall_widths[str(tiles_from,tiles_to)]
		if print_info: 
			print("Hallway width: ",hallway_width)
			print("Hallway: \n    Tiles from: %s\n    Tiles to: %s" % [tiles_from, tiles_to])
		for i in range(min(tiles_from.size(), tiles_to.size())):
			var pos_from : Vector2i = Vector2i(int(tiles_from[i].x), int(tiles_from[i].z))
			var pos_to : Vector2i = Vector2i(int(tiles_to[i].x), int(tiles_to[i].z))
			#print("(",pos_from, ", ", pos_to,")")
			var hall : PackedVector2Array = astar.get_point_path(pos_from, pos_to)
			for t in hall:
				var pos : Vector3i = Vector3i(int(t.x), 0, int(t.y))
				if grid_map.get_cell_item(pos) < 0:
					grid_map.set_cell_item(pos, get_tile_index(TileType.HALLWAY))
					#var hallway = [tiles_from, tiles_to]
					h_tiles.append(pos)
		hallway_tiles.append(h_tiles)

func select_shortest_tiles(room: PackedVector3Array, room_position: Vector3,width: int) -> Array:
	var tiles_with_distance = []
	for tile in room:
		var distance = tile.distance_to(room_position)
		tiles_with_distance.append({"tile": tile, "distance": distance})
	tiles_with_distance.sort_custom(func(a, b):
		return a["distance"] < b["distance"]
	)
	var selected_tiles = []
	for i in range(min(width, tiles_with_distance.size())):
		selected_tiles.append(tiles_with_distance[i]["tile"])
	return selected_tiles

func manhattan_distance(v1: Vector3, v2: Vector3) -> int:
	return abs(v1.x - v2.x) + abs(v1.z - v2.z)

func get_room_dimensions(room: PackedVector3Array) -> Vector2:
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for tile in room:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_z = min(min_z, tile.z)
		max_z = max(max_z, tile.z)

	var width = max_x - min_x + 1
	var height = max_z - min_z + 1

	return Vector2(width, height)

func get_mesh_from_index(index: int) -> Mesh:
	var mesh_library = grid_map.mesh_library
	if mesh_library.has_item(index):
		return mesh_library.get_item_mesh(index)
	else:
		print("Index not found in MeshLibrary")
		return null

func place_border_around_tiles(rooms: Array, hallways: Array, wall_item_id: int):
	var all_tiles = []  # Store all room and hallway tiles
	if print_info:
		print("Rooms Count: ", rooms.size())
		print("Hallway Count: ", hallways.size())
		print("Total tiles: ", grid_map.get_used_cells().size())
	all_tiles += rooms
	all_tiles += hallways
	
	for tiles in all_tiles:
		for tile in tiles:
			var x = tile.x
			var z = tile.z
			# Check all 8 surrounding tiles (left, right, up, down, and diagonals)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					
					var neighbor_pos = Vector3i(x + dx, 0, z + dz)
					
					if grid_map.get_cell_item(neighbor_pos) < 0:  # Check if it's an empty space
						grid_map.set_cell_item(neighbor_pos, wall_item_id)

func make_room(rec : int):
	if rec<0: return
	
	@warning_ignore("integer_division")
	var width : int = max((randi() % (max_room_size - min_room_size) + min_room_size) / 4 * 4, 4)
	var height : int = max(randi() % (max_room_size - min_room_size) + min_room_size, 4)
	
	var start_pos : Vector3i
	#start_pos.x = randi() % (border_size - width + 1) - (border_size / 2) # If centered
	#start_pos.z = randi() % (border_size - width + 1) - (border_size / 2)
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - width + 1)
	
	for r in range(-room_margin,height+room_margin):
		for c in range(-room_margin,width+room_margin):
			var new_pos : Vector3i = start_pos + Vector3i(c,0,r)
			if grid_map.get_cell_item(new_pos) == 0: # 0 if occupied/-1 if empty
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var other_pos : Vector3i = start_pos + Vector3i(c,0,r)
			grid_map.set_cell_item(other_pos,0)
			room.append(other_pos)
	room_tiles.append(room)
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x,0,avg_z)
	room_positions.append(pos)
