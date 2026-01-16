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
	
	# Start the setup polling
	setup_scene()

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
