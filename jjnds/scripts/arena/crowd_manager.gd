extends Node2D

class_name CrowdManager

# Manages all crowd sections and coordinates their reactions to combat events.

var crowd_sections: Array[CrowdSection] = []
var _camera: Camera2D

func _ready() -> void:
	_camera = get_node_or_null("/root/Main/Camera2D")
	if not _camera:
		# Fallback to get any camera
		_camera = get_viewport().get_camera_2d()
	# Add some default crowd sections if none exist in the tree
	if get_child_count() == 0:
		var cs_scene = load("res://scenes/arena/crowd_section.tscn")
		if cs_scene:
			# Left section
			var cs1 = cs_scene.instantiate() as CrowdSection
			cs1.position = Vector2(300, 250)
			cs1.section_width = 400
			cs1.crowd_density = 8
			add_child(cs1)
			
			# Center section
			var cs2 = cs_scene.instantiate() as CrowdSection
			cs2.position = Vector2(800, 200)
			cs2.section_width = 500
			cs2.crowd_density = 12
			add_child(cs2)
			
			# Right section
			var cs3 = cs_scene.instantiate() as CrowdSection
			cs3.position = Vector2(1300, 250)
			cs3.section_width = 400
			cs3.crowd_density = 8
			add_child(cs3)
	
	# Find all child crowd sections
	for child in get_children():
		if child is CrowdSection:
			crowd_sections.append(child)

func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_2d()
	if _camera:
		# Simple parallax effect: move crowd slightly in opposite direction of camera
		var cam_pos = _camera.get_screen_center_position() - (get_viewport_rect().size / 2.0)
		position = -cam_pos * 0.1

func set_crowd_state(state: CrowdSection.CrowdState, duration: float = 0.0) -> void:
	for cs in crowd_sections:
		cs.set_state(state, duration)

func trigger_reaction(reaction_type: String) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	
	match reaction_type:
		"strong_hit":
			# Small cheer for a strong hit
			set_crowd_state(CrowdSection.CrowdState.EXCITED, 1.5)
			if sm: sm.play("crowd_cheer", -10.0) # Lower volume
			
		"combo":
			# Medium cheer for a good combo
			set_crowd_state(CrowdSection.CrowdState.EXCITED, 2.5)
			if sm: sm.play("crowd_cheer", -5.0)
			
		"knockdown":
			# Everyone shocked/excited for a knockdown
			set_crowd_state(CrowdSection.CrowdState.SHOCK, 2.0)
			if sm: sm.play("crowd_cheer", 0.0)
			
		"countdown":
			# Nervous during the count
			set_crowd_state(CrowdSection.CrowdState.NERVOUS)
			
		"ko":
			# Big celebration for a KO
			set_crowd_state(CrowdSection.CrowdState.CELEBRATE, 5.0)
			if sm: sm.play("crowd_cheer", 5.0)
			
		"round_end":
			# Applause at the end of a round
			set_crowd_state(CrowdSection.CrowdState.EXCITED, 3.0)
			if sm: sm.play("crowd_cheer", -5.0)
			
		"boo":
			# Boo if action is slow or foul
			set_crowd_state(CrowdSection.CrowdState.IDLE, 3.0)
			if sm: sm.play("crowd_boo", 0.0)
