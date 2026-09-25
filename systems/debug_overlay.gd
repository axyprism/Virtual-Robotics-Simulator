extends CanvasLayer

var _visible_state: bool = false
var _panel: PanelContainer
var _label: RichTextLabel

func _ready() -> void:
	layer = 100 
	_build_ui()
	visible = false

	MatchScheduler.schedule_updated.connect(_refresh)
	MatchScheduler.current_match_changed.connect(func(_m): _refresh())
	MatchScheduler.match_completed.connect(func(_n, _r): _refresh())
	MatchScheduler.config_changed.connect(_refresh)
	ScoringManager.score_changed.connect(func(_a, _s): _refresh())
	MatchManager.phase_changed.connect(func(_p): _refresh())
	GameManager.game_selected.connect(func(_g): _refresh())
	NetworkManager.player_connected.connect(func(_id): _refresh())
	NetworkManager.player_disconnected.connect(func(_id): _refresh())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.offset_left = -428
	_panel.offset_right = -8
	_panel.offset_top = 8
	_panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 500)
	_panel.add_child(scroll)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(400, 0)
	_label.scroll_active = false
	scroll.add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_visible_state = not _visible_state
		visible = _visible_state
		if _visible_state:
			_refresh()

func _process(_delta: float) -> void:
	if visible:
		_refresh() 

func _refresh() -> void:
	if not visible or not _label:
		return
	_label.text = _build_report()

func _build_report() -> String:
	var lines: Array[String] = []

	if not NetworkManager.is_networked():
		lines.append("[color=gray]OFFLINE (singleplayer)[/color]")
	elif NetworkManager.is_host():
		lines.append("[color=yellow]HOST[/color] - peer id %d" % NetworkManager.get_my_id())
	else:
		lines.append("[color=cyan]CLIENT[/color] - peer id %d" % NetworkManager.get_my_id())
	lines.append("Connected players: %s" % str(NetworkManager.players.keys()))
	lines.append("")

	lines.append("[b]MatchManager[/b]")
	lines.append("  phase: %s" % MatchManager.Phase.keys()[MatchManager.current_phase])
	lines.append("  time_left: %.1f  running: %s" % [MatchManager.time_left, MatchManager.running])
	if MatchManager.in_gap:
		lines.append("  [color=orange]in_gap: %.1fs left[/color]" % MatchManager.gap_time_left)
	lines.append("")

	lines.append("[b]MatchScheduler[/b]")
	lines.append("  mode: %s  total_matches: %d  alliance_size: %d (min %d)" % [
		MatchScheduler.Mode.keys()[MatchScheduler.mode], MatchScheduler.total_matches,
		MatchScheduler.alliance_size, MatchScheduler.min_alliance_size
	])
	lines.append("  bench: %s" % str(MatchScheduler.get_bench()))
	lines.append("  current_match_index: %d" % MatchScheduler.current_match_index)

	var current = MatchScheduler.get_current_match()
	if current == null:
		lines.append("  [color=gray]current match: none[/color]")
	else:
		lines.append("  [color=lime]current match:[/color] %s" % _format_match(current))

	lines.append("  full queue:")
	if MatchScheduler.schedule.is_empty():
		lines.append("    (empty)")
	for i in MatchScheduler.schedule.size():
		var marker := "->" if i == MatchScheduler.current_match_index else "  "
		lines.append("    %s %s" % [marker, _format_match(MatchScheduler.schedule[i])])
	lines.append("")

	lines.append("[b]ScoringManager[/b]")
	lines.append("  red: %d   blue: %d" % [ScoringManager.get_score("red"), ScoringManager.get_score("blue")])
	lines.append("")

	var scoring := GameManager.current_scoring
	if scoring is RebuiltScoring:
		var rs: RebuiltScoring = scoring
		lines.append("[b]RebuiltScoring[/b]")
		lines.append("  auto_winner: %s" % (rs.auto_winner if rs.auto_winner != "" else "(tied/unset)"))
		lines.append("  hub active - red: %s  blue: %s" % [rs.is_hub_active("red"), rs.is_hub_active("blue")])
		lines.append("  fuel scored - red: %d  blue: %d" % [rs.get_fuel_scored("red"), rs.get_fuel_scored("blue")])
		lines.append("  tower pts - red: %d  blue: %d" % [rs.get_tower_points("red"), rs.get_tower_points("blue")])
		lines.append("  energized - red: %s  blue: %s" % [rs.has_energized("red"), rs.has_energized("blue")])
		lines.append("  supercharged - red: %s  blue: %s" % [rs.has_supercharged("red"), rs.has_supercharged("blue")])

	return "\n".join(lines)

func _format_match(m: Dictionary) -> String:
	return "#%d [%s] red%s vs blue%s" % [m["match_number"], m["status"], str(m["red"]), str(m["blue"])]
