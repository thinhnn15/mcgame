class_name UiTheme
extends RefCounted

const CREAM := Color("fff8ef")
const INK := Color("5b4a44")
const PINK := Color("ffb7c8")
const PINK_DARK := Color("f08aa6")
const MINT := Color("bfeedd")

static func box(bg: Color, radius := 18, border := Color(0, 0, 0, 0), bw := 0, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.shadow_color = Color(0.45, 0.3, 0.3, 0.12)
	s.shadow_size = 4
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", INK)
	t.set_stylebox("normal", "Button", box(Color.WHITE, 16, Color("f3d9d0"), 2))
	t.set_stylebox("hover", "Button", box(Color("fff0f3"), 16, PINK, 3))
	t.set_stylebox("pressed", "Button", box(PINK_DARK, 16, PINK_DARK, 3))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 16, PINK, 3))
	t.set_stylebox("panel", "PanelContainer", box(Color(CREAM, 0.94), 28, Color("f6dccf"), 3, 18))
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0))
	t.set_stylebox("tab_selected", "TabContainer", box(PINK, 14, PINK_DARK, 0, 14))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color("fbe9e2"), 14, Color(0, 0, 0, 0), 0, 14))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color("ffd6df"), 14, Color(0, 0, 0, 0), 0, 14))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", INK)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font_size("font_size", "TabContainer", 22)
	return t
