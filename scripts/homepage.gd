extends Node2D

const LEVEL_ROOT := "res://assets/levels"

@onready var item_list = $ItemList
@onready var item_list_2 = $ItemList2
@onready var button = $Button
@onready var difficulty_not_found = $DifficultyNotFound

var levels : Array[String]
var difficulties := ["EZ", "HD", "IN", "AT", "SP"]

func _ready():
	#_on_size_changed()
	#get_tree().root.size_changed.connect(_on_size_changed)
	seek_levels()
	for level in levels:
		item_list.add_item(level)


func seek_levels():
	var dir = DirAccess.open(LEVEL_ROOT)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			levels.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_button_pressed():
	var path = LEVEL_ROOT + "/" + levels[item_list.get_selected_items()[0]]
	var difficulty = difficulties[item_list_2.get_selected_items()[0]] if item_list_2.get_selected_items().size() > 0 else "IN"
	if !FileAccess.file_exists(path + "/" + "Chart_" + difficulty + ".json"):
		difficulty_not_found.modulate.a = 1
		await get_tree().create_timer(2).timeout
		difficulty_not_found.modulate.a = 0
		return
	var level = load("res://scenes/level.tscn").instantiate()
	level.path = path
	level.level = difficulty
	queue_free()
	get_tree().root.add_child(level)


func _on_item_list_item_selected(index):
	button.disabled = false


#func _on_size_changed():
	#var size = DisplayServer.window_get_size()
	#Globals.BASE_HEIGHT = Globals.BASE_WIDTH / size.x * size.y
