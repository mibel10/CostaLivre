extends CanvasLayer

var world: Node3D
var badge: Label
var next_update := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size",16)
	badge.add_theme_color_override("font_color",Color("a8f0b5"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02,0.05,0.07,0.9)
	background.content_margin_left = 7
	background.content_margin_right = 7
	background.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("normal",background)
	add_child(badge)
	get_viewport().size_changed.connect(refresh)
	refresh()

func refresh() -> void:
	badge.visible = world.settings.fps_corner >= 0
	badge.text = "%d FPS" % Engine.get_frames_per_second()
	var corner: int = world.settings.fps_corner
	var bounds := get_viewport().get_visible_rect().size
	badge.position = Vector2(bounds.x-100 if corner in [1,3] else 5, bounds.y-25 if corner in [2,3] else 0)

func _process(_delta: float) -> void:
	if world.settings.fps_corner < 0:
		return
	var now := Time.get_ticks_msec()
	if now >= next_update:
		next_update = now + 250
		refresh()
