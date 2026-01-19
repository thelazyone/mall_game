extends Node3D

# References to main nodes
var geometry
var player

# Setup state
var setup_complete: bool = false

# Procedural generation parameters
var mall_size: int = 10  # Number of segments per side

# Asset loader configuration
var mall_assets_file: String = "res://mall_assets.blend"
var asset_list: Array = ["short_segment", "curve", "stair_slot", "stair_up", "stair_down"] 

# Loaded assets cache (mesh_name -> MeshInstance3D)
var loaded_assets: Dictionary = {}

# Mesh placement data structure
class MeshPlacement:
	var type: String  # "corner" or "segment"
	var position: Vector3
	
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

func generate_procedural_mall() -> void:
	"""Generate a procedural mall based on mall_size parameter"""
	print("Generating procedural mall with size: ", mall_size)
	
	var segment_template = get_asset("short_segment")
	var corner_template = get_asset("curve")
	
	if not segment_template or not corner_template:
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
	
	# Step 2: Generate detailed mesh placement list
	var mesh_placements: Array = []
	
	# Bottom side (left to right): corner, segments, corner
	var x = -half_side
	var z = -half_side
	mesh_placements.append(MeshPlacement.new("corner", Vector3(x, 0, z)))
	x += 4  # Corner is 4 wide
	for i in range(mall_size):
		mesh_placements.append(MeshPlacement.new("segment", Vector3(x, 0, z)))
		x += 2  # Segment is 2 wide
	
	# Right side (bottom to top): corner, segments, corner
	x = half_side
	z = -half_side
	mesh_placements.append(MeshPlacement.new("corner", Vector3(x, 0, z)))
	z += 4  # Corner is 4 wide
	for i in range(mall_size):
		mesh_placements.append(MeshPlacement.new("segment", Vector3(x, 0, z)))
		z += 2  # Segment is 2 wide
	
	# Top side (right to left): corner, segments, corner
	x = half_side
	z = half_side
	mesh_placements.append(MeshPlacement.new("corner", Vector3(x, 0, z)))
	x -= 4  # Corner is 4 wide
	for i in range(mall_size):
		mesh_placements.append(MeshPlacement.new("segment", Vector3(x, 0, z)))
		x -= 2  # Segment is 2 wide
	
	# Left side (top to bottom): corner, segments (last corner wraps to start)
	x = -half_side
	z = half_side
	mesh_placements.append(MeshPlacement.new("corner", Vector3(x, 0, z)))
	z -= 4  # Corner is 4 wide
	for i in range(mall_size):
		mesh_placements.append(MeshPlacement.new("segment", Vector3(x, 0, z)))
		z -= 2  # Segment is 2 wide
	
	# Step 3: Instantiate meshes with calculated rotations
	for i in range(mesh_placements.size()):
		var placement = mesh_placements[i]
		var next_placement = mesh_placements[(i + 1) % mesh_placements.size()]
		
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
			print("Added corner at ", placement.position, " with rotation ", angle_degrees)
		elif placement.type == "segment":
			var segment = segment_template.duplicate()
			segment.position = placement.position
			segment.rotation_degrees.y = angle_degrees
			add_child(segment)
			print("Added segment at ", placement.position, " with rotation ", angle_degrees)
	
	print("Procedural mall generation complete! Generated ", mesh_placements.size(), " mesh placements")

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
