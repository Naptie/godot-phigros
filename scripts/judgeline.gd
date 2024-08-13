extends Node2D

const NOTE_SCENE := "res://scenes/note_part.tscn"
const NotePart = preload("res://scripts/note_part.gd")

class Event:
	var start_time: float
	var end_time: float
	
class SpeedEvent extends Event:
	var value: float

class DurationalEvent extends Event:
	var start: float
	var end: float

class DurationalVectorEvent extends Event:
	var start: float
	var end: float
	var start2: float
	var end2: float

class HoldGroup:
	var head: Node
	var body: Node
	var tail: Node


var notes_above: Array[Node]
var notes_below: Array[Node]
var speed_events: Array[SpeedEvent]
var move_events: Array[DurationalVectorEvent]
var rotate_events: Array[DurationalEvent]
var disappear_events: Array[DurationalEvent]
var bpm: float

var time: float
var current_move := 0
var current_rotate := 0
var current_disappear := 0
var current_speed := 0
var current_height := 0

var data: Dictionary
var line_number: int
var total_time: int
var height_time: Array[float]
var height_time_cache := {}
var height_cache: Array[float]
var hold_groups: Array[HoldGroup]

@onready var texture = $Texture
@onready var label = $Label


func _ready():
	label.text = str(line_number)
	for note in notes_above:
		add_child(note)
	for note in notes_below:
		add_child(note)


func load_judgeline(line_no: int):
	line_number = line_no
	bpm = data["bpm"]
	notes_above = load_notes(data["notesAbove"])
	notes_below = load_notes(data["notesBelow"])
	speed_events = load_speed_events(data["speedEvents"])
	move_events = load_durational_vector_events(data["judgeLineMoveEvents"])
	rotate_events = load_durational_events(data["judgeLineRotateEvents"])
	disappear_events = load_durational_events(data["judgeLineDisappearEvents"])


func draw(time_in_seconds, delta):
	time = Globals.ct(time_in_seconds, bpm)
	handle_moves(time)
	handle_rotations(time)
	handle_opacities(time)
	handle_heights(time)
	handle_notes(time, notes_above, 1)
	handle_notes(time, notes_below, -1)


func handle_moves(time):
	if move_events.size() == 0:
		return
	var event = move_events[current_move]
	var progress = clampf((time - event.start_time) / (event.end_time - event.start_time), 0, 1)
	position.x = Globals.BASE_WIDTH * (progress * (event.end - event.start) + event.start) - Globals.BASE_WIDTH / 2
	position.y = -Globals.BASE_HEIGHT * (progress * (event.end2 - event.start2) + event.start2) + Globals.BASE_HEIGHT / 2
	while time >= move_events[current_move].end_time && current_move < move_events.size() - 1:
		current_move += 1


func handle_rotations(time):
	if rotate_events.size() == 0:
		return
	var event = rotate_events[current_rotate]
	var progress = clampf((time - event.start_time) / (event.end_time - event.start_time), 0, 1)
	rotation_degrees = -(progress * (event.end - event.start) + event.start)
	while time >= rotate_events[current_rotate].end_time && current_rotate < rotate_events.size() - 1:
		current_rotate += 1


func handle_opacities(time):
	if disappear_events.size() == 0:
		return
	var event = disappear_events[current_disappear]
	var progress = clampf((time - event.start_time) / (event.end_time - event.start_time), 0, 1)
	texture.self_modulate.a = progress * (event.end - event.start) + event.start
	while time >= disappear_events[current_disappear].end_time && current_disappear < disappear_events.size() - 1:
		current_disappear += 1


func handle_notes(time, notes, modifier: int):
	for note in notes:
		if (!note.visible or note.modulate.a == 0 or note.scale.y == 0) and note.judge != note.JudgeType.UNJUDGED and note.note.time + note.note.hold_time < time - 16:
			notes.erase(note)
			$"..".notes.erase(note)
			note.queue_free()
			continue
		if note.note.time < time + Globals.EPS:
			if note.note.type != note.NoteType.HOLD or note.hold_head or note.note.time + note.note.hold_time <= time:
				if Globals.is_autoplay:
					note.autoplay(time)
				else:
					var delta = 1e3 * Globals.cs(time - note.note.time, bpm)
					note.modulate.a = max(0, 1 - delta / Globals.good) if note.note.type != note.NoteType.HOLD else 0
					if delta > Globals.good and note.judge == note.JudgeType.UNJUDGED:
						note.miss()
		if (note.note.time > time or !note.hold_head) and note.judge != note.JudgeType.BAD:
			if note.note.type != note.NoteType.HOLD or note.hold_head or note.hold_tail:
				note.scale = Vector2.ONE * Globals.note_size * modifier
				if note.judge == note.JudgeType.UNJUDGED:
					note.visible = note.position.y / modifier <= 0 or note.note.time < time + Globals.EPS
				if note.hold_head:
					note.position.y = -calculate_distance(time, note.note.time) * modifier
				elif note.hold_tail:
					note.position.y = -calculate_distance(time, note.note.time + note.note.hold_time) * modifier
				else:
					note.position.y = -calculate_distance(time, note.note.time) * modifier * note.note.speed
			else:
				var start_height = -calculate_distance(time, max(note.note.time, time)) * modifier
				var end_height = -calculate_distance(time, note.note.time + note.note.hold_time) * modifier
				if start_height / modifier > 0:
					start_height = 0
				if end_height / modifier > 0:
					end_height = 0
				note.scale.x = Globals.note_size * modifier
				note.scale.y = (start_height - end_height) / 1900
				note.position.y = (start_height + end_height) / 2


func calculate_distance(time, note_time) -> float:
	if is_equal_approx(time, note_time):
		return 0
	var modifier = 1
	if time > note_time:
		var temp = note_time
		note_time = time
		time = temp
		modifier = -1
	var end_index: int
	if height_time_cache.has(note_time):
		end_index = height_time_cache[note_time]
	else:
		end_index = height_time.bsearch(note_time)
		height_time_cache[note_time] = end_index
	var remainder_end: float
	if end_index >= height_time.size():
		var event = speed_events[height_time.size() - 2]
		remainder_end = (note_time - event.start_time) * event.value
	else:
		remainder_end = (height_cache[end_index] - (height_cache[end_index - 1])) \
		* (note_time - height_time[end_index - 1]) / (height_time[end_index] - height_time[end_index - 1])
	var remainder_start = (height_cache[current_height + 1] - height_cache[current_height]) \
		* (height_time[current_height + 1] - time) / (height_time[current_height + 1] - height_time[current_height])
	var result = Globals.cs(modifier * (remainder_start + remainder_end + height_cache[end_index - 1] - height_cache[current_height + 1]) \
		* 0.6 * Globals.BASE_HEIGHT, bpm)
	return result


func handle_heights(time):
	while current_height < height_time.size() - 1 && time >= height_time[current_height + 1]:
		current_height += 1

# 纯暴力
#func calculate_distance(time, note) -> float:
	#var distance := 0.0
	#for i in speed_events.size() - current_speed:
		#var event = speed_events[i + current_speed]
		#if event.start_time > note.note.time:
			#break
		#var start_time = max(time, event.start_time)
		#var end_time: float
		#if i == speed_events.size() - current_speed - 1:
			#end_time = note.note.time
		#else:
			#end_time = min(note.note.time, speed_events[i + current_speed + 1].start_time)
		#distance += Globals.cs((end_time - start_time) * event.value)
	#if current_speed < speed_events.size() - 1 && time >= speed_events[current_speed + 1].start_time:
		#current_speed += 1
	#return 0.6 * Globals.BASE_HEIGHT * distance * note.note.speed


func load_notes(data) -> Array[Node]:
	var result: Array[Node] = []
	var scene = load(NOTE_SCENE)
	for note_data in data:
		var note_part = scene.instantiate()
		note_part.data = note_data
		note_part.load_data()
		if note_part.note.type == NotePart.NoteType.HOLD:
			var hold_head = scene.instantiate()
			hold_head.data = note_data
			hold_head.hold_head = true
			hold_head.load_data()
			var hold_tail = scene.instantiate()
			hold_tail.data = note_data
			hold_tail.hold_tail = true
			hold_tail.load_data()
			note_part.judge = note_part.JudgeType.UNINVOLVED
			hold_tail.judge = note_part.JudgeType.UNINVOLVED
			hold_head.hold_index = hold_groups.size()
			note_part.hold_index = hold_groups.size()
			hold_tail.hold_index = hold_groups.size()
			var group = HoldGroup.new()
			group.head = hold_head
			group.body = note_part
			group.tail = hold_tail
			hold_groups.push_back(group)
			result.append(hold_head)
			result.append(hold_tail)
		result.append(note_part)
	return result


func load_speed_events(data) -> Array[SpeedEvent]:
	var result: Array[SpeedEvent] = []
	for event_data in data:
		var event = SpeedEvent.new()
		event.start_time = event_data["startTime"]
		event.end_time = event_data["endTime"]
		event.value = event_data["value"]
		result.append(event)
	if result[-1].end_time < total_time:
		result[-1].end_time = total_time
	result.sort_custom(func (a, b): return a.start_time < b.start_time)
	var height := 0
	height_time.append(0)
	height_cache.append(0)
	for event in result:
		height_time.append(event.end_time)
		height += (event.end_time - event.start_time) * event.value
		height_cache.append(height)
	return result


func load_durational_events(data) -> Array[DurationalEvent]:
	var result: Array[DurationalEvent] = []
	for event_data in data:
		var event = DurationalEvent.new()
		event.start_time = event_data["startTime"]
		event.end_time = event_data["endTime"]
		event.start = event_data["start"]
		event.end = event_data["end"]
		result.append(event)
	result.sort_custom(func (a, b): return a.start_time < b.start_time)
	return result


func load_durational_vector_events(data) -> Array[DurationalVectorEvent]:
	var result: Array[DurationalVectorEvent] = []
	for event_data in data:
		var event = DurationalVectorEvent.new()
		event.start_time = event_data["startTime"]
		event.end_time = event_data["endTime"]
		event.start = event_data["start"]
		event.end = event_data["end"]
		event.start2 = event_data["start2"]
		event.end2 = event_data["end2"]
		result.append(event)
	result.sort_custom(func (a, b): return a.start_time < b.start_time)
	return result


func implement_simultaneous_hints(moments: Array[int]):
	for note in notes_above:
		if moments.any(func (element): return element == note.note.time):
			note.is_simultaneous = true
	for note in notes_below:
		if moments.any(func (element): return element == note.note.time):
			note.is_simultaneous = true
