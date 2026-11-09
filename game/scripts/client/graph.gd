class_name PopulationGraph
extends Control
## Paper-organizer population chart (GDD v0.3 section 4). One point per round plus a Start point.
## BUGS = bugs after the hunt, before bug births. LIZARDS = lizards after starvation and births.
## MUTANTS = Stage 4 mutant lizards after births. Each series has its own dash pattern, marker shape
## and text label, so colour is never the only cue. Drawn with _draw() only: no textures, no emoji.

const KEY_BUGS: String = "BUGS"
const KEY_LIZARDS: String = "LIZARDS"
const KEY_MUTANTS: String = "MUTANTS"

const DASH_SOLID: int = 0
const DASH_DASHED: int = 1
const DASH_DOTTED: int = 2

const MARK_CIRCLE: int = 0
const MARK_SQUARE: int = 1
const MARK_TRIANGLE: int = 2

const COL_BG: Color = Color(0.93, 0.95, 0.91, 1)
const COL_INK: Color = Color(0.1, 0.12, 0.1, 1)
const COL_AXIS: Color = Color(0.35, 0.38, 0.35, 1)
const COL_GRID: Color = Color(0.8, 0.82, 0.78, 1)
const COL_BUGS: Color = Color(0.1, 0.45, 0.2, 1)
const COL_LIZARDS: Color = Color(0.45, 0.25, 0.08, 1)
const COL_MUTANTS: Color = Color(0.45, 0.2, 0.6, 1)

const FONT_PX: int = 16
const LINE_W: float = 3.0
const MARKER_R: float = 6.0
const PAD: float = 12.0
const RIGHT_PAD: float = 24.0
const BOTTOM_H: float = 62.0
const LEGEND_ROW_H: float = 26.0
const LEGEND_SAMPLE_W: float = 28.0
const LEGEND_GAP: float = 8.0
const LEGEND_ITEM_GAP: float = 18.0

var _names: PackedStringArray = PackedStringArray([KEY_BUGS, KEY_LIZARDS])
var _values: Dictionary = {}
var _axis_rounds: int = 4
var _y_top: float = 10.0
var _y_step: float = 2.0


func _init() -> void:
	custom_minimum_size = Vector2(480, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)


## history: round records (keys BUGS, LIZARDS, MUTANTS). start_bugs / start_lizards: the START column.
## MUTANTS starts at 0, because Stage 4 starts with no mutants (RoundRules).
func set_history(history: Array, stage: int, start_bugs: int, start_lizards: int) -> void:
	var st: int = clampi(stage, 1, 4)
	_names = PackedStringArray([KEY_BUGS, KEY_LIZARDS])
	if st == 4:
		_names.append(KEY_MUTANTS)
	var starts: Dictionary = {KEY_BUGS: float(start_bugs), KEY_LIZARDS: float(start_lizards), KEY_MUTANTS: 0.0}
	var built: Dictionary = {}
	for key: String in _names:
		built[key] = PackedFloat64Array([float(starts[key])])
	var rounds: int = 0
	for raw: Variant in history:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = raw
		rounds += 1
		for key: String in _names:
			var vals: PackedFloat64Array = built[key]
			vals.append(float(r.get(key, 0)))
			built[key] = vals
	var peak: float = 0.0
	for key: String in _names:
		var series: PackedFloat64Array = built[key]
		for v: float in series:
			peak = maxf(peak, v)
	_values = built
	_axis_rounds = maxi(5 if st == 4 else 4, rounds)
	var scale: Vector2 = _nice_scale(peak)
	_y_step = scale.x
	_y_top = scale.y
	queue_redraw()


## Test hook: where a value is drawn, in this control's local pixels. Index 0 is Start, index k is
## round k. Returns Vector2(-1, -1) when the series or index has no value.
func point_for(series: String, index: int) -> Vector2:
	if not _values.has(series):
		return Vector2(-1.0, -1.0)
	var vals: PackedFloat64Array = _values[series]
	if index < 0 or index >= vals.size():
		return Vector2(-1.0, -1.0)
	var rect: Rect2 = _plot_rect()
	return Vector2(_x_for(index, rect), _y_for(vals[index], rect))


## Test hook: series keys in drawing order (stage 4 adds MUTANTS).
func series_names() -> PackedStringArray:
	return _names.duplicate()


# === SCALE & LAYOUT ===
## Smallest step from 1, 2, 2.5, 5 (times a power of ten) giving at most five intervals up to a top
## at least as large as the peak. The floor is 10.
func _nice_scale(peak: float) -> Vector2:
	var target: float = maxf(peak, 10.0)
	var base: float = pow(10.0, floor(log(target) / log(10.0)))
	for m: float in [0.2, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0]:
		var step: float = base * m
		var count: int = ceili(target / step - 0.000001)
		if count <= 5:
			return Vector2(step, step * float(count))
	return Vector2(target, target)


func _legend_layout(width: float) -> Dictionary:
	var font: Font = ThemeDB.fallback_font
	var positions: Array = []
	var x: float = 0.0
	var row: int = 0
	for key: String in _names:
		var label: String = str(_style(key)["label"])
		var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		var item_w: float = LEGEND_SAMPLE_W + LEGEND_GAP + text_w + LEGEND_ITEM_GAP
		if x > 0.0 and x + item_w > width:
			x = 0.0
			row += 1
		positions.append(Vector2(x, float(row)))
		x += item_w
	var rows: int = row + 1 if not _names.is_empty() else 0
	return {"pos": positions, "rows": rows}


## The plot sits below the wrapped legend and right of the widest y label.
func _plot_rect() -> Rect2:
	var font: Font = ThemeDB.fallback_font
	var top_label_w: float = font.get_string_size(str(roundi(_y_top)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	var left: float = PAD + top_label_w + 12.0
	var rows: int = int(_legend_layout(size.x - 2.0 * PAD)["rows"])
	var top: float = PAD + float(rows) * LEGEND_ROW_H + 18.0
	var w: float = maxf(size.x - left - RIGHT_PAD, 40.0)
	var h: float = maxf(size.y - top - BOTTOM_H, 40.0)
	return Rect2(left, top, w, h)


func _x_for(index: int, rect: Rect2) -> float:
	return rect.position.x + rect.size.x * float(index) / float(maxi(_axis_rounds, 1))


func _y_for(value: float, rect: Rect2) -> float:
	return rect.position.y + rect.size.y * (1.0 - value / _y_top)


func _style(key: String) -> Dictionary:
	if key == KEY_LIZARDS:
		return {"label": "Lizards (after births)", "color": COL_LIZARDS, "dash": DASH_DASHED, "marker": MARK_SQUARE}
	if key == KEY_MUTANTS:
		return {"label": "Mutant lizards", "color": COL_MUTANTS, "dash": DASH_DOTTED, "marker": MARK_TRIANGLE}
	return {"label": "Bugs (after the hunt)", "color": COL_BUGS, "dash": DASH_SOLID, "marker": MARK_CIRCLE}


func _num_text(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.1f" % v


# === DRAW ===
func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	_draw_legend(font)
	var rect: Rect2 = _plot_rect()

	# Y gridlines and labels, from 0 up to the top.
	var ticks: int = roundi(_y_top / _y_step)
	for i: int in range(ticks + 1):
		var v: float = _y_step * float(i)
		var y: float = _y_for(v, rect)
		if i > 0:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), COL_GRID, 1.0)
		var label: String = _num_text(v)
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		draw_string(font, Vector2(rect.position.x - 8.0 - tw, y + 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, COL_INK)

	# Axes.
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), COL_AXIS, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, COL_AXIS, 2.0)

	# X labels: Start, then round numbers.
	for i: int in range(_axis_rounds + 1):
		var x: float = _x_for(i, rect)
		var text: String = "Start" if i == 0 else str(i)
		var xw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + 5.0), COL_AXIS, 1.5)
		draw_string(font, Vector2(x - xw * 0.5, rect.end.y + 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, COL_INK)
	var caption: String = "Round (Start = starting values)"
	var cw: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	draw_string(font, Vector2(rect.position.x + rect.size.x * 0.5 - cw * 0.5, rect.end.y + 46.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, COL_INK)

	for key: String in _names:
		_draw_series(key, rect)


func _draw_legend(font: Font) -> void:
	var layout: Dictionary = _legend_layout(size.x - 2.0 * PAD)
	var positions: Array = layout["pos"]
	for i: int in range(_names.size()):
		var key: String = _names[i]
		var st: Dictionary = _style(key)
		var p: Vector2 = positions[i]
		var x: float = PAD + p.x
		var y: float = PAD + p.y * LEGEND_ROW_H + LEGEND_ROW_H * 0.5
		var col: Color = st["color"]
		_draw_segment(Vector2(x, y), Vector2(x + LEGEND_SAMPLE_W, y), col, int(st["dash"]))
		_draw_marker(Vector2(x + LEGEND_SAMPLE_W * 0.5, y), int(st["marker"]), col)
		draw_string(font, Vector2(x + LEGEND_SAMPLE_W + LEGEND_GAP, y + 6.0), str(st["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, COL_INK)


func _draw_series(key: String, rect: Rect2) -> void:
	var vals: PackedFloat64Array = _values.get(key, PackedFloat64Array())
	var st: Dictionary = _style(key)
	var col: Color = st["color"]
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(vals.size()):
		pts.append(Vector2(_x_for(i, rect), _y_for(vals[i], rect)))
	for i: int in range(pts.size() - 1):
		_draw_segment(pts[i], pts[i + 1], col, int(st["dash"]))
	for p: Vector2 in pts:
		_draw_marker(p, int(st["marker"]), col)


func _draw_segment(a: Vector2, b: Vector2, col: Color, dash: int) -> void:
	if dash == DASH_SOLID:
		draw_line(a, b, col, LINE_W, true)
	elif dash == DASH_DASHED:
		draw_dashed_line(a, b, col, LINE_W, 12.0, true)
	else:
		var length: float = a.distance_to(b)
		if length <= 0.0:
			return
		var dir: Vector2 = (b - a) / length
		var t: float = 0.0
		while t < length:
			var t2: float = minf(t + 3.0, length)
			draw_line(a + dir * t, a + dir * t2, col, LINE_W, true)
			t += 9.0


func _draw_marker(p: Vector2, shape: int, col: Color) -> void:
	if shape == MARK_SQUARE:
		draw_rect(Rect2(p - Vector2(MARKER_R, MARKER_R), Vector2(MARKER_R * 2.0, MARKER_R * 2.0)), col, true)
	elif shape == MARK_TRIANGLE:
		var pts: PackedVector2Array = PackedVector2Array([
			p + Vector2(0.0, -MARKER_R - 2.0),
			p + Vector2(MARKER_R + 1.0, MARKER_R),
			p + Vector2(-MARKER_R - 1.0, MARKER_R),
		])
		draw_colored_polygon(pts, col)
	else:
		draw_circle(p, MARKER_R, col)
