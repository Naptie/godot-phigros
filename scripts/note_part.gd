extends Node2D

enum NoteType { TAP = 1, DRAG, HOLD, FLICK }
enum JudgeType { PERFECT, GOOD, BAD, MISS, UNJUDGED, UNINVOLVED }

signal on_judge(judge: JudgeType, note: Node, position: Vector2, counted: bool, hidden: bool, muted: bool)

class Note:
	var type : NoteType
	var time : int
	var position_x : float
	var hold_time : int
	var speed : float
	var floor_position : float


var note: Note
var judge := JudgeType.UNJUDGED
var data: Dictionary
var is_simultaneous := false
var hold_index: int
var hold_head := false
var hold_tail := false
var bpm: float

@onready var level = $"../.."
@onready var judgeline = $".."
@onready var label = $Label


func load_data():
	note = Note.new()
	note.type = int(data["type"])
	note.time = data["time"]
	note.position_x = data["positionX"]
	note.hold_time = data["holdTime"]
	note.speed = data["speed"]
	note.floor_position = data["floorPosition"]


func _ready():
	bpm = judgeline.bpm
	connect("on_judge", level._on_judge)
	position.x = note.position_x * 0.05625 * Globals.BASE_WIDTH
	scale *= Globals.note_size
	match note.type:
		NoteType.TAP:
			if is_simultaneous:
				$TapHL.visible = true
			else:
				$Tap.visible = true
		NoteType.DRAG:
			if is_simultaneous:
				$DragHL.visible = true
			else:
				$Drag.visible = true
		NoteType.FLICK:
			if is_simultaneous:
				$FlickHL.visible = true
			else:
				$Flick.visible = true
		NoteType.HOLD:
			if hold_head:
				if is_simultaneous:
					$HoldHeadHL.visible = true
				else:
					$HoldHead.visible = true
			elif hold_tail:
				$HoldTail.visible = true
			else:
				if is_simultaneous:
					$HoldBodyHL.visible = true
				else:
					$HoldBody.visible = true


func autoplay(time: float):
	if judge != JudgeType.UNJUDGED and judge != JudgeType.UNINVOLVED:
		return
	judge = JudgeType.PERFECT
	visible = false
	if note.type != NoteType.HOLD or hold_head:
		#print("Global: (" + str(global_position.x) + ", " + str(global_position.y) + ", " + str(global_rotation) + "); Relative: (" + str(position.x) + ", " + str(position.y) + ", " + str(rotation) + "); Line: (" + str(judgeline.position.x) + ", " + str(judgeline.position.y) + ", " + str(judgeline.rotation) + ");")
		var judge_position = judgeline.position + Vector2(cos(judgeline.rotation), sin(judgeline.rotation)) * position.x
		if hold_head:
			var hold_end = note.time + note.hold_time
			var head = true
			while judgeline.time < hold_end:
				judge_position = judgeline.position + Vector2(cos(judgeline.rotation), sin(judgeline.rotation)) * position.x
				on_judge.emit(judge, self, judge_position, false, false, !head)
				head = false
				await get_tree().create_timer(30 / bpm).timeout
			on_judge.emit(judge, self, judge_position, true, true, true)
		else:
			on_judge.emit(judge, self, judge_position, true, false, false)


func handle_input(time_in_seconds: float, event: InputEventFromWindow):
	if judge != JudgeType.UNJUDGED and judge != JudgeType.UNINVOLVED:
		return
	var delta = 1e3 * (time_in_seconds - Globals.cs(note.time, bpm))
	if abs(delta) <= Globals.perfect:
		judge = JudgeType.PERFECT
	elif abs(delta) <= Globals.good:
		judge = JudgeType.GOOD if note.type == NoteType.TAP or note.type == NoteType.HOLD else JudgeType.PERFECT
	elif note.type == NoteType.TAP:
		judge = JudgeType.BAD
	else:
		judge = JudgeType.MISS
	#print("Global: (" + str(global_position.x) + ", " + str(global_position.y) + ", " + str(global_rotation) + "); Relative: (" + str(position.x) + ", " + str(position.y) + ", " + str(rotation) + "); Line: (" + str(judgeline.position.x) + ", " + str(judgeline.position.y) + ", " + str(judgeline.rotation) + ");")
	var judge_position = judgeline.position + Vector2(cos(judgeline.rotation), sin(judgeline.rotation)) * position.x
	if hold_head:
		var hold_end = note.time + note.hold_time
		var head = true
		while judgeline.time < hold_end and is_holding(event.index):
			judge_position = judgeline.position + Vector2(cos(judgeline.rotation), sin(judgeline.rotation)) * position.x
			on_judge.emit(judge, self, judge_position, false, false, !head)
			head = false
			await get_tree().create_timer(30 / bpm).timeout
		if judgeline.time < hold_end - 16:
			miss()
		else:
			on_judge.emit(judge, self, judge_position, true, true, true)
	elif note.type == NoteType.TAP:
		if abs(delta) <= Globals.good:
			visible = false
		on_judge.emit(judge, self, judge_position, true, false, false)
	else:
		await get_tree().create_timer(max(-delta / 1e3, 0)).timeout
		visible = false
		on_judge.emit(judge, self, judge_position, true, false, false)


func is_holding(index: int):
	if Globals.finger_lock:
		return level.judge_distance(level.fingers[index].position, self) <= Globals.judge_radius
	else:
		return level.fingers.keys().any(func (i): return level.judge_distance(level.fingers[i].position, self) <= Globals.judge_radius)


func miss():
	if judge != JudgeType.UNJUDGED and !hold_head:
		return
	judge = JudgeType.MISS
	if hold_head:
		var group = judgeline.hold_groups[hold_index]
		group.body.modulate.a = 0.5
		group.tail.modulate.a = 0.5
	visible = false
	#print("Global: (" + str(global_position.x) + ", " + str(global_position.y) + ", " + str(global_rotation) + "); Relative: (" + str(position.x) + ", " + str(position.y) + ", " + str(rotation) + "); Line: (" + str(judgeline.position.x) + ", " + str(judgeline.position.y) + ", " + str(judgeline.rotation) + ");")
	var judge_position = judgeline.position + Vector2(cos(judgeline.rotation), sin(judgeline.rotation)) * position.x
	on_judge.emit(judge, self, judge_position, true, false, false)
