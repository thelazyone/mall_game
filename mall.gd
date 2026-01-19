extends Node3D

# References to main nodes
var geometry
var player

# Setup state
var setup_complete: bool = false

# Procedural generation parameters
var mall_size: int = 10  # Number of segments per side
var segment_rotation_offset: float = 0.0  # Rotation offset for segments (in degrees)
var corner_rotation_offset: float = 0.0  # Rotation offset for corners (in degrees)

# Asset references
var segment_template = null
var corner_template = null

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
	load_player_character()
	load_asset_templates()
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
	
	print("Character instance name: ", character_instance.name)
	print("Character instance scale: ", character_instance.scale)
	print("Character instance children count: ", character_instance.get_child_count())
	
	# Debug: print all children
	for child in character_instance.get_children():
		print("  Character child: ", child.name, " Type: ", child.get_class(), " Scale: ", child.scale if child is Node3D else "N/A")
	
	# Find the character mesh
	var character_mesh = null
	var nodes_to_check = [character_instance]
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_back()
		
		if node.name.contains("character") and node is MeshInstance3D:
			character_mesh = node
			print("Found character mesh: ", node.name, " with scale: ", node.scale)
		
		# Add children to check
		for child in node.get_children():
			nodes_to_check.append(child)
	
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

func load_asset_templates() -> void:
	"""Load the asset templates from mall_assets.blend"""
	print("Loading asset templates...")
	
	# Load the mall_assets scene
	var mall_assets = load("res://mall_assets.blend")
	if not mall_assets:
		push_error("Failed to load mall_assets.blend!")
		return
	
	# Instantiate the scene to access its children
	var assets_instance = mall_assets.instantiate()
	
	print("Assets instance name: ", assets_instance.name)
	print("Assets instance scale: ", assets_instance.scale)
	
	# Search recursively for the meshes
	var nodes_to_check = [assets_instance]
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_back()
		
		if node.name.contains("curve") and node is MeshInstance3D:
			corner_template = node.duplicate()
			print("Found corner template: ", node.name, " with scale: ", corner_template.scale)
		elif node.name.contains("short_segment") and node is MeshInstance3D:
			segment_template = node.duplicate()
			print("Found segment template: ", node.name, " with scale: ", segment_template.scale)
		
		# Add children to check
		for child in node.get_children():
			nodes_to_check.append(child)
	
	# Clean up the temporary instance
	assets_instance.queue_free()
	
	if not segment_template:
		push_error("short_segment mesh not found in mall_assets!")
	if not corner_template:
		push_error("curve mesh not found in mall_assets!")
	
	print("Asset templates loaded successfully")

func generate_procedural_mall() -> void:
	"""Generate a procedural mall based on mall_size parameter"""
	print("Generating procedural mall with size: ", mall_size)
	
	if not segment_template or not corner_template:
		push_error("Asset templates not loaded!")
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
			corner.rotation_degrees.y = corner_rotation_offset + angle_degrees
			add_child(corner)
			print("Added corner at ", placement.position, " with rotation ", angle_degrees)
		elif placement.type == "segment":
			var segment = segment_template.duplicate()
			segment.position = placement.position
			segment.rotation_degrees.y = segment_rotation_offset + angle_degrees
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
