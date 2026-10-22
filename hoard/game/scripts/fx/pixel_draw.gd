class_name PixelDraw
## Lines and circles made of 1px rects, so they sit on the 480x270 grid like the
## pixel art does. draw_line/draw_arc/draw_circle render at window resolution under
## canvas_items stretch and look smooth and blurry next to the sprites.
##   func _draw(): PixelDraw.line(self, a, b, Palette.GLOW); PixelDraw.ring(self, c, 6, Palette.CREAM)


## Bresenham line from a to b (rounded to whole pixels), `width` px thick.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 1) -> void:
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var w := Vector2(width, width)
	var half := Vector2(width / 2, width / 2)
	while true:
		ci.draw_rect(Rect2(Vector2(x0, y0) - half, w), color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## The points of a midpoint circle of radius r (one per octant step).
static func circle_points(r: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if r <= 0:
		pts.append(Vector2.ZERO)
		return pts
	var x := r
	var y := 0
	var err := 1 - r
	while x >= y:
		for p: Vector2 in [Vector2(x, y), Vector2(y, x), Vector2(-y, x), Vector2(-x, y), Vector2(-x, -y), Vector2(-y, -x), Vector2(y, -x), Vector2(x, -y)]:
			pts.append(p)
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1
	return pts


## A 1px ring (midpoint circle) of radius r around c.
static func ring(ci: CanvasItem, c: Vector2, r: int, color: Color) -> void:
	var o := c.round()
	for p in circle_points(r):
		ci.draw_rect(Rect2(o + p, Vector2.ONE), color)


## A filled pixel disc of radius r around c (horizontal spans).
static func disc(ci: CanvasItem, c: Vector2, r: int, color: Color) -> void:
	var o := c.round()
	for y in range(-r, r + 1):
		var half := floori(sqrt(float(r * r - y * y)) + 0.5)
		ci.draw_rect(Rect2(o + Vector2(-half, y), Vector2(half * 2 + 1, 1)), color)


## A filled pixel ellipse (rx, ry) around c, for shadows and pools.
static func ellipse(ci: CanvasItem, c: Vector2, rx: int, ry: int, color: Color) -> void:
	var o := c.round()
	for y in range(-ry, ry + 1):
		var t := float(y) / maxf(1.0, float(ry))
		var half := floori(rx * sqrt(maxf(0.0, 1.0 - t * t)) + 0.25)
		ci.draw_rect(Rect2(o + Vector2(-half, y), Vector2(half * 2 + 1, 1)), color)


## A pixel arc of radius r from angle a0 to a1 (radians), stepping one pixel at a time.
static func arc(ci: CanvasItem, c: Vector2, r: int, a0: float, a1: float, color: Color) -> void:
	var o := c.round()
	var steps := maxi(4, ceili(absf(a1 - a0) * r * 1.2))
	var last := Vector2(INF, INF)
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		var p := (o + Vector2(cos(a), sin(a)) * r).round()
		if p != last:
			ci.draw_rect(Rect2(p, Vector2.ONE), color)
			last = p
