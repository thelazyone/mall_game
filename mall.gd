extends Node3D

# References to main nodes
var geometry
var player

# Setup state
var setup_complete: bool = false

# Procedural generation parameters
var mall_size: int = 10  # Number of segments per side

# Debug flag
var debug_stairs: bool = true  # Toggle stair generation debug output

# Asset loader configuration
var mall_assets_file: String = "res://mall_assets.blend"
var asset_list: Array = ["short_segment", "curve", "stair_slot", "stair_up", "stair_down"] 

# Loaded assets cache (mesh_name -> MeshInstance3D)
var loaded_assets: Dictionary = {}

# Stair data structure
class StairInfo:
	var floor: int  # Which floor this stair starts on
	var side: int   # Which side (0=bottomm, 1=right, 2=top, 3=left)
	var segment_pos: int  # Position within that side (in segments)
	var direction_forward: bool  # True = forward along path, False = backward
	
	func _init(f: int, s: int, pos: int, dir_fwd: bool):
		floor = f
		side = s
		segment_pos = pos
		direction_forward = dir_fwd
	
	func output_to_string() -> String:
		var side_name = ["Bottom", "Right", "Top", "Left"][side]
		var dir_name = "Forward" if direction_forward else "Backward"
		var arrival_pos = segment_pos + (4 if direction_forward else -4)
		return "Floor %d | Side: %s | Departure seg: %d | Arrival seg: %d | Direction: %s" % [floor, side_name, segment_pos, arrival_pos, dir_name]

# Mesh placement data structure
class MeshPlacement:
	var type: String  # "corner", "segment", "stair_departure", or "stair_arrival"
	var position: Vector3
	var stair_direction_forward: bool = true  # Only used for stairs
	
	func _init(t: String, pos: Vector3):
		type = t
		position = pos

func _ready() -> void:
	print("Mall scene initializing...")
	
	# Find the nodes
	geometry = find_child("Geometry", true, false)
	player = find_child("Player", true, false)
	
	if not geometry:
		push_error("Geometry node not found!")
		return
	
	if not player:
		push_error("Player node not found!")
		return
	
	print("Found Geometry and Player nodes")
	
	# Load everything from code for consistent scaling
	load_mall_scene()
	
	# Load and validate all assets
	if not load_all_assets():
		push_error("Failed to load required assets! Aborting scene setup.")
		return
	
	load_player_character()
	generate_procedural_mall()
	
	# Start the setup polling
	setup_scene()

func load_mall_scene() -> void:
	"""Load the mall.blend scene programmatically"""
	print("Loading mall scene from code...")
	
	var mall_scene = load("res://mall.blend")
	if not mall_scene:
		push_error("Failed to load mall.blend!")
		return
	
	var mall_instance = mall_scene.instantiate()
	add_child(mall_instance)
	print("Mall scene loaded with scale: ", mall_instance.scale)

func load_player_character() -> void:
	"""Load the player character mesh from character.blend"""
	print("Loading player character from code...")
	
	# Load the character.blend scene
	var character_scene = load("res://character.blend")
	if not character_scene:
		push_error("Failed to load character.blend!")
		return
	
	# Instantiate the scene
	var character_instance = character_scene.instantiate()
	
	# Find the character mesh
	var character_mesh = find_mesh_recursive(character_instance, "character")
	
	# Add the character to the player node
	if character_mesh:
		var char_duplicate = character_mesh.duplicate()
		player.add_child(char_duplicate)
		print("Character mesh added to player with scale: ", char_duplicate.scale)
	else:
		push_error("Character mesh not found in character.blend!")
	
	# Clean up the temporary instance
	character_instance.queue_free()
	
	print("Player character loaded")

func load_all_assets() -> bool:
	"""Load and validate all required assets from mall_assets.blend"""
	print("Loading assets from: ", mall_assets_file)
	
	# Load the mall_assets scene file
	var scene = load(mall_assets_file)
	if not scene:
		push_error("Failed to load file: %s" % mall_assets_file)
		return false
	
	# Instantiate to access meshes
	var scene_instance = scene.instantiate()
	
	# Load each mesh from the asset list
	for mesh_name in asset_list:
		print("  Looking for mesh: '%s'" % mesh_name)
		
		# Search for the mesh
		var found_mesh = find_mesh_recursive(scene_instance, mesh_name)
		
		if found_mesh:
			# Store the duplicated mesh node
			loaded_assets[mesh_name] = found_mesh.duplicate()
			print("    ✓ Loaded '%s' successfully (scale: %s)" % [mesh_name, loaded_assets[mesh_name].scale])
		else:
			push_error("    ✗ Mesh '%s' not found in '%s'" % [mesh_name, mall_assets_file])
			scene_instance.queue_free()
			return false
	
	# Clean up temporary instance
	scene_instance.queue_free()
	
	print("All assets loaded successfully!")
	return true

func find_mesh_recursive(node: Node, mesh_name: String) -> MeshInstance3D:
	"""Recursively search for a mesh by name"""
	if node.name.contains(mesh_name) and node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = find_mesh_recursive(child, mesh_name)
		if result:
			return result
	
	return null

func get_asset(asset_name: String) -> MeshInstance3D:
	"""Get a loaded asset by name, returns null and logs error if not found"""
	if loaded_assets.has(asset_name):
		return loaded_assets[asset_name]
	else:
		push_error("Asset '%s' not found! Available assets: %s" % [asset_name, loaded_assets.keys()])
		return null

func capture_stair_positions_from_mesh_generation(num_floors: int, floor_heights: Array, 
												   departure_stairs_lookup: Dictionary,
												   half_side: float) -> Array:
	"""Capture actual stair positions during mesh generation for geometry"""
	var geometry_stairs = []
	
	for floor_idx in range(num_floors):
		var floor_y = floor_heights[floor_idx]
		var departure_stairs = departure_stairs_lookup[floor_idx]
		
		# We'll capture positions for each side
		for side_idx in range(4):
			if not departure_stairs.has(side_idx):
				continue
			
			var stair_info = departure_stairs[side_idx]
			var departure_segment_pos = stair_info.segment_pos
			
			# Calculate the actual world position where the stair mesh is placed
			var stair_world_pos = Vector3.ZERO
			var side_accumulated_distance = 0.0  # Distance from start of this path segment
			
			# Calculate based on which side
			if side_idx == 0:  # Bottom (left to right)
				var x = -half_side + 4.0  # After corner
				var i = 0
				while i <= departure_segment_pos:
					if i == departure_segment_pos:
						stair_world_pos = Vector3(x, floor_y, -half_side)
						side_accumulated_distance = x - (-half_side + 4.0)
						break
					x += 2.0
					i += 1
			elif side_idx == 1:  # Right (bottom to top)
				var z = -half_side + 4.0
				var i = 0
				while i <= departure_segment_pos:
					if i == departure_segment_pos:
						stair_world_pos = Vector3(half_side, floor_y, z)
						side_accumulated_distance = z - (-half_side + 4.0)
						break
					z += 2.0
					i += 1
			elif side_idx == 2:  # Top (right to left)
				var x = half_side - 4.0
				var i = 0
				while i <= departure_segment_pos:
					if i == departure_segment_pos:
						stair_world_pos = Vector3(x, floor_y, half_side)
						side_accumulated_distance = (half_side - 4.0) - x
						break
					x -= 2.0
					i += 1
			elif side_idx == 3:  # Left (top to bottom)
				var z = half_side - 4.0
				var i = 0
				while i <= departure_segment_pos:
					if i == departure_segment_pos:
						stair_world_pos = Vector3(-half_side, floor_y, z)
						side_accumulated_distance = (half_side - 4.0) - z
						break
					z -= 2.0
					i += 1
			
			# Arrival is 8 units ahead in the path direction
			var arrival_side = side_idx
			var arrival_distance = side_accumulated_distance + 8.0
			var side_length = (mall_size * 2.0)  # Total length of segments on this side
			
			# Check if arrival wraps to next side
			if arrival_distance >= side_length:
				arrival_distance -= side_length
				arrival_side = (arrival_side + 1) % 4
			
			# Add UPWARD stair on this floor
			geometry_stairs.append({
				"floor": floor_idx,
				"segment_index": side_idx,
				"position_on_segment": side_accumulated_distance,
				"arrival_segment": arrival_side,
				"arrival_position": arrival_distance,
				"arrival_floor": floor_idx + 1,
				"going_up": true
			})
			
			# Add corresponding DOWNWARD stair on the floor above
			if floor_idx + 1 < num_floors:
				geometry_stairs.append({
					"floor": floor_idx + 1,
					"segment_index": arrival_side,
					"position_on_segment": arrival_distance,
					"arrival_segment": side_idx,
					"arrival_position": side_accumulated_distance,
					"arrival_floor": floor_idx,
					"going_up": false
				})
	
	return geometry_stairs

func generate_stair_data(num_floors: int) -> Array:
	"""Generate all stair data for the mall structure"""
	var all_stairs = []  # Array of StairInfo objects
	
	# Seed randomizer
	randomize()
	
	# Track which sides have stairs and their directions (for consistency between floors)
	# Format: side_idx -> direction_forward
	var previous_floor_side_directions = {}
	
	# Fixed positions for stairs (in segment units, not world units)
	var forward_departure_segment = (mall_size / 2) - 3  # center-minus-six for forward
	if forward_departure_segment < 0:
		forward_departure_segment = 0
	forward_departure_segment = (forward_departure_segment / 2) * 2  # Ensure even
	
	var backward_departure_segment = (mall_size / 2) + 1  # center-plus-two for backward
	backward_departure_segment = (backward_departure_segment / 2) * 2  # Ensure even
	
	# For each floor except the top, generate two stairs going up
	for floor_idx in range(num_floors - 1):
		# Pick two different random sides
		var available_sides = [0, 1, 2, 3]
		available_sides.shuffle()
		var side1 = available_sides[0]
		var side2 = available_sides[1]
		
		var current_floor_side_directions = {}
		
		# Create stairs for both sides
		for side_idx in [side1, side2]:
			var direction_forward: bool
			
			# Check if this side had a stair on the floor below
			if previous_floor_side_directions.has(side_idx):
				# Keep same direction for consistency
				direction_forward = previous_floor_side_directions[side_idx]
			else:
				# New side, pick random direction
				direction_forward = randf() > 0.5
			
			# Choose segment position based on direction
			var segment_pos = forward_departure_segment if direction_forward else backward_departure_segment
			
			# Create the stair
			var stair = StairInfo.new(floor_idx, side_idx, segment_pos, direction_forward)
			all_stairs.append(stair)
			
			# Track this side's direction for next floor
			current_floor_side_directions[side_idx] = direction_forward
		
		# Update for next iteration
		previous_floor_side_directions = current_floor_side_directions
	
	return all_stairs

func print_stair_data(stairs: Array) -> void:
	"""Print all stair data in a readable format"""
	if not debug_stairs:
		return
	
	print("\n========== STAIR GENERATION DATA ==========")
	print("Total stairs: ", stairs.size())
	print("Mall size (segments per side): ", mall_size)
	print("\nForward direction:")
	print("  Departure segment position: ", (mall_size / 2) - 3)
	print("  Arrival segment position: ", ((mall_size / 2) - 3) + 4, " = ", (mall_size / 2) + 1)
	print("\nBackward direction:")
	print("  Departure segment position: ", (mall_size / 2) + 1)
	print("  Arrival segment position: ", ((mall_size / 2) + 1) - 4, " = ", (mall_size / 2) - 3)
	print("\n-------------------------------------------")
	
	# Group by floor
	var floors = {}
	for stair in stairs:
		if not floors.has(stair.floor):
			floors[stair.floor] = []
		floors[stair.floor].append(stair)
	
	# Print each floor
	var floor_keys = floors.keys()
	floor_keys.sort()
	for floor_idx in floor_keys:
		print("\n--- Floor ", floor_idx, " (connects to floor ", floor_idx + 1, ") ---")
		for stair in floors[floor_idx]:
			print("  ", stair.output_to_string())
	
	print("\n===========================================\n")

func generate_procedural_mall() -> void:
	"""Generate a procedural mall based on mall_size parameter"""
	print("Generating procedural mall with size: ", mall_size)
	
	var segment_template = get_asset("short_segment")
	var corner_template = get_asset("curve")
	var stair_slot_template = get_asset("stair_slot")
	var stair_up_template = get_asset("stair_up")
	var stair_down_template = get_asset("stair_down")
	
	if not segment_template or not corner_template or not stair_slot_template or not stair_up_template or not stair_down_template:
		push_error("Required assets not available!")
		return
	
	# Step 1: Generate the simple abstract geometry (4 corners for a rectangle)
	var side_length = 4 + (mall_size * 2)
	var half_side = side_length / 2.0
	
	var geometry_corners = [
		Vector2(-half_side, -half_side),  # Bottom-left
		Vector2(half_side, -half_side),   # Bottom-right
		Vector2(half_side, half_side),    # Top-right
		Vector2(-half_side, half_side)    # Top-left
	]
	
	# Update geometry with simple 4-corner path
	if geometry and geometry.has_method("define_path"):
		geometry.define_path(geometry_corners)
		print("Updated geometry path with 4 corners")
	else:
		push_error("Geometry node not found or doesn't have define_path method!")
	
	# Step 2: Generate 5 floors (2 below, current, 2 above) - floors are 4 tall
	var floor_heights = [-8, -4, 0, 4, 8]
	var num_floors = floor_heights.size()
	
	# Step 3: Generate stair data
	var all_stairs = generate_stair_data(num_floors)
	print_stair_data(all_stairs)
	
	# Convert stair data to lookup tables for easier access during mesh generation
	# departure_stairs[floor][side] = StairInfo
	var departure_stairs_lookup = {}
	for floor_idx in range(num_floors):
		departure_stairs_lookup[floor_idx] = {}
	
	for stair in all_stairs:
		departure_stairs_lookup[stair.floor][stair.side] = stair
	
	# arrival_stairs[floor][side] = StairInfo (from floor below)
	var arrival_stairs_lookup = {}
	for floor_idx in range(num_floors):
		arrival_stairs_lookup[floor_idx] = {}
	
	for stair in all_stairs:
		var arrival_floor = stair.floor + 1
		if arrival_floor < num_floors:
			arrival_stairs_lookup[arrival_floor][stair.side] = stair
	
	# Capture actual stair positions for geometry
	var geometry_stair_data = capture_stair_positions_from_mesh_generation(
		num_floors, floor_heights, departure_stairs_lookup, half_side)
	
	# Debug: print converted geometry stair data
	if debug_stairs:
		print("\n========== CONVERTED GEOMETRY STAIR DATA ==========")
		for i in range(geometry_stair_data.size()):
			var gs = geometry_stair_data[i]
			var side_name = ["Bottom", "Right", "Top", "Left"][gs["segment_index"]]
			var direction = "UP" if gs["going_up"] else "DOWN"
			print("Stair ", i, ": Floor ", gs["floor"], " | Direction: ", direction)
			print("  Side: ", side_name, " (", gs["segment_index"], ") | Pos: ", gs["position_on_segment"])
			print("  -> Arrival floor: ", gs["arrival_floor"], " | Side: ", ["Bottom", "Right", "Top", "Left"][gs["arrival_segment"]], 
				  " (", gs["arrival_segment"], ") | Pos: ", gs["arrival_position"])
		print("=================================================\n")
	
	if geometry and geometry.has_method("define_floors"):
		geometry.define_floors(num_floors, geometry_stair_data)
		print("Geometry floors defined with ", geometry_stair_data.size(), " stairs")
	
	# Step 4: Generate mesh placements for each floor
	for floor_idx in range(num_floors):
		var floor_y = floor_heights[floor_idx]
		var mesh_placements: Array = []
		
		# Get stair info for this floor
		var departure_stairs = departure_stairs_lookup[floor_idx]  # side -> StairInfo
		var arrival_stairs = arrival_stairs_lookup[floor_idx]  # side -> StairInfo
		
		# Bottom side (0): left to right
		var x = -half_side
		var z = -half_side
		mesh_placements.append(MeshPlacement.new("corner", Vector3(x, floor_y, z)))
		x += 4  # Corner is 4 wide
		var i = 0
		while i < mall_size:
			var placed = false
			
			# Check for departure stair (going up from this floor)
			if departure_stairs.has(0):
				var stair_info = departure_stairs[0]
				if i == stair_info.segment_pos:
					var stair_departure = MeshPlacement.new("stair_departure", Vector3(x, floor_y, z))
					stair_departure.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_departure)
					x += 4
					i += 2
					placed = true
			
			# Check for arrival stair (coming down from floor below)
			if not placed and arrival_stairs.has(0):
				var stair_info = arrival_stairs[0]
				# Arrival is +4 segments if forward, -4 segments if backward
				var arrival_pos = stair_info.segment_pos + (4 if stair_info.direction_forward else -4)
				if i == arrival_pos:
					var stair_arrival = MeshPlacement.new("stair_arrival", Vector3(x, floor_y, z))
					stair_arrival.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_arrival)
					x += 4
					i += 2
					placed = true
			
			if not placed:
				mesh_placements.append(MeshPlacement.new("segment", Vector3(x - 1, floor_y, z)))
				x += 2
				i += 1
		
		# Right side (1): bottom to top
		x = half_side
		z = -half_side
		mesh_placements.append(MeshPlacement.new("corner", Vector3(x, floor_y, z)))
		z += 4  # Corner is 4 wide
		i = 0
		while i < mall_size:
			var placed = false
			
			if departure_stairs.has(1):
				var stair_info = departure_stairs[1]
				if i == stair_info.segment_pos:
					var stair_departure = MeshPlacement.new("stair_departure", Vector3(x, floor_y, z))
					stair_departure.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_departure)
					z += 4
					i += 2
					placed = true
			
			if not placed and arrival_stairs.has(1):
				var stair_info = arrival_stairs[1]
				var arrival_pos = stair_info.segment_pos + (4 if stair_info.direction_forward else -4)
				if i == arrival_pos:
					var stair_arrival = MeshPlacement.new("stair_arrival", Vector3(x, floor_y, z))
					stair_arrival.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_arrival)
					z += 4
					i += 2
					placed = true
			
			if not placed:
				mesh_placements.append(MeshPlacement.new("segment", Vector3(x, floor_y, z - 1)))
				z += 2
				i += 1
		
		# Top side (2): right to left
		x = half_side
		z = half_side
		mesh_placements.append(MeshPlacement.new("corner", Vector3(x, floor_y, z)))
		x -= 4  # Corner is 4 wide
		i = 0
		while i < mall_size:
			var placed = false
			
			if departure_stairs.has(2):
				var stair_info = departure_stairs[2]
				if i == stair_info.segment_pos:
					var stair_departure = MeshPlacement.new("stair_departure", Vector3(x, floor_y, z))
					stair_departure.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_departure)
					x -= 4
					i += 2
					placed = true
			
			if not placed and arrival_stairs.has(2):
				var stair_info = arrival_stairs[2]
				var arrival_pos = stair_info.segment_pos + (4 if stair_info.direction_forward else -4)
				if i == arrival_pos:
					var stair_arrival = MeshPlacement.new("stair_arrival", Vector3(x, floor_y, z))
					stair_arrival.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_arrival)
					x -= 4
					i += 2
					placed = true
			
			if not placed:
				mesh_placements.append(MeshPlacement.new("segment", Vector3(x + 1, floor_y, z)))
				x -= 2
				i += 1
		
		# Left side (3): top to bottom
		x = -half_side
		z = half_side
		mesh_placements.append(MeshPlacement.new("corner", Vector3(x, floor_y, z)))
		z -= 4  # Corner is 4 wide
		i = 0
		while i < mall_size:
			var placed = false
			
			if departure_stairs.has(3):
				var stair_info = departure_stairs[3]
				if i == stair_info.segment_pos:
					var stair_departure = MeshPlacement.new("stair_departure", Vector3(x, floor_y, z))
					stair_departure.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_departure)
					z -= 4
					i += 2
					placed = true
			
			if not placed and arrival_stairs.has(3):
				var stair_info = arrival_stairs[3]
				var arrival_pos = stair_info.segment_pos + (4 if stair_info.direction_forward else -4)
				if i == arrival_pos:
					var stair_arrival = MeshPlacement.new("stair_arrival", Vector3(x, floor_y, z))
					stair_arrival.stair_direction_forward = stair_info.direction_forward
					mesh_placements.append(stair_arrival)
					z -= 4
					i += 2
					placed = true
			
			if not placed:
				mesh_placements.append(MeshPlacement.new("segment", Vector3(x, floor_y, z + 1)))
				z -= 2
				i += 1
		
		# Step 5: Instantiate meshes with calculated rotations
		for j in range(mesh_placements.size()):
			var placement = mesh_placements[j]
			var next_placement = mesh_placements[(j + 1) % mesh_placements.size()]
			
			# Calculate direction to next placement
			var direction = (next_placement.position - placement.position).normalized()
			var angle = -atan2(direction.z, direction.x)
			var angle_degrees = rad_to_deg(angle)
			
			# Instantiate the appropriate mesh
			if placement.type == "corner":
				var corner = corner_template.duplicate()
				corner.position = placement.position
				corner.rotation_degrees.y = angle_degrees
				add_child(corner)
			elif placement.type == "segment":
				var segment = segment_template.duplicate()
				segment.position = placement.position
				segment.rotation_degrees.y = angle_degrees
				add_child(segment)
			elif placement.type == "stair_departure":
				# Departure stair (going up from this floor)
				# direction_forward=true: stair goes forward (right) - stair_up normal
				# direction_forward=false: stair goes backward (left) - stair_up x-flipped
				
				var dir_forward = placement.stair_direction_forward
				
				# Place stair_slot
				var stair_slot = stair_slot_template.duplicate()
				stair_slot.position = placement.position
				stair_slot.rotation_degrees.y = angle_degrees
				add_child(stair_slot)
				
				# Place stair_up (on top of slot)
				var stair_up = stair_up_template.duplicate()
				stair_up.position = placement.position
				stair_up.rotation_degrees.y = angle_degrees
				if not dir_forward:
					stair_up.scale.x = -1  # Flip to face backward
				add_child(stair_up)
				
			elif placement.type == "stair_arrival":
				# Arrival stair (coming down to this floor from above)
				# direction_forward=true: stair came forward (right) - stair_down x-flipped
				# direction_forward=false: stair came backward (left) - stair_down normal
				
				var dir_forward = placement.stair_direction_forward
				
				# Place stair_slot
				var stair_slot = stair_slot_template.duplicate()
				stair_slot.position = placement.position
				stair_slot.rotation_degrees.y = angle_degrees
				add_child(stair_slot)
				
				# Place stair_down (on top of slot)
				var stair_down = stair_down_template.duplicate()
				stair_down.position = placement.position
				stair_down.rotation_degrees.y = angle_degrees
				if dir_forward:
					stair_down.scale.x = -1  # Flip to face backward (opposite of up)
				add_child(stair_down)
	
	print("Procedural mall generation complete with ", num_floors, " floors!")

func setup_scene() -> void:
	"""Poll until geometry is ready, then initialize player"""
	print("Starting setup polling...")
	
	# Poll until geometry path is defined
	while not geometry.is_path_defined:
		await get_tree().process_frame
		print("Waiting for geometry path to be defined...")
	
	print("Geometry path is ready!")
	
	# Now initialize the player
	if player.has_method("initialize_position"):
		player.initialize_position()
		print("Player position initialized via mall.gd")
		setup_complete = true
	else:
		push_error("Player doesn't have initialize_position method!")

func _process(_delta: float) -> void:
	if not setup_complete:
		# Visual feedback that setup is still in progress
		pass
