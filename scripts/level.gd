extends Node2D

const JUDGELINE_SCENE := "res://scenes/judgeline.tscn"
const HIT_EFFECTS_SCENE := "res://scenes/hit_effects.tscn"
const HIT_SOUND_SCENE := "res://scenes/hit_sound.tscn"
const TAP_HIT = "res://assets/game/tap.wav"
const DRAG_HIT = "res://assets/game/drag.wav"
const FLICK_HIT = "res://assets/game/flick.wav"
const PERFECT := Color8(255, 255, 180)
const GOOD := Color8(179, 236, 255)
const WHITE := Color8(255, 255, 255)
const NotePart = preload("res://scripts/note_part.gd")

@onready var music = $Music
@onready var background_temp = $VerticalBlurLayer/SubViewport/HorizontalBlurLayer
@onready var background = $Background
@onready var pause_screen = $PauseScreen

var path: String
var level: String
var notes: Array[Node]
var note_count: int
var offset := 0

var time_in_seconds: float
var bpm: float
var judgelines: Array[Node]
var hit_effects_pool: Array[Node]
var hit_sound_pool: Array[Node]
var fc_ap_status := 2
var color := PERFECT
var score := 0
var accuracy := 1.
var max_combo := 0
var combo := 0
var perfect := 0
var good := 0
var bad := 0
var miss := 0

var fingers := {}
var finger_resistance := {}


func _ready():
	var chart = path + "/" + "Chart_" + level + ".json"
	var song = path + "/" + "music.ogg"
	var illustration = path + "/" + "Illustration.png"
	background_temp.texture = load(illustration)
	$VerticalBlurLayer.material.set("shader_parameter/darkness", Globals.bg_darkness)
	music.stream = load(song)
	load_chart(chart)
	preprocess()
	for judgeline in judgelines:
		add_child(judgeline)
	music.play()


func _process(delta):
	$FPS.text = "FPS: " + str(int(1 / delta))
	$Combo.text = str(combo)
	$Score.text = "%07d" % score
	$Accuracy.text = "AUTOPLAY" if Globals.is_autoplay else ("%.2f" % (roundf(accuracy * 1e4) / 1e2) + "%")
	if music.playing:
		time_in_seconds = music.get_playback_position() - offset / 1000
		#if time_in_seconds > 1 and $VerticalBlurLayer.visible:
			#background.texture = ImageTexture.create_from_image($VerticalBlurLayer.texture.get_image())
			#$VerticalBlurLayer.visible = false
		for judgeline in judgelines:
			judgeline.draw(time_in_seconds, delta)
		for judgeline in judgelines:
			judgeline.texture.self_modulate.r = color.r
			judgeline.texture.self_modulate.g = color.g
			judgeline.texture.self_modulate.b = color.b
			judgeline.label.self_modulate = judgeline.texture.self_modulate
		for i in fingers:
			handle_drag(fingers[i])
			handle_flick(fingers[i])


func load_chart(file_name):
	var content = FileAccess.get_file_as_string(file_name)
	var data = JSON.parse_string(content)
	offset = data["offset"]
	bpm = data["judgeLineList"][0]["bpm"]
	var scene = load(JUDGELINE_SCENE)
	var index = 0
	for judgeline_data in data["judgeLineList"]:
		print("Loading Line #" + str(index))
		var judgeline = scene.instantiate()
		judgeline.data = judgeline_data
		var temp_bpm = data["judgeLineList"][index]["bpm"]
		judgeline.total_time = Globals.ct(music.stream.get_length(), temp_bpm)
		judgeline.load_judgeline(index)
		judgelines.append(judgeline)
		index += 1


func preprocess():
	var temp_notes: Array[Node]
	for judgeline in judgelines:
		temp_notes.append_array(judgeline.notes_above)
		temp_notes.append_array(judgeline.notes_below)
	temp_notes.sort_custom(func (a, b): return a.note.time < b.note.time)
	var simultaneous_moments: Array[int]
	var last_moment := -1
	var hit_effects_scene = load(HIT_EFFECTS_SCENE)
	var hit_sound_scene = load(HIT_SOUND_SCENE)
	for note in temp_notes:
		hit_effects_pool.push_back(hit_effects_scene.instantiate())
		hit_sound_pool.push_back(hit_sound_scene.instantiate())
		if note.note.type == note.NoteType.HOLD and !note.hold_head:
			continue
		notes.push_back(note)
		note_count += 1
		if note.hold_head:
			for i in note.note.hold_time / 16:
				hit_effects_pool.push_back(hit_effects_scene.instantiate())
		if note.note.time == last_moment:
			simultaneous_moments.append(note.note.time)
		else:
			last_moment = note.note.time
	var index = 0
	for judgeline in judgelines:
		judgeline.implement_simultaneous_hints(simultaneous_moments)
		index += 1


func judge(type):
	match type:
		NotePart.JudgeType.PERFECT:
			perfect += 1
			combo += 1
		NotePart.JudgeType.GOOD:
			good += 1
			combo += 1
		NotePart.JudgeType.BAD:
			bad += 1
			combo = 0
		NotePart.JudgeType.MISS:
			miss += 1
			combo = 0
	max_combo = max(max_combo, combo)
	if type == NotePart.JudgeType.GOOD:
		fc_ap_status = min(fc_ap_status, 1)
	elif type != NotePart.JudgeType.PERFECT:
		fc_ap_status = min(fc_ap_status, 0)
	match fc_ap_status:
		2:
			color = PERFECT
		1:
			color = GOOD
		0:
			color = WHITE
	calculate_score()
	calculate_accuracy()


func calculate_score():
	if note_count == 0:
		score = 1_000_000
	score = roundi((9e5 * perfect + 585e3 * good + 1e5 * max_combo) / note_count)


func calculate_accuracy():
	if note_count == 0:
		accuracy = 1.
	accuracy = (perfect + 0.65 * good) / (perfect + good + bad + miss)


func home():
	var homepage = load("res://scenes/homepage.tscn").instantiate()
	queue_free()
	get_tree().root.add_child(homepage)


func _on_judge(type, note, position, counted, hidden, muted):
	print("Judge " + NotePart.JudgeType.keys()[type] + " from " + NotePart.NoteType.keys()[note.note.type - 1] + " received at (" + str(int(position.x)) + ", " + str(int(position.y)) + ")")
	if counted:
		judge(type)
	if !muted and (type == NotePart.JudgeType.PERFECT or type == NotePart.JudgeType.GOOD):
		var hit_sound = hit_sound_pool.pop_front()
		match note.note.type:
			NotePart.NoteType.TAP:
				hit_sound.stream = load(TAP_HIT)
			NotePart.NoteType.HOLD:
				hit_sound.stream = load(TAP_HIT)
			NotePart.NoteType.DRAG:
				hit_sound.stream = load(DRAG_HIT)
			NotePart.NoteType.FLICK:
				hit_sound.stream = load(FLICK_HIT)
		hit_sound.position = position if Globals.is_in_screen(position) else Vector2(clampf(position.x, -Globals.BASE_WIDTH / 2, Globals.BASE_WIDTH / 2), 0)
		add_child(hit_sound)
		hit_sound.play()
	if !hidden:
		if type == NotePart.JudgeType.PERFECT or type == NotePart.JudgeType.GOOD:
			var hit_effects = hit_effects_pool.pop_front()
			hit_effects.position = position
			match type:
				NotePart.JudgeType.PERFECT:
					hit_effects.modulate = PERFECT
				NotePart.JudgeType.GOOD:
					hit_effects.modulate = GOOD
			add_child(hit_effects)
		elif type == NotePart.JudgeType.BAD:
			note.modulate = Color(1, 0, 0)
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(note, "modulate:a", 0, 0.5).set_ease(Tween.EASE_IN)


func _on_music_finished():
	home()


func _on_pause_pressed():
	music.stream_paused = true
	pause_screen.visible = true


func _on_homepage_pressed():
	home()


func _on_resume_pressed():
	pause_screen.visible = false
	music.stream_paused = false


func _unhandled_input(event):
	if !(event is InputEventFromWindow):
		return
	event.position -= Vector2(Globals.BASE_WIDTH, Globals.BASE_HEIGHT) / 2
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event
			handle_touch(event)
		else:
			fingers.erase(event.index)
			finger_resistance.erase(event.index)
		print(fingers)
	elif event is InputEventScreenDrag:
		if fingers.has(event.index):
			fingers[event.index] = event
		print(fingers)


func handle_touch(event):
	if Globals.is_autoplay:
		return
	var nearby_notes = notes.filter(func (note):
		#if Globals.is_in_screen(note.global_position):
			#print(str(event.position) + " -> " + str(note.global_position) + ": " + str(int(note.global_position.distance_to(event.position))))
			#print(time_in_seconds - Globals.cs(note.note.time, note.bpm))
		return note.judge == note.JudgeType.UNJUDGED and (note.note.type == note.NoteType.TAP or note.NoteType.DRAG or note.hold_head) \
		and judge_distance(event.position, note) <= Globals.judge_radius and Globals.is_in((time_in_seconds - Globals.cs(note.note.time, note.bpm)) * 1e3, -Globals.bad, Globals.good))
	print("Nearby Notes: " + str(nearby_notes.size()))
	if nearby_notes.size() == 0:
		return
	#for note in nearby_notes:
		#note.modulate.r = 0
		#var thread = Thread.new()
		#thread.start(func ():
			#await get_tree().create_timer(0.3).timeout
			#if note:
				#note.modulate.r = 1
		#)
	var nearest_note = nearby_notes.filter(func (note): return note.note.type != note.NoteType.DRAG).reduce(func(accum, cur):
		return cur if space_time_distance_sq(event.position, cur, time_in_seconds) < space_time_distance_sq(event.position, accum, time_in_seconds) else accum
	)
	if !nearest_note:
		return
	nearest_note.handle_input(time_in_seconds, event)


func handle_drag(event):
	if Globals.is_autoplay:
		return
	var nearby_notes = notes.filter(func (note):
		#if Globals.is_in_screen(note.global_position):
			#print(str(event.position) + " -> " + str(note.global_position) + ": " + str(int(note.global_position.distance_to(event.position))))
			#print(time_in_seconds - Globals.cs(note.note.time, note.bpm))
		return note.judge == note.JudgeType.UNJUDGED and (note.note.type == note.NoteType.DRAG) \
		and judge_distance(event.position, note) <= Globals.judge_radius and Globals.is_in((time_in_seconds - Globals.cs(note.note.time, note.bpm)) * 1e3, -Globals.good, Globals.good))
	print("Nearby Drags: " + str(nearby_notes.size()))
	if nearby_notes.size() == 0:
		return
	#for note in nearby_notes:
		#note.modulate.g = 0
		#var thread = Thread.new()
		#thread.start(func ():
			#await get_tree().create_timer(0.3).timeout
			#if note:
				#note.modulate.g = 1
		#)
	var nearest_note = nearby_notes.reduce(func(accum, cur):
		return cur if space_time_distance_sq(event.position, cur, time_in_seconds) < space_time_distance_sq(event.position, accum, time_in_seconds) else accum
	)
	nearest_note.handle_input(time_in_seconds, event)


func handle_flick(event):
	if Globals.is_autoplay or !(event is InputEventScreenDrag):
		return
	var velocity = event.velocity if !finger_resistance.has(event.index) else apply_resistance(event.velocity, finger_resistance[event.index])
	if velocity.length() < Globals.flick_velocity:
		return
	var nearby_notes = notes.filter(func (note):
		#if Globals.is_in_screen(note.global_position):
			#print(str(event.position) + " -> " + str(note.global_position) + ": " + str(int(note.global_position.distance_to(event.position))))
			#print(time_in_seconds - Globals.cs(note.note.time, note.bpm))
		return note.judge == note.JudgeType.UNJUDGED and (note.note.type == note.NoteType.FLICK) \
		and judge_distance(event.position, note) <= Globals.judge_radius and Globals.is_in((time_in_seconds - Globals.cs(note.note.time, note.bpm)) * 1e3, -Globals.good, Globals.good))
	print("Nearby Flicks: " + str(nearby_notes.size()))
	if nearby_notes.size() == 0:
		return
	#for note in nearby_notes:
		#note.modulate.b = 0
		#var thread = Thread.new()
		#thread.start(func ():
			#await get_tree().create_timer(0.3).timeout
			#if note:
				#note.modulate.b = 1
		#)
	var nearest_note = nearby_notes.reduce(func(accum, cur):
		return cur if space_time_distance_sq(event.position, cur, time_in_seconds) < space_time_distance_sq(event.position, accum, time_in_seconds) else accum
	)
	nearest_note.handle_input(time_in_seconds, event)
	finger_resistance[event.index] = event.velocity.angle()


func apply_resistance(vector: Vector2, angle: float) -> Vector2:
	return vector * max(abs(vector.angle() - angle) / (PI / 2), 1)


func judge_distance(position: Vector2, note: Node):
	var position_delta = position - note.judgeline.position
	return abs(position.x * cos(note.judgeline.rotation) + position.y * sin(note.judgeline.rotation) - note.position.x)


func space_time_distance_sq(position: Vector2, note: Node, time_in_seconds: float):
	var time_delta = time_in_seconds - Globals.cs(note.note.time, note.bpm)
	return judge_distance(position, note) ** 2 + time_delta ** 2
