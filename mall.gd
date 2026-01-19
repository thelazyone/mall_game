extends Node3D

# References to main nodes
var geometry
var player

# Setup state
var setup_complete: bool = false

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
	load_test_segments()
	
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

func load_test_segments() -> void:
	"""Load test instances of curve and short_segment from mall_assets"""
	print("Loading test segments...")
	
	# Load the mall_assets scene
	var mall_assets = load("res://mall_assets.blend")
	if not mall_assets:
		push_error("Failed to load mall_assets.blend!")
		return
	
	# Instantiate the scene to access its children
	var assets_instance = mall_assets.instantiate()
	
	print("Assets instance name: ", assets_instance.name)
	print("Assets instance scale: ", assets_instance.scale)
	print("Assets instance transform: ", assets_instance.transform)
	print("Assets instance children count: ", assets_instance.get_child_count())
	
	# Debug: print all children
	for child in assets_instance.get_children():
		print("  Child: ", child.name, " Type: ", child.get_class(), " Scale: ", child.scale if child is Node3D else "N/A")
	
	# Find the original mesh nodes (to copy their transforms)
	var curve_node = null
	var short_segment_node = null
	
	# Search recursively for the meshes (they might be nested)
	var nodes_to_check = [assets_instance]
	var scale_factor = 1.0
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_back()
		
		if node.name.contains("curve") and node is MeshInstance3D:
			curve_node = node
			curve_node.scale = curve_node.scale * scale_factor
			print("Found curve node: ", node.name, " with scale: ", node.scale, " and transform: ", node.transform)
		elif node.name.contains("short_segment") and node is MeshInstance3D:
			short_segment_node = node
			short_segment_node.scale = short_segment_node.scale * scale_factor
			print("Found short_segment node: ", node.name, " with scale: ", node.scale, " and transform: ", node.transform)
		
		# Add children to check
		for child in node.get_children():
			nodes_to_check.append(child)
	
	# Create 2 copies of short_segment
	if short_segment_node:
		pass

		# var segment1 = short_segment_node.duplicate()
		# segment1.position = Vector3(0, 0, 0)
		# add_child(segment1)
		# print("Added short_segment at (0, 0, 0) with final scale: ", segment1.scale)

		var segment1 = short_segment_node.duplicate()
		segment1.position = Vector3(31, 0, 32)
		add_child(segment1)	
		print("Added short_segment at (1, 0, 0) with final scale: ", segment1.scale)
		
		var segment2 = short_segment_node.duplicate()
		segment2.position = Vector3(33, 0, 32)
		add_child(segment2)
		print("Added short_segment at (2, 0, 0) with final scale: ", segment2.scale)

	else:
		push_error("short_segment mesh not found in mall_assets!")
	
	# Create 2 copies of curve
	if curve_node:
		pass
		# var curve1 = curve_node.duplicate()
		# curve1.position = Vector3(0, 0, 4)
		# curve1.scale = curve1.scale * scale_factor
		# add_child(curve1)
		# print("Added curve at (0, 0, 4) with final scale: ", curve1.scale)
		
		# var curve2 = curve_node.duplicate()
		# curve2.position = Vector3(4, 0, 4)
		# curve2.scale = curve2.scale * scale_factor
		# add_child(curve2)
		# print("Added curve at (4, 0, 4) with final scale: ", curve2.scale)
	else:
		push_error("curve mesh not found in mall_assets!")
	
	# Clean up the temporary instance
	assets_instance.queue_free()
	
	print("Test segments loaded successfully")

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
