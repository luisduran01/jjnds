extends Node

signal phase_changed(phase)
signal result_ready(text)
enum Phase { PRE_FIGHT, ROUND_START, FIGHTING, KNOCKDOWN, ROUND_END, REST, FIGHT_END }
@export_enum("3","6","8","10","12") var rounds_choice = "3"
@export_range(15,180,5) var round_time=120.0
@export_range(3,60,1) var rest_time=15.0
@export var three_knockdown_rule=true
var phase=Phase.PRE_FIGHT
var round_number=1
var remaining=120.0
var phase_time=0.0
var player
var enemy
var sound
var arena
var camera
var down_fighter
var count=0
var rise_progress=0.0
var scorecards: Array=[]
var total_player=0
var total_enemy=0
var banner="CORNER CLUB"
var subtitle="BOXEO / EXHIBICIÓN"
var result=""

func change(next: Phase,seconds: float=0) -> void:
	phase=next
	phase_time=seconds
	player.fighting=next==Phase.FIGHTING
	enemy.fighting=next==Phase.FIGHTING
	if next!=Phase.FIGHTING:
		for boxer in [player,enemy]:
			boxer.move_input=Vector2.ZERO
			boxer.buffered=""
			boxer.current_punch=""
			if boxer.state not in [boxer.State.KNOCKDOWN,boxer.State.KO,boxer.State.VICTORY,boxer.State.DEFEAT,boxer.State.GET_UP]:
				boxer.set_state(boxer.State.IDLE)
	phase_changed.emit(next)

func begin() -> void:
	if phase!=Phase.PRE_FIGHT: return
	start_round()

func start_round() -> void:
	remaining=round_time
	player.position=Vector3(-1.05,0,0)
	enemy.position=Vector3(1.05,0,0)
	for boxer in [player,enemy]:
		boxer.round_knockdowns=0
		boxer.round_quality=0
		boxer.set_state(boxer.State.IDLE)
	banner="ROUND %d"%round_number
	subtitle="Mantén la distancia. Protege tu guardia."
	change(Phase.ROUND_START,2.4)

func _process(delta: float) -> void:
	if not player: return
	if phase in [Phase.PRE_FIGHT,Phase.FIGHT_END]: return
	phase_time-=delta
	match phase:
		Phase.ROUND_START:
			if phase_time<=0:
				banner="FIGHT"
				subtitle=""
				sound.play("bell")
				change(Phase.FIGHTING,1.0)
		Phase.FIGHTING:
			remaining=maxf(0,remaining-delta)
			if phase_time<=0: banner=""
			if remaining<=0:
				score_round()
				banner="FIN DEL ROUND"
				sound.play("bell")
				arena.excitement=.6
				change(Phase.ROUND_END,2)
		Phase.ROUND_END:
			if phase_time<=0:
				if round_number>=int(rounds_choice): decide_winner()
				else:
					banner="DESCANSO"
					subtitle="Respira. Recupera stamina."
					change(Phase.REST,rest_time)
		Phase.REST:
			player.position=player.position.move_toward(Vector3(-2.6,0,-2.6),delta*1.6)
			enemy.position=enemy.position.move_toward(Vector3(2.6,0,2.6),delta*1.6)
			for boxer in [player,enemy]:
				boxer.stamina=minf(100,boxer.stamina+delta*4)
				boxer.health=minf(100,boxer.health+delta*.24)
			if phase_time<=0:
				round_number+=1
				start_round()
		Phase.KNOCKDOWN:
			update_count(delta)

func on_knockdown(boxer) -> void:
	if phase!=Phase.FIGHTING: return
	down_fighter=boxer
	count=0
	rise_progress=0
	banner="KNOCKDOWN"
	subtitle="Pulsa ESPACIO repetidamente para levantarte" if boxer.is_player else "El árbitro inicia la cuenta"
	arena.excitement=1
	sound.play("knockdown")
	change(Phase.KNOCKDOWN,1.6)
	if three_knockdown_rule and boxer.round_knockdowns>=3:
		finish(boxer.opponent,"TKO · tres caídas en el round")
	elif boxer.head_damage>115 and boxer.knockdowns>=2:
		finish(boxer.opponent,"TKO · detención del árbitro")

func update_count(delta: float) -> void:
	if not down_fighter: return
	var other=down_fighter.opponent
	var corner=Vector3(-2.5,0,2.5) if down_fighter.position.x>0 else Vector3(2.5,0,-2.5)
	other.position=other.position.move_toward(corner,delta*1.3)
	if count==-1:
		if phase_time<=0:
			banner="BOX"
			subtitle=""
			down_fighter=null
			change(Phase.FIGHTING,1)
		return
	if down_fighter.is_player and Input.is_action_just_pressed("box_get_up"):
		rise_progress+=.7
	elif not down_fighter.is_player and down_fighter.health>0:
		rise_progress+=delta*(1.2-down_fighter.knockdowns*.12)
	if phase_time<=0:
		count+=1
		phase_time+=1
		banner=str(count)
		if count>=10:
			down_fighter.set_state(down_fighter.State.KO,0,"ko")
			finish(other,"KO · cuenta de diez")
		elif count>=5 and rise_progress>=3.5+down_fighter.knockdowns*.8 and down_fighter.health>0:
			down_fighter.recover_from_down()
			count=-1
			phase_time=1.8
			banner="EN PIE"
			subtitle="El árbitro verifica que puede continuar"

func score_round() -> void:
	var p=10
	var e=10
	if player.round_quality>enemy.round_quality+1: e=9
	elif enemy.round_quality>player.round_quality+1: p=9
	p=maxi(6,p-player.round_knockdowns)
	e=maxi(6,e-enemy.round_knockdowns)
	total_player+=p
	total_enemy+=e
	scorecards.append({"round":round_number,"player":p,"enemy":e})

func decide_winner() -> void:
	var winner=player if total_player>total_enemy else enemy if total_enemy>total_player else null
	finish(winner,"DECISIÓN · %d — %d"%[total_player,total_enemy])

func finish(winner,method: String) -> void:
	if phase==Phase.FIGHT_END: return
	change(Phase.FIGHT_END)
	banner=winner.boxer_name+" GANA" if winner else "EMPATE"
	subtitle=method
	result=banner+"\n"+method
	for boxer in [player,enemy]:
		if boxer==winner: boxer.set_state(boxer.State.VICTORY,0,"victory")
		elif boxer.state not in [boxer.State.KNOCKDOWN,boxer.State.KO]: boxer.set_state(boxer.State.DEFEAT,0,"defeat")
	arena.excitement=1
	sound.play("ko")
	result_ready.emit(result)

func on_hit(attacker,victim,info: Dictionary) -> void:
	camera.shake=minf(.075,info.damage*.004)
	arena.excitement=minf(1,arena.excitement+info.damage*.03)
	var kind="blocked" if info.blocked else "body" if info.zone=="body" else "hook" if "hook" in info.punch else "uppercut" if "uppercut" in info.punch else info.punch
	sound.play(kind,info.damage/10+.3)
	if info.counter:
		banner="COUNTER"
		phase_time=.55
