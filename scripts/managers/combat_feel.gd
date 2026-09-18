extends Node

# process_mode = ALWAYS so hit-stop timer still fires when tree is paused

# =============================================================
# COMBAT FEEL — Phase 1 Polish
# Centraliza: hit-stop, screen shake, impact flash, combo counter.
# =============================================================

# --- Hit-stop config ---
const HIT_STOP = {
	"jab":      0.020,
	"cross":    0.035,
	"hook":     0.050,
	"uppercut": 0.055,
	"body":     0.030,
	"knockdown":0.080,
	"ko":       0.120,
}

# --- Shake config ---
const SHAKE = {
	"jab":       Vector2(1.5, 1.0),
	"cross":     Vector2(3.0, 2.0),
	"hook":      Vector2(4.0, 2.5),
	"uppercut":  Vector2(3.5, 4.5),
	"body":      Vector2(2.0, 1.5),
	"knockdown": Vector2(6.0, 5.0),
	"ko":        Vector2(9.0, 7.0),
}

# --- Internal ---
var _camera: Camera2D = null
var _camera_origin: Vector2 = Vector2.ZERO
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
const SHAKE_DECAY: float = 8.0

var _combo_count: int = 0
var _combo_reset_timer: float = 0.0
const COMBO_RESET_DELAY: float = 1.2

var _combo_label: Label = null

func setup(camera: Camera2D, combo_label: Label) -> void:
	_camera = camera
	# Don't store origin here — main.gd manages zoom; we only manage offset shake
	_camera_origin = Vector2.ZERO
	_combo_label = combo_label
	if _combo_label:
		_combo_label.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_update_shake(delta)
	_update_combo(delta)

# ----------------------------------------------------------
# HIT-STOP (micro freeze via time scale)
# ----------------------------------------------------------
func trigger_hit_stop(punch_type: String) -> void:
	var dur = HIT_STOP.get(punch_type, 0.025)
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur * 0.05, true, false, true).timeout
	Engine.time_scale = 1.0

# ----------------------------------------------------------
# SCREEN SHAKE
# ----------------------------------------------------------
func trigger_shake(punch_type: String) -> void:
	if not _camera:
		return
	var v: Vector2 = SHAKE.get(punch_type, Vector2(2.0, 1.5))
	_shake_intensity = v.x
	_shake_timer = v.y * 0.06

func _update_shake(delta: float) -> void:
	if not _camera:
		return
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var r := Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity * 0.6, _shake_intensity * 0.6)
		)
		# Add shake as offset ON TOP of whatever zoom-offset the camera has
		_camera.offset = r
		_shake_intensity = lerpf(_shake_intensity, 0.0, SHAKE_DECAY * delta)
	else:
		_camera.offset = Vector2.ZERO

# ----------------------------------------------------------
# IMPACT FLASH (sprite turns white briefly)
# ----------------------------------------------------------
func trigger_flash(sprite: AnimatedSprite2D, duration: float = 0.045) -> void:
	if not sprite or not is_instance_valid(sprite):
		return
	sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)  # Overbright white
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(sprite):
		# Fade back to normal
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)

# ----------------------------------------------------------
# COMBO COUNTER
# ----------------------------------------------------------
func register_hit(punch_type: String) -> void:
	_combo_count += 1
	_combo_reset_timer = COMBO_RESET_DELAY
	_update_combo_display(punch_type)
	# Trigger feel effects
	trigger_shake(punch_type)

func _update_combo(delta: float) -> void:
	if _combo_count > 0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_combo_count = 0
			if _combo_label:
				var tw = create_tween()
				tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)

func _update_combo_display(punch_type: String) -> void:
	if not _combo_label:
		return
	if _combo_count < 2:
		_combo_label.modulate.a = 0.0
		return
	var label_map = {
		2: "2 HIT COMBO",
		3: "3 HIT COMBO",
		4: "4 HIT COMBO",
		5: "5 HIT COMBO!!",
	}
	_combo_label.text = label_map.get(_combo_count, str(_combo_count) + " HIT COMBO!!")
	# Color escalation
	if _combo_count >= 5:
		_combo_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2, 1))
	elif _combo_count >= 3:
		_combo_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	else:
		_combo_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	# Pop animation
	_combo_label.modulate.a = 1.0
	_combo_label.scale = Vector2(1.25, 1.25)
	var tw = create_tween()
	tw.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
