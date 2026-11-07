extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for row in 72:
		var t := float(row)/72
		draw_rect(Rect2(0,row*10,1280,11),Color("26464f").lerp(Color("08161e"),t))
	draw_circle(Vector2(470,250),135,Color("be9561"))
	draw_circle(Vector2(470,250),122,Color("ddad72"))
	for i in 19:
		var height := float(50+(i*67)%180)
		var x := float(i*34)
		draw_rect(Rect2(x,530-height,31,height),Color("152e38"))
		for window in int(height/18):
			draw_rect(Rect2(x+7,535-height+window*18,3,5),Color("a29465"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,550),Vector2(620,490),Vector2(620,720),Vector2(0,720)]),Color("10282e"))
	for i in 8:
		draw_line(Vector2(15+i*73,580+i*8),Vector2(58+i*73,578+i*8),Color("497f80"),2)
	draw_rect(Rect2(625,0,655,720),Color(0.025,0.055,0.08,0.97))
	var card := StyleBoxFlat.new()
	card.bg_color = Color("142c36")
	card.set_corner_radius_all(18)
	draw_style_box(card,Rect2(660,117,520,236))
	draw_style_box(card,Rect2(660,366,520,227))
	draw_line(Vector2(660,117),Vector2(1180,117),Color("85d5b7"),2)
	draw_line(Vector2(660,366),Vector2(1180,366),Color("ffd18a"),2)
