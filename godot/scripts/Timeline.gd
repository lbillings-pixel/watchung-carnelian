extends Node
## Chapter registry and time state. Chapters are scripts in res://chapters/ extending Chapter.gd.

signal chapter_changed(index: int)
signal t_changed(t: float)

const MANUAL_SPEED := 0.04   # scrubber units per second when the user presses Play (25 s per chapter);
                             # under the guided tour Tour.gd sets play_speed per beat from the narration length

var chapters: Array = []    # Array[Chapter]
var current := -1
var t := 0.0
var main: Node
var playing := false
var play_speed := MANUAL_SPEED


func register(ch) -> void:
	ch.index = chapters.size()
	chapters.append(ch)


func go_to_chapter(i: int, animate := true) -> void:
	if i < 0 or i >= chapters.size():
		return
	if current >= 0 and current != i:
		chapters[current].exit(main)
	var changed := current != i
	current = i
	t = 0.0
	playing = false
	Glossary.reset_chapter()
	# structural state the chapter expects (flat depositional stack for 2-5, tilted elsewhere)
	if chapters[i].uses_flat_stack:
		main.volumes.set_tilted(false)
	elif chapters[i].id != "erosion":
		main.volumes.set_tilted(true)
	chapters[i].enter(main, animate and changed)
	chapters[i].set_t(0.0, main)
	chapter_changed.emit(i)
	t_changed.emit(t)


func chapter_index(id: String) -> int:
	for k in chapters.size():
		if chapters[k].id == id:
			return k
	return -1


func set_t(v: float) -> void:
	t = clampf(v, 0.0, 1.0)
	if current >= 0:
		chapters[current].set_t(t, main)
	t_changed.emit(t)


func _process(dt: float) -> void:
	if playing and current >= 0:
		var nt: float = t + dt * play_speed * chapters[current].play_rate
		if nt >= 1.0:
			nt = 1.0
			playing = false
		set_t(nt)


func current_chapter():
	return chapters[current] if current >= 0 else null


## Years before present for the global strip (log scale between 1e4 and 1.5e9, linear below 1e4).
static func strip_x(years_ago: float) -> float:
	# maps 1.5e9 -> 0, 1e4 -> ~0.93, 0 -> 1
	var lo := log(1.0e4)
	var hi := log(1.5e9)
	if years_ago <= 1.0e4:
		return 0.93 + 0.07 * (1.0 - years_ago / 1.0e4)
	return 0.93 * (1.0 - (log(years_ago) - lo) / (hi - lo))
