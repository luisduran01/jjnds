extends Control

var fight
var brain
var debug=false
var menu: PanelContainer
var results: PanelContainer
var result_label: Label
var pause_panel: PanelContainer
var font: Font
var status=""

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font
	menu=panel(Vector2(510,570))
	var list=VBoxContainer.new()
	list.add_theme_constant_override("separation",13)
	menu.add_child(list)
	label(list,"CORNER CLUB",34,Color("f0c47a"))
	label(list,"EXHIBICIÓN  /  BOXEO 3D",13,Color("93a4b5"))
	label(list,"ALONSO  vs  VEGA",25,Color.WHITE)
	var style=OptionButton.new()
	for name in brain.STYLES: style.add_item(name)
	style.select(1)
	style.item_selected.connect(func(i): brain.style=style.get_item_text(i))
	row(list,"ESTILO DEL RIVAL",style)
	var rounds=OptionButton.new()
	for number in [3,6,8,10,12]: rounds.add_item(str(number))
	rounds.item_selected.connect(func(i): fight.rounds_choice=rounds.get_item_text(i))
	row(list,"ROUNDS",rounds)
	var duration=SpinBox.new()
	duration.min_value=15
	duration.max_value=180
	duration.step=15
	duration.value=120
	duration.suffix=" s"
	duration.value_changed.connect(func(v): fight.round_time=v)
	row(list,"TIEMPO POR ROUND",duration)
	var rest=SpinBox.new()
	rest.min_value=3
	rest.max_value=60
	rest.value=15
	rest.suffix=" s"
	rest.value_changed.connect(func(v): fight.rest_time=v)
	row(list,"DESCANSO",rest)
	var rule=CheckButton.new()
	rule.button_pressed=true
	rule.toggled.connect(func(on): fight.three_knockdown_rule=on)
	row(list,"TKO POR 3 CAÍDAS",rule)
	label(list,"WASD  Pasos   ·   Click izq./der. o J/K  Jab/Cross\nU/I  Hooks   ·   O/L  Uppercuts   ·   Ctrl  Cuerpo\nShift  Guardia   ·   Q/E  Slips   ·   Espacio  Duck\nC  Weave   ·   Z/X  Pivotes   ·   F3  Debug\nEsc  Pausa   ·   Mando: stick / X,Y,A,B / LB,RB",14,Color("b5c4d0"))
	var start=Button.new()
	start.text="ENTRAR AL RING"
	start.custom_minimum_size.y=48
	start.pressed.connect(func(): menu.hide(); fight.begin(); fight.sound.play("menu"))
	list.add_child(start)
	start.grab_focus()
	results=panel(Vector2(520,350))
	results.hide()
	var result_box=VBoxContainer.new()
	result_box.add_theme_constant_override("separation",22)
	results.add_child(result_box)
	result_label=label(result_box,"",24,Color("f0c47a"))
	var rematch=Button.new()
	rematch.text="REVANCHA  /  R"
	rematch.pressed.connect(func(): get_tree().paused=false; get_tree().reload_current_scene())
	result_box.add_child(rematch)
	fight.result_ready.connect(show_result)
	pause_panel=panel(Vector2(400,190))
	pause_panel.hide()
	var pause_box=VBoxContainer.new()
	pause_panel.add_child(pause_box)
	label(pause_box,"PAUSA",32,Color("f0c47a"))
	var resume=Button.new()
	resume.text="CONTINUAR  /  ESC"
	resume.pressed.connect(toggle_pause)
	pause_box.add_child(resume)

func panel(dimensions: Vector2) -> PanelContainer:
	var p=PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left=-dimensions.x/2
	p.offset_right=dimensions.x/2
	p.offset_top=-dimensions.y/2
	p.offset_bottom=dimensions.y/2
	var style=StyleBoxFlat.new()
	style.bg_color=Color(.035,.055,.085,.97)
	style.border_color=Color("a78854")
	style.set_border_width_all(1)
	style.content_margin_left=28
	style.content_margin_right=28
	style.content_margin_top=24
	style.content_margin_bottom=24
	p.add_theme_stylebox_override("panel",style)
	add_child(p)
	return p

func label(parent: Node,text: String,size: int,color: Color) -> Label:
	var item=Label.new()
	item.text=text
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item

func row(parent: Node,text: String,widget: Control) -> void:
	var line=HBoxContainer.new()
	parent.add_child(line)
	var title=label(line,text,13,Color("b5c4d0"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	widget.custom_minimum_size.x=170
	line.add_child(widget)

func show_result(text: String) -> void:
	var p=fight.player
	var e=fight.enemy
	result_label.text=text+"\n\nImpactos: %d / %d    —    %d / %d\nCaídas: %d    —    %d"%[p.landed,p.thrown,e.landed,e.thrown,p.knockdowns,e.knockdowns]
	for card in fight.scorecards:
		result_label.text+="\nRound %d:  %d — %d"%[card.round,card.player,card.enemy]
	results.show()

func toggle_pause() -> void:
	get_tree().paused=!get_tree().paused
	pause_panel.visible=get_tree().paused

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("box_pause") and not menu.visible: toggle_pause()

func _process(_delta: float) -> void:
	queue_redraw()

func text_at(at: Vector2,text: String,size: int=16,color: Color=Color.WHITE) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func bar(at: Vector2,width: float,value: float,color: Color,height: float=7) -> void:
	draw_rect(Rect2(at,Vector2(width,height)),Color(.2,.25,.29,.8))
	draw_rect(Rect2(at,Vector2(width*clampf(value/100,0,1),height)),color)

func _draw() -> void:
	if not fight or not font: return
	var viewport=get_viewport_rect().size
	var scale_factor=viewport.x/1280.0
	var h=viewport.y/scale_factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	draw_rect(Rect2(0,0,1280,58),Color(.025,.04,.065,.85))
	text_at(Vector2(30,35),"CC / CORNER CLUB",19,Color("edc27e"))
	text_at(Vector2(980,34),"EXHIBICIÓN   •   EN VIVO",14,Color("b7c7d4"))
	for side in 2:
		var fighter=fight.player if side==0 else fight.enemy
		var x=30.0 if side==0 else 864.0
		var color=Color("e85a48") if side==0 else Color("62acd8")
		draw_rect(Rect2(x,h-144,386,119),Color(.025,.04,.065,.91))
		draw_rect(Rect2(x,h-144,4,119),color)
		text_at(Vector2(x+18,h-114),fighter.boxer_name,23)
		text_at(Vector2(x+260,h-116),"%d / %d"%[fighter.landed,fighter.thrown],13,Color("a8b6c6"))
		bar(Vector2(x+18,h-101),350,fighter.health,color,9)
		text_at(Vector2(x+18,h-71),"STAMINA",10,Color("9cacb8"))
		bar(Vector2(x+89,h-79),279,fighter.stamina,Color("ddc781"))
		text_at(Vector2(x+18,h-43),"CABEZA",10,Color("9cacb8"))
		bar(Vector2(x+75,h-50),91,100-fighter.head_damage,Color("a7bfc4"),5)
		text_at(Vector2(x+191,h-43),"CUERPO",10,Color("9cacb8"))
		bar(Vector2(x+248,h-50),120,100-fighter.body_damage,Color("a7bfc4"),5)
	draw_rect(Rect2(540,h-125,200,100),Color(.025,.04,.065,.94))
	text_at(Vector2(576,h-100),"ROUND %d / %s"%[fight.round_number,fight.rounds_choice],14,Color("edc27e"))
	var seconds=int(ceil(fight.phase_time if fight.phase==fight.Phase.REST else fight.remaining))
	text_at(Vector2(587,h-56),"%d:%02d"%[seconds/60,seconds%60],36)
	if fight.banner!="" and not menu.visible and not results.visible:
		var width=font.get_string_size(fight.banner,HORIZONTAL_ALIGNMENT_LEFT,-1,42).x
		text_at(Vector2((1280-width)/2,145),fight.banner,42,Color("f5d49d"))
		width=font.get_string_size(fight.subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		text_at(Vector2((1280-width)/2,174),fight.subtitle,16)
	text_at(Vector2(450,h-10),"WASD  MOVER    SHIFT  GUARDIA    CTRL  CUERPO    ESC  PAUSA",11,Color("a1b1bc"))
	if debug:
		var p=fight.player
		var e=fight.enemy
		draw_rect(Rect2(20,75,420,160),Color(0,0,0,.8))
		text_at(Vector2(32,99),"DEBUG   FPS: %d   DIST: %.2f m"%[Engine.get_frames_per_second(),p.position.distance_to(e.position)],14)
		text_at(Vector2(32,124),"PLAYER: %s / %s"%[p.State.keys()[p.state],p.current_punch],14)
		text_at(Vector2(32,149),"AI: %s / %s"%[brain.Strategy.keys()[brain.strategy],brain.style],14)
		text_at(Vector2(32,174),"HP %.1f   STA %.1f   GUARD %.1f"%[p.health,p.stamina,p.guard],14)
		text_at(Vector2(32,199),"STUN %.1f   KD %.1f   PHASE %s"%[p.stun,p.knockdown_meter,fight.Phase.keys()[fight.phase]],14)
