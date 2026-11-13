class_name MailReply
extends MiniGame

const ROUNDS := 3

var good := 0
var _round := 0
var _round_left := 0.0
var _round_secs := 9.0
var _thread: VBoxContainer
var _choices: VBoxContainer
var _typing: Label
var _waiting := false

func _build(area: Control) -> void:
	_round_secs = 9.0 * (1.0 - 0.35 * difficulty)
	duration = ROUNDS * (_round_secs + 1.2) + 1.0
	_left = duration
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.size = MiniGame.AREA
	area.add_child(h)
	var mail := PanelContainer.new()
	mail.add_theme_stylebox_override("panel", UiTheme.box(Color("f7f8fa"), 14, Color("e3e6ec"), 2, 14))
	mail.custom_minimum_size = Vector2(430, MiniGame.AREA.y)
	_thread = VBoxContainer.new()
	_thread.add_theme_constant_override("separation", 10)
	mail.add_child(_thread)
	h.add_child(mail)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	h.add_child(right)
	_typing = label(tr("MG_TYPING"), 20, Color("a08a82"))
	right.add_child(_typing)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 12)
	right.add_child(_choices)
	_next_round()

func _key(i: int, part: String) -> String:
	return "MG_M_%s%d%s" % ["V" if job == "dev" else "D", i + 1, part]

func _next_round() -> void:
	for c in _choices.get_children():
		c.queue_free()
	if _round >= ROUNDS:
		done(float(good) / ROUNDS)
		return
	_typing.visible = true
	_waiting = true
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	_typing.visible = false
	_bubble(tr(_key(_round, "")), false)
	var opts := [["_G", true], ["_R", false], ["_O", false]]
	opts.shuffle()
	for o in opts:
		var b := button(tr(_key(_round, o[0])), 20)
		b.custom_minimum_size = Vector2(0, 74)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(b.text, o[1]))
		_choices.add_child(b)
	_round_left = _round_secs
	_waiting = false

func _bubble(text: String, mine: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color("dcefe2") if mine else Color.WHITE, 14,
		Color("b9dcc4") if mine else Color("e3e6ec"), 2, 12))
	var l := label(text, 18, UiTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	_thread.add_child(p)
	while _thread.get_child_count() > 5:
		var old := _thread.get_child(0)
		_thread.remove_child(old)
		old.queue_free()

func _answer(text: String, right: bool) -> void:
	if _waiting:
		return
	_waiting = true
	_bubble(text, true)
	if right:
		good += 1
	else:
		shake(_thread.get_parent())
		fumble()
	_round += 1
	_next_round()

func _tick(delta: float) -> void:
	if _waiting:
		return
	_round_left -= delta
	if _round_left <= 0.0:
		_waiting = true
		_bubble("???", false)
		_round += 1
		_next_round()

func timeout_score() -> float:
	return float(good) / ROUNDS
