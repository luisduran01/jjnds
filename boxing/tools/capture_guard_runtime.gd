extends "res://boxing/main.gd"
func _ready() -> void:
	super._ready()
	call_deferred("capture")
func capture() -> void:
	hud.menu.hide()
	fight.begin()
	brain.set_physics_process(false)
	fight.player.is_player = false
	fight.enemy.is_player = false
	fight.player.position = Vector3(-.5,0,0)
	fight.enemy.position = Vector3(.5,0,0)
	fight.player.move_input = Vector2.ZERO
	fight.enemy.move_input = Vector2.ZERO
	fight.player.set_state(fight.player.State.IDLE)
	fight.enemy.set_state(fight.enemy.State.IDLE)
	await get_tree().create_timer(.75).timeout
	await RenderingServer.frame_post_draw
	var suffix = "before" if OS.get_cmdline_user_args().has("--before") else "after"
	get_viewport().get_texture().get_image().save_png("res://boxing/tests/guard_runtime_"+suffix+".png")
	print("GUARD RUNTIME CAPTURE ",suffix)
	get_tree().quit()
