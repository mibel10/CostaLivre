extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# The live Costa Livre world stays visible behind this CS-style menu overlay.
	draw_rect(Rect2(0,0,1280,720),Color(0.015,0.025,0.035,0.24))
	for row in 90:
		var alpha := 0.72 * (1.0 - float(row) / 90.0)
		draw_rect(Rect2(0,360+row*4,1280,5),Color(0.015,0.035,0.045,alpha))
	draw_rect(Rect2(0,0,550,720),Color(0.01,0.025,0.035,0.45))
	draw_rect(Rect2(625,0,655,720),Color(0.015,0.035,0.05,0.76))
	draw_rect(Rect2(625,0,3,720),Color("e3a64d",0.9))
