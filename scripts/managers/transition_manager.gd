extends CanvasLayer

signal transition_finished

var rect: ColorRect

func _ready() -> void:
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.modulate.a = 0.0

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)
	await tween.finished
	transition_finished.emit()

func fade_out(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	await tween.finished
	transition_finished.emit()

func change_scene(path: String, duration: float = 0.4) -> void:
	await fade_in(duration)
	get_tree().change_scene_to_file(path)
	await fade_out(duration)
