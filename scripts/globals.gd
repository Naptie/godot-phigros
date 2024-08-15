extends Node

const BASE_WIDTH := 1920.0
const BASE_HEIGHT := 1080.0
const EPS := 1e-4

var note_size := 0.25
var is_autoplay := true
var bg_darkness := 0.5
var judge_radius := 300
var flick_velocity := 300
var finger_lock := false
var perfect := 80
var good := 160
var bad := 180


func is_in_screen(position: Vector2):
	return is_in_area(position, Vector2(-BASE_WIDTH / 2, -BASE_HEIGHT / 2), Vector2(BASE_WIDTH / 2, BASE_HEIGHT / 2))


func is_in_area(position: Vector2, top_left: Vector2, bottom_right: Vector2):
	return position.x >= top_left.x - EPS and position.x <= bottom_right.x + EPS \
	and position.y >= top_left.y - EPS and position.y <= bottom_right.y + EPS


func ct(time_in_seconds: float, bpm: float) -> float:
	return time_in_seconds * bpm * 32 / 60


func cs(chart_time: float, bpm: float) -> float:
	return chart_time * 60 / bpm / 32


func is_in(value: float, min: float, max: float):
	return value >= min and value <= max
