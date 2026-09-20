extends "res://boxing/main.gd"

func _ready() -> void:
	super._ready()
	call_deferred("capture")

func capture() -> void:
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://boxing/tests/menu.png")
	hud.menu.hide()
	fight.begin()
	await get_tree().create_timer(3).timeout
	brain.set_physics_process(false)
	fight.player.position=Vector3(-.42,0,0)
	fight.enemy.position=Vector3(.42,0,0)
	fight.player.move_input=Vector2.ZERO
	fight.enemy.move_input=Vector2.ZERO
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://boxing/tests/guard.png")
	fight.player.attack("jab")
	await get_tree().create_timer(.20).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://boxing/tests/jab.png")
	await get_tree().create_timer(.5).timeout
	print("VISUAL TEST HP: ",fight.enemy.health," / landed: ",fight.player.landed)
	get_tree().quit()
