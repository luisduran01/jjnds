extends Node2D

class_name CrowdSection

# Represents a section of the crowd. Manages multiple AnimatedSprite2D instances.

@export var crowd_density: int = 10
@export var section_width: float = 800.0

var crowd_members: Array[AnimatedSprite2D] = []

enum CrowdState {
	IDLE,
	EXCITED,
	NERVOUS,
	CELEBRATE,
	SHOCK
}

var current_state: CrowdState = CrowdState.IDLE
var reaction_timer: Timer

func _ready() -> void:
	reaction_timer = Timer.new()
	reaction_timer.one_shot = true
	reaction_timer.timeout.connect(_on_reaction_timeout)
	add_child(reaction_timer)
	
	_generate_crowd()
	_start_idle_loop()

func _generate_crowd() -> void:
	# Create empty SpriteFrames to avoid errors, we will add placeholder animations
	var frames = SpriteFrames.new()
	var anims = ["idle", "clap", "cheer", "jump", "hands_up", "boo", "celebrate", "shock"]
	for anim in anims:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 5.0)

	var spacing = section_width / max(1, crowd_density - 1)
	
	for i in range(crowd_density):
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		# Random position within the section
		sprite.position.x = -section_width/2.0 + (i * spacing) + randf_range(-20.0, 20.0)
		sprite.position.y = randf_range(-30.0, 30.0)
		# Random scale for variety
		var s = randf_range(0.8, 1.2)
		sprite.scale = Vector2(s, s)
		
		# Placeholder visual since frames are empty (we can use modulate to simulate state if no texture)
		var placeholder = ColorRect.new()
		placeholder.size = Vector2(20, 40)
		placeholder.position = Vector2(-10, -40)
		placeholder.color = Color(randf(), randf(), randf(), 0.5)
		sprite.add_child(placeholder)
		
		add_child(sprite)
		crowd_members.append(sprite)

func set_state(state: CrowdState, duration: float = 0.0) -> void:
	current_state = state
	
	for member in crowd_members:
		_apply_state_animation(member)
		
	if duration > 0.0:
		reaction_timer.start(duration)

func _on_reaction_timeout() -> void:
	set_state(CrowdState.IDLE)

func _start_idle_loop() -> void:
	# Periodically change some members' idle animations slightly
	for member in crowd_members:
		if current_state == CrowdState.IDLE:
			_apply_state_animation(member)
	
	get_tree().create_timer(randf_range(2.0, 5.0)).timeout.connect(_start_idle_loop)

func _apply_state_animation(member: AnimatedSprite2D) -> void:
	if not member.sprite_frames:
		return
		
	var anim_name = "idle"
	var speed_scale = 1.0
	
	match current_state:
		CrowdState.IDLE:
			var roll = randf()
			if roll < 0.6: anim_name = "idle"
			elif roll < 0.8: anim_name = "clap"
			else: anim_name = "cheer"
			speed_scale = randf_range(0.8, 1.2)
		CrowdState.EXCITED:
			var roll = randf()
			if roll < 0.4: anim_name = "cheer"
			elif roll < 0.8: anim_name = "hands_up"
			else: anim_name = "jump"
			speed_scale = randf_range(1.2, 1.5)
		CrowdState.NERVOUS:
			anim_name = "idle"
			speed_scale = randf_range(0.5, 0.8)
		CrowdState.CELEBRATE:
			var roll = randf()
			if roll < 0.5: anim_name = "celebrate"
			else: anim_name = "jump"
			speed_scale = randf_range(1.3, 1.8)
		CrowdState.SHOCK:
			anim_name = "shock"
			speed_scale = 1.0
	
	if member.sprite_frames.has_animation(anim_name):
		member.play(anim_name)
		member.speed_scale = speed_scale
		
		# Visual feedback for placeholder
		var rect = member.get_child(0) as ColorRect
		if rect:
			var tween = create_tween()
			match current_state:
				CrowdState.IDLE: tween.tween_property(rect, "position:y", -40.0, 0.5)
				CrowdState.EXCITED: tween.tween_property(rect, "position:y", -50.0, 0.2).set_loops(2)
				CrowdState.CELEBRATE: tween.tween_property(rect, "position:y", -60.0, 0.3).set_loops(4)
				CrowdState.SHOCK: tween.tween_property(rect, "scale:y", 1.2, 0.1)
				CrowdState.NERVOUS: tween.tween_property(rect, "scale:y", 0.9, 0.5)
