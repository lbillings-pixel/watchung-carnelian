extends CanvasLayer
## All on-screen UI, built in code. Two modes (AppState.ui_mode):
##   basic    - chapter bar, guided tour, scrubber + caption, short narration, key, one-line tier legend
##   advanced - everything: full narration + glossary, display / cut / layer panels, zoom path, camera modes
## plus the evidence panel, info popup, orientation aids and About dialog in both.

var main: Node
var strip: Control
var scrub: HSlider
var scrub_value: Label
var scrub_title: Label
var caption: Label
var chapter_buttons: Array = []
var narration: RichTextLabel
var glossary_box: RichTextLabel
var gscroll: ScrollContainer
var evidence_panel: PanelContainer
var evidence_text: RichTextLabel
var evidence_charts: VBoxContainer
var info_panel: PanelContainer
var info_text: RichTextLabel
var info_pinned := false
var legend_panel: PanelContainer
var legend_rows: VBoxContainer
var legend_line: Label
var legend_thick: Label
var key_panel: PanelContainer
var key_rows: VBoxContainer
var key_scroll: ScrollContainer
var orient: Control
var readout: Label
var vexag_label: Label
var ch_controls: VBoxContainer
var play_btn: Button
var about: AcceptDialog
var layer_checks := {}
var ruled_panel: PanelContainer
var right: PanelContainer
var left: PanelContainer
var top_adv: Array = []       # top-bar controls shown only in advanced mode
var tour_btn: Button
var next_btn: Button
var mode_btn: Button
var more_btn: Button
var intro_screen: PanelContainer
var group_checks := {}         # group name -> CheckBox (zone A sheets share one toggle)
var show_full_narration := false
var show_text_in_tour := false   # the chapter text is spoken under the tour; this re-shows it
var font_small := 13

const PANEL_BG := Color(0.08, 0.09, 0.11, 0.86)
## basic-mode key groups (polish pass): [id, member keys, label]
const KEY_GROUPS := [
	["passaic", ["passaic"], "Passaic Formation (red beds below)"],
	["orange_mountain", ["orange_mountain"], "Orange Mountain Basalt, ~218 m"],
	["feltville", ["feltville", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole"], "Feltville Formation, 145 m (two lake beds, baked top)"],
	["first_flow", ["glass_rind", "pillow_zone", "columnar_zone", "gabbroid", "glass_rich_gabbroid", "massive_top", "amygdaloidal_top"], "First Preakness flow: glass, pillows, columns, gabbroid lens, flow top"],
	["zone_a", [], "Candidate zone A"],
	["jps1", ["jps1"], "Jps1 siltstone between the flows, 2-3 m"],
	["upper", ["second_flow_base", "second_flow", "upper_preakness"], "Second and later Preakness flows"],
	["towaco", ["towaco"], "Towaco Formation, ~380 m"],
]
const BOTTOM_H := 162.0   # bottom panel: strip, scrubber title + switches, scrubber, two subtitle lines
const FEATURE_KEY := [
	["streams", "Streams (NHD)", Color(0.15, 0.45, 0.95), "observed"],
	["contacts", "Bedrock contacts (map)", Color(0.1, 0.1, 0.1), "observed"],
	["faults", "Faults (map)", Color(0.75, 0.05, 0.05), "observed"],
	["glacial", "Glacial deposit outlines (OFM 69)", Color(0.35, 0.55, 0.85), "observed"],
	["glacial_limits", "Glacier limits M1 / M2 (OFM 69 fig. 1, dashed)", Color(0.25, 0.45, 0.95), "observed"],
	["sites", "Sample-site zones GBR, SGB (orange ring, 250 m)", Color(1.0, 0.35, 0.1), "observed"],
	["mindat", "Mindat-reported localities (purple hatched ring)", Color(0.55, 0.25, 0.65), "mindat_reported"],
]


func setup(m: Node) -> void:
	main = m
	_build()
	Timeline.chapter_changed.connect(_on_chapter)
	Timeline.t_changed.connect(_on_t)
	AppState.changed.connect(_on_state)
	AppState.mode_changed.connect(func(_m): _apply_mode())
	AppState.layer_visibility_changed.connect(func(_k, _v): _refresh_key())
	AppState.selection_changed.connect(func(_i): _refresh_readout())
	main.tour.caption_changed.connect(func(txt): caption.text = txt)
	main.tour.state_changed.connect(_refresh_tour_button)
	_apply_mode()


func _panel(parent: Control, anchor_preset: int, size: Vector2, margin := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(anchor_preset)
	p.custom_minimum_size = size
	return p


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- top bar ----
	var top := _panel(root, Control.PRESET_TOP_WIDE, Vector2(0, 44), 6)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	top.add_child(hb)
	var ttl := Label.new()
	ttl.text = "NJ Carnelian"
	ttl.tooltip_text = "An explorable 3D time-lapse of the Volkert et al. (2023) argument"
	ttl.add_theme_font_size_override("font_size", 15)
	hb.add_child(ttl)
	hb.add_child(VSeparator.new())
	for i in Timeline.chapters.size():
		var b := Button.new()
		var ch = Timeline.chapters[i]
		b.text = ch.short_title if ch.short_title != "" else str(i + 1)
		b.tooltip_text = ch.title
		b.toggle_mode = true
		b.pressed.connect(func(): Timeline.go_to_chapter(i))
		hb.add_child(b)
		chapter_buttons.append(b)
	hb.add_child(VSeparator.new())
	tour_btn = Button.new()
	tour_btn.text = "Guided tour"
	tour_btn.tooltip_text = "Play every chapter with the camera, highlights and captions set for you (G)"
	tour_btn.pressed.connect(func(): main.tour.toggle())
	hb.add_child(tour_btn)
	next_btn = Button.new()
	next_btn.text = "Next >"
	next_btn.tooltip_text = "Skip the rest of this beat of the narrated tour (N)"
	next_btn.pressed.connect(func(): main.tour.skip())
	next_btn.visible = false
	hb.add_child(next_btn)
	var reset := Button.new()
	reset.text = "Chapter view"
	reset.tooltip_text = "Return to this chapter's curated starting view (R)"
	reset.pressed.connect(_reset_view)
	hb.add_child(reset)
	var modes := OptionButton.new()
	for n in ["Orbit (LMB rotate, RMB pan, wheel zoom)", "Free fly (WASD/QE, hold RMB to look, wheel = speed)", "Walk the brook (WASD, hold RMB to look)"]:
		modes.add_item(n)
	modes.item_selected.connect(func(i): main.camera.set_mode(i))
	main.camera.mode_changed.connect(func(mo): modes.select(mo))
	hb.add_child(modes)
	top_adv.append(modes)
	var zl := Label.new()
	zl.text = "Zoom path:"
	hb.add_child(zl)
	top_adv.append(zl)
	for sname in ["landscape", "outcrop", "vesicle", "microstructure"]:
		var zb := Button.new()
		zb.text = sname.capitalize()
		zb.pressed.connect(func(): _zoom_to(sname))
		hb.add_child(zb)
		top_adv.append(zb)
	var sep2 := VSeparator.new()
	hb.add_child(sep2)
	mode_btn = Button.new()
	mode_btn.pressed.connect(func(): AppState.ui_mode = "basic" if AppState.ui_mode == "advanced" else "advanced")
	hb.add_child(mode_btn)
	var ab := Button.new()
	ab.text = "About"
	ab.pressed.connect(func(): about.popup_centered())
	hb.add_child(ab)
	var help := Button.new()
	help.text = "?"
	help.tooltip_text = "Click any feature for details (Esc dismisses the pop-up). Keys: 1-8 chapters, Space play/pause, G guided tour, N next beat (tour), M basic/advanced, R chapter view, C cross-section, T thickening, V tier styling, H hide/show panels, I introduction."
	hb.add_child(help)

	# ---- bottom: strip + scrubber + caption ----
	var bottom := _panel(root, Control.PRESET_BOTTOM_WIDE, Vector2(0, BOTTOM_H), 6)
	bottom.offset_top = -BOTTOM_H
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	bottom.add_child(vb)
	strip = Control.new()
	strip.custom_minimum_size = Vector2(0, 46)
	strip.set_script(load("res://scripts/GlobalStrip.gd"))
	vb.add_child(strip)
	var trow := HBoxContainer.new()
	vb.add_child(trow)
	scrub_title = Label.new()
	scrub_title.add_theme_font_size_override("font_size", font_small - 1)
	scrub_title.modulate = Color(0.8, 0.8, 0.85)
	scrub_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub_title.clip_text = true
	trow.add_child(scrub_title)
	var tog_voice := CheckButton.new()
	tog_voice.text = "Narration"
	tog_voice.tooltip_text = "Spoken narration under the guided tour (computer-generated voice). The tour keeps the same timing either way."
	tog_voice.button_pressed = AppState.narration_on
	tog_voice.toggled.connect(func(on):
		AppState.narration_on = on
		if not on:
			main.tour.player.stop())
	tog_voice.add_theme_font_size_override("font_size", font_small - 1)
	trow.add_child(tog_voice)
	var tog_sub := CheckButton.new()
	tog_sub.text = "Subtitles"
	tog_sub.tooltip_text = "Show the narration sentence being spoken"
	tog_sub.button_pressed = AppState.subtitles_on
	tog_sub.toggled.connect(func(on):
		AppState.subtitles_on = on
		caption.text = main.tour.current_sentence() if (on and main.tour.on) else ("" if main.tour.on else main.tour.current_caption()))
	tog_sub.add_theme_font_size_override("font_size", font_small - 1)
	trow.add_child(tog_sub)
	var tog_hover := CheckButton.new()
	tog_hover.text = "Hover info"
	tog_hover.tooltip_text = "Pop up a feature's details when the mouse rests on it (always off during the guided tour; clicking still pins a panel, Esc dismisses it)"
	tog_hover.button_pressed = AppState.hover_info
	tog_hover.toggled.connect(func(on):
		AppState.hover_info = on
		if not on:
			hide_info())
	tog_hover.add_theme_font_size_override("font_size", font_small - 1)
	trow.add_child(tog_hover)
	var tog_amb := CheckButton.new()
	tog_amb.text = "Ambience"
	tog_amb.tooltip_text = "Quiet brook and lava sounds under the narration (synthesised; cosmetic)"
	tog_amb.button_pressed = AppState.ambience_on
	tog_amb.toggled.connect(func(on): AppState.ambience_on = on)
	tog_amb.add_theme_font_size_override("font_size", font_small - 1)
	trow.add_child(tog_amb)
	var sh := HBoxContainer.new()
	vb.add_child(sh)
	play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(func():
		Timeline.playing = not Timeline.playing
		if Timeline.playing and Timeline.t >= 1.0:
			Timeline.set_t(0.0))
	sh.add_child(play_btn)
	scrub = HSlider.new()
	scrub.min_value = 0.0
	scrub.max_value = 1.0
	scrub.step = 0.001
	scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub.value_changed.connect(func(v): if absf(v - Timeline.t) > 0.0005: Timeline.set_t(v))
	sh.add_child(scrub)
	scrub_value = Label.new()
	scrub_value.custom_minimum_size = Vector2(460, 0)
	scrub_value.add_theme_font_size_override("font_size", font_small)
	sh.add_child(scrub_value)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 15)
	caption.modulate = Color(1.0, 0.92, 0.7)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(caption)

	# ---- left: narration (+ glossary in advanced) + evidence + chapter controls ----
	left = _panel(root, Control.PRESET_TOP_LEFT, Vector2(400, 0))
	left.offset_top = 50
	left.offset_left = 6
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	var lv := VBoxContainer.new()
	left.add_child(lv)
	left.resized.connect(func(): left.size.y = minf(left.size.y, get_viewport().get_visible_rect().size.y - 50 - 300))
	narration = RichTextLabel.new()
	narration.bbcode_enabled = true
	narration.fit_content = true
	narration.scroll_active = false
	narration.custom_minimum_size = Vector2(380, 0)
	narration.add_theme_font_size_override("normal_font_size", font_small)
	narration.add_theme_font_size_override("bold_font_size", font_small + 2)
	lv.add_child(narration)
	more_btn = Button.new()
	more_btn.text = "More detail"
	more_btn.toggle_mode = true
	more_btn.toggled.connect(func(on):
		if main.tour.on:
			show_text_in_tour = on
		else:
			show_full_narration = on
		_on_chapter(Timeline.current))
	lv.add_child(more_btn)
	gscroll = ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(380, 0)
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(gscroll)
	glossary_box = RichTextLabel.new()
	glossary_box.bbcode_enabled = true
	glossary_box.fit_content = true
	glossary_box.scroll_active = false
	glossary_box.custom_minimum_size = Vector2(370, 0)
	glossary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glossary_box.resized.connect(func(): gscroll.custom_minimum_size.y = minf(glossary_box.size.y, 170.0))
	glossary_box.add_theme_font_size_override("normal_font_size", font_small - 1)
	glossary_box.modulate = Color(0.85, 0.9, 1.0)
	gscroll.add_child(glossary_box)
	var eb := Button.new()
	eb.text = "Evidence panel (observations, charts)"
	eb.toggle_mode = true
	eb.toggled.connect(func(on): evidence_panel.visible = on)
	lv.add_child(eb)
	ch_controls = VBoxContainer.new()
	lv.add_child(ch_controls)

	evidence_panel = _panel(root, Control.PRESET_CENTER, Vector2(640, 600))
	evidence_panel.visible = false
	evidence_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ev_scroll := ScrollContainer.new()
	ev_scroll.custom_minimum_size = Vector2(640, 600)
	evidence_panel.add_child(ev_scroll)
	var ev_vb := VBoxContainer.new()
	ev_vb.custom_minimum_size = Vector2(620, 0)
	ev_scroll.add_child(ev_vb)
	evidence_text = RichTextLabel.new()
	evidence_text.bbcode_enabled = true
	evidence_text.fit_content = true
	evidence_text.scroll_active = false
	evidence_text.custom_minimum_size = Vector2(620, 0)
	evidence_text.add_theme_font_size_override("normal_font_size", font_small)
	ev_vb.add_child(evidence_text)
	evidence_charts = VBoxContainer.new()
	ev_vb.add_child(evidence_charts)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		evidence_panel.visible = false
		eb.button_pressed = false)
	ev_vb.add_child(close)

	# ---- right: display + cut + layers (advanced) ----
	right = _panel(root, Control.PRESET_RIGHT_WIDE, Vector2(300, 0))
	right.offset_top = 50
	right.offset_bottom = -140
	right.offset_right = -6
	right.offset_left = -306
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rs)
	var rv := VBoxContainer.new()
	rv.custom_minimum_size = Vector2(280, 0)
	rs.add_child(rv)
	_section(rv, "Display")
	vexag_label = Label.new()
	vexag_label.text = "Vertical exaggeration: 1.0x"
	vexag_label.add_theme_font_size_override("font_size", font_small)
	rv.add_child(vexag_label)
	var vs := HSlider.new()
	vs.min_value = 1.0
	vs.max_value = 5.0
	vs.step = 0.1
	vs.value = 1.0
	vs.value_changed.connect(func(v): AppState.vexag = v)
	rv.add_child(vs)
	var tk := CheckButton.new()
	tk.text = "Thicken thin layers (x%d)" % int(AppState.thicken_factor)
	tk.button_pressed = true
	tk.toggled.connect(func(on): AppState.thicken_on = on)
	AppState.changed.connect(func(): if tk.button_pressed != AppState.thicken_on: tk.set_pressed_no_signal(AppState.thicken_on))
	tk.add_theme_font_size_override("font_size", font_small)
	rv.add_child(tk)
	var ts := CheckButton.new()
	ts.text = "Certainty-tier styling"
	ts.button_pressed = true
	ts.toggled.connect(func(on): AppState.tier_styling = on)
	ts.add_theme_font_size_override("font_size", font_small)
	rv.add_child(ts)
	var ck := CheckButton.new()
	ck.text = "Cover skin: bedrock top under colluvium / alluvium"
	ck.tooltip_text = "Draws the modelled top of bedrock beneath the mapped surficial deposits (OFM 69 extents and maxima, Illustrative taper). Best seen with the cross-section plane."
	ck.toggled.connect(func(on): AppState.cover_skin = on)
	AppState.changed.connect(func(): if ck.button_pressed != AppState.cover_skin: ck.set_pressed_no_signal(AppState.cover_skin))
	ck.add_theme_font_size_override("font_size", font_small)
	rv.add_child(ck)
	var cm := OptionButton.new()
	for n in ["Surface colour: bedrock units", "Surface colour: surficial deposits", "Surface colour: hillshade only", "Surface colour: natural (textured)"]:
		cm.add_item(n)
	cm.select(AppState.color_mode)
	cm.item_selected.connect(func(i): AppState.color_mode = i)
	AppState.changed.connect(func(): if cm.selected != AppState.color_mode: cm.select(AppState.color_mode))
	rv.add_child(cm)
	_section(rv, "Cross-section plane")
	var cs := CheckButton.new()
	cs.text = "Enable cut"
	cs.toggled.connect(func(on): AppState.cut_enabled = on)
	AppState.changed.connect(func(): if cs.button_pressed != AppState.cut_enabled: cs.set_pressed_no_signal(AppState.cut_enabled))
	cs.add_theme_font_size_override("font_size", font_small)
	rv.add_child(cs)
	var cut_az := _slider(rv, "Azimuth (deg)", 0, 360, 1, 140)
	var cut_dip := _slider(rv, "Dip of plane (deg, 90 = vertical)", 0, 90, 1, 90)
	var cut_off := _slider(rv, "Offset along normal (m)", -6000, 6000, 10, 0)
	var cut_apply := func(_v = null):
		var az := deg_to_rad(cut_az.value)
		var dp := deg_to_rad(cut_dip.value)
		var n := Vector3(sin(az) * sin(dp), cos(dp), -cos(az) * sin(dp)).normalized()
		var anchor: Vector3 = main.gbr
		AppState.cut_plane = Plane(n, n.dot(anchor) + cut_off.value)
	cut_az.value_changed.connect(cut_apply)
	cut_dip.value_changed.connect(cut_apply)
	cut_off.value_changed.connect(cut_apply)
	var flip := Button.new()
	flip.text = "Flip side"
	flip.pressed.connect(func():
		var p := AppState.cut_plane
		AppState.cut_plane = Plane(-p.normal, -p.d))
	rv.add_child(flip)
	_section(rv, "Layers")
	for fk in FEATURE_KEY:
		_layer_toggle(rv, fk[0], fk[1])
	var ro := CheckButton.new()
	ro.text = "Ruled-out sources overlay"
	ro.toggled.connect(func(on):
		main.ruled_out_on = on
		ruled_panel.visible = on)
	ro.add_theme_font_size_override("font_size", font_small)
	rv.add_child(ro)
	_section(rv, "Subsurface layers")
	for e in main.volumes.manifest["layers"]:
		if e.has("group"):
			var grp: String = e["group"]
			if group_checks.has(grp):
				continue
			var members: Array = []
			for e2 in main.volumes.manifest["layers"]:
				if e2.get("group", "") == grp:
					members.append(e2["key"])
			var c := CheckBox.new()
			c.text = "Candidate zone A: vesicle-rich gabbroid sheets (%d drawn)" % members.size() if grp == "zone_a" else grp
			c.button_pressed = true
			c.add_theme_font_size_override("font_size", font_small - 1)
			c.modulate = AppState.TIER_COLORS.get(e["tier"], Color.WHITE).lerp(Color.WHITE, 0.45)
			c.tooltip_text = AppState.tier_name(e["tier"])
			c.toggled.connect(func(on):
				for k in members:
					AppState.set_layer_visible(k, on))
			rv.add_child(c)
			group_checks[grp] = c
			continue
		_layer_toggle(rv, e["key"], e["name"], e["tier"])

	# ruled-out text panel
	ruled_panel = _panel(root, Control.PRESET_CENTER_BOTTOM, Vector2(760, 0))
	ruled_panel.offset_bottom = -(BOTTOM_H + 12)
	ruled_panel.offset_top = -(BOTTOM_H + 218)
	ruled_panel.offset_left = -380
	ruled_panel.offset_right = 380
	ruled_panel.visible = false
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(740, 0)
	rt.add_theme_font_size_override("normal_font_size", font_small)
	var s := "[b]Alternative sources the paper rules out (section 4.2)[/b]\n"
	for r in main.RULED_OUT:
		s += "[color=#f0b060]%s[/color]: %s [i](%s)[/i]\n" % [r[0], r[1], r[2]]
	rt.text = s
	ruled_panel.add_child(rt)

	# ---- key (what the colours are) and tier legend, bottom-left above the strip ----
	key_panel = _panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(330, 0), 6)
	key_panel.offset_left = 6
	key_panel.offset_right = 336
	key_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var kv := VBoxContainer.new()
	key_panel.add_child(kv)
	var kt := Label.new()
	kt.text = "Key: what is drawn now"
	kt.add_theme_font_size_override("font_size", font_small)
	kt.modulate = Color(1.0, 0.9, 0.7)
	kv.add_child(kt)
	key_scroll = ScrollContainer.new()
	key_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	key_scroll.custom_minimum_size = Vector2(318, 60)
	kv.add_child(key_scroll)
	key_rows = VBoxContainer.new()
	key_rows.custom_minimum_size = Vector2(300, 0)
	key_scroll.add_child(key_rows)
	legend_panel = _panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(330, 0), 6)
	legend_panel.offset_left = 6
	legend_panel.offset_right = 336
	var lv2 := VBoxContainer.new()
	legend_panel.add_child(lv2)
	legend_line = Label.new()
	legend_line.add_theme_font_size_override("font_size", font_small - 2)
	legend_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_line.text = "Certainty: solid = Observed,  translucent = Inferred,  hatched ghost = Illustrative,  purple ring = Mindat-reported"
	lv2.add_child(legend_line)
	legend_rows = VBoxContainer.new()
	lv2.add_child(legend_rows)
	var lt := Label.new()
	lt.text = "Certainty tiers (always on):"
	lt.add_theme_font_size_override("font_size", font_small)
	legend_rows.add_child(lt)
	for k in ["observed", "inferred", "illustrative", "mindat_reported"]:
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = AppState.TIER_COLORS[k]
		sw.custom_minimum_size = Vector2(14, 14)
		row.add_child(sw)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", font_small - 1)
		l.text = {"observed": "Observed: solid (mapped, measured)", "inferred": "Inferred: translucent (paper's interpretation)",
			"illustrative": "Illustrative: ghosted/hatched (our reconstruction)", "mindat_reported": "Mindat-reported: hatched ring (user-contributed)"}[k]
		row.add_child(l)
		legend_rows.add_child(row)
	legend_thick = Label.new()
	legend_thick.add_theme_font_size_override("font_size", font_small - 2)
	legend_thick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_thick.modulate = Color(1.0, 0.85, 0.4)
	lv2.add_child(legend_thick)

	# ---- orientation (top-right under bar) ----
	orient = Control.new()
	orient.set_script(load("res://scripts/Orientation.gd"))
	orient.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	orient.offset_left = -306 - 330
	orient.offset_right = -306
	orient.offset_top = 50
	orient.offset_bottom = 170
	orient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(orient)
	orient.main = main
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", font_small - 1)
	readout.position = Vector2(0, 0)
	orient.add_child(readout)

	# ---- info popup ----
	info_panel = _panel(root, Control.PRESET_TOP_LEFT, Vector2(360, 0))
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.fit_content = true
	info_text.scroll_active = false
	info_text.custom_minimum_size = Vector2(340, 0)
	info_text.add_theme_font_size_override("normal_font_size", font_small - 1)
	info_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info_text)

	# ---- about ----
	about = AcceptDialog.new()
	about.title = "About and attribution"
	about.min_size = Vector2i(760, 560)
	var at := RichTextLabel.new()
	at.bbcode_enabled = true
	at.custom_minimum_size = Vector2(720, 500)
	at.add_theme_font_size_override("normal_font_size", font_small)
	at.text = ABOUT_TEXT + _mindat_about()
	var av := VBoxContainer.new()
	about.add_child(av)
	av.add_child(at)
	var ib := Button.new()
	ib.text = "Show the introduction screen again"
	ib.pressed.connect(func():
		about.hide()
		show_intro())
	av.add_child(ib)
	root.add_child(about)
	_build_intro(root)
	_on_state()


## ---- introduction screen (startup; About > Show introduction; key I) ----
const INTRO_TEXT := """[b]A red stone in the wrong place[/b]

Two small brooks on the Second Watchung ridge, west of New York City, carry something no other stream in the north-eastern United States does: pebbles of carnelian, the translucent orange-red form of chalcedony. Collectors have picked them out of the gravel bars for more than a century, and nobody has ever found the rock they fell out of. Nothing in the surrounding sandstone could make them. No glacier delivered them. They are not far-travelled: their edges are barely worn.

In 2023 Richard Volkert and colleagues at the New Jersey Geological and Water Survey and Montclair State University put the pieces together: a 145-metre lava flow that cooled over a flat red floodplain 201 million years ago; a thick gabbroid lens inside it that trapped rising gas as sheets of bubbles; hot acidic water from ancient basement rocks, 100-280 degrees, climbing the basin's faults to meet cool rain water inside the bubbly upper flow; silica released from black volcanic glass, settling at 20-80 degrees into those bubbles as carnelian; then burial, tilting, a hundred million years of erosion, and two brooks that happen to cut the one horizon where it grew.

This app rebuilds that story in the real landscape, on lidar terrain, and lets you walk its chapters: the basement source, the floodplain, the eruption, the precipitation inside a single 8 mm bubble, the burial, the unroofing, today's gravel bars, and the journey of one nodule from bubble to brook. Everything on screen carries a label: Observed (measured or mapped), Inferred (the paper's interpretation), or Illustrative (this reconstruction's own choices).

[i]Based on Volkert, Gorring, Peck & Stanford (2023), Minerals 13(10):1249, CC BY 4.0, and the Chatham quadrangle maps. The app adds no collecting, access or parking information.[/i]"""


func _build_intro(root: Control) -> void:
	intro_screen = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.96)
	intro_screen.add_theme_stylebox_override("panel", sb)
	root.add_child(intro_screen)
	intro_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_screen.visible = false
	var center := CenterContainer.new()
	intro_screen.add_child(center)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 36)
	center.add_child(hb)
	var img := TextureRect.new()
	img.texture = load("res://assets/carnelian.png")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(360, 360)
	img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	img.tooltip_text = "Stylised carnelian pebble (Illustrative artwork; the real pieces are 1-5.5 cm, subangular to subrounded)"
	hb.add_child(img)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(760, 0)
	vb.add_theme_constant_override("separation", 12)
	hb.add_child(vb)
	var ttl := Label.new()
	ttl.text = "Watchung Carnelian"
	ttl.add_theme_font_size_override("font_size", 30)
	ttl.modulate = Color(1.0, 0.62, 0.3)
	vb.add_child(ttl)
	var sub := Label.new()
	sub.text = "How carnelian came to be in two brooks in New Jersey: an explorable 3D time-lapse of the Volkert et al. (2023) argument"
	sub.add_theme_font_size_override("font_size", 15)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(0.85, 0.85, 0.9)
	vb.add_child(sub)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(760, 0)
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 18)
	body.text = INTRO_TEXT
	vb.add_child(body)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	vb.add_child(bh)
	var go := Button.new()
	go.text = "Start the guided tour"
	go.tooltip_text = "Eight narrated chapters with the camera set for you (about %d minutes; N skips ahead)" % int(round(main.tour.total_minutes()))
	go.add_theme_font_size_override("font_size", 16)
	go.pressed.connect(func():
		intro_screen.visible = false
		main.tour.start(0))
	bh.add_child(go)
	var ex := Button.new()
	ex.text = "Explore on my own"
	ex.tooltip_text = "Close this screen; use the chapter buttons, scrubber and camera yourself"
	ex.add_theme_font_size_override("font_size", 16)
	ex.pressed.connect(func(): intro_screen.visible = false)
	bh.add_child(ex)
	var ck := CheckBox.new()
	ck.text = "Don't show this screen at startup (it stays available under About)"
	ck.button_pressed = bool(AppState.get_pref("skip_intro", false))
	ck.toggled.connect(func(on): AppState.set_pref("skip_intro", on))
	vb.add_child(ck)
	var hint := Label.new()
	hint.text = "Keys: G guided tour, N next beat, Space play/pause, 1-8 chapters, M basic/advanced, I this screen, Esc dismiss a pop-up. Click anything in the scene for its source. Narration, subtitles and hover pop-ups can be switched off above the scrubber."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)


func show_intro() -> void:
	intro_screen.visible = true
	intro_screen.move_to_front()


func _reset_view() -> void:
	var ch = Timeline.current_chapter()
	if ch:
		main.camera.set_near(0.5)
		main.camera.fly_to(ch.start_pos, ch.start_look)


func _apply_mode() -> void:
	var adv := AppState.ui_mode == "advanced"
	right.visible = adv
	for c in top_adv:
		c.visible = adv
	gscroll.visible = adv or (show_full_narration and not main.tour.on)
	more_btn.visible = not adv
	legend_rows.visible = adv
	legend_line.visible = not adv
	left.custom_minimum_size = Vector2(400 if adv else 360, 0)
	narration.custom_minimum_size = Vector2(380 if adv else 340, 0)
	mode_btn.text = "Switch to basic" if adv else "Switch to advanced"
	mode_btn.tooltip_text = "Basic: a streamlined screen. Advanced: every panel and control (M)"
	orient.offset_left = (-306 if adv else -6) - 330
	orient.offset_right = -306 if adv else -6
	_on_chapter(Timeline.current)
	_layout_bottom_left()
	_refresh_tour_button()


func _refresh_tour_button() -> void:
	tour_btn.text = "Stop tour" if main.tour.on else "Guided tour"
	tour_btn.modulate = Color(1.0, 0.8, 0.5) if main.tour.on else Color.WHITE
	next_btn.visible = main.tour.on
	more_btn.text = "Chapter text" if main.tour.on else "More detail"
	more_btn.tooltip_text = "Show the written chapter text (spoken by the narration)" if main.tour.on else "Full chapter text with glossary"
	if main.tour.on:
		more_btn.set_pressed_no_signal(show_text_in_tour)
	else:
		more_btn.set_pressed_no_signal(show_full_narration)
	if Timeline.current >= 0:
		_on_chapter(Timeline.current)


## Stack the key above the legend, both above the bottom strip.
func _layout_bottom_left() -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	legend_panel.reset_size()
	key_panel.reset_size()
	var lh := legend_panel.size.y
	var x0 := 416.0 if AppState.ui_mode == "advanced" else 6.0
	for pnl in [legend_panel, key_panel]:
		pnl.offset_left = x0
		pnl.offset_right = x0 + 330.0
	legend_panel.offset_top = -(BOTTOM_H + 4.0 + lh)
	legend_panel.offset_bottom = -(BOTTOM_H + 4.0)
	var kh := key_panel.size.y
	key_panel.offset_top = -(BOTTOM_H + 4.0 + lh + 4.0 + kh)
	key_panel.offset_bottom = -(BOTTOM_H + 4.0 + lh + 4.0)
	_shrink_left()


## PanelContainers only grow; after the content changes, let the left panel shrink back to its content.
func _shrink_left() -> void:
	await get_tree().process_frame
	left.reset_size()


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_small + 1)
	l.modulate = Color(1.0, 0.9, 0.7)
	parent.add_child(l)


func _slider(parent: Control, text: String, lo: float, hi: float, step: float, val: float) -> HSlider:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_small - 1)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	parent.add_child(s)
	return s


func _layer_toggle(parent: Control, key: String, text: String, tier := "") -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = true
	c.add_theme_font_size_override("font_size", font_small - 1)
	if tier != "":
		c.modulate = AppState.TIER_COLORS.get(tier, Color.WHITE).lerp(Color.WHITE, 0.45)
		c.tooltip_text = AppState.tier_name(tier)
	c.toggled.connect(func(on): AppState.set_layer_visible(key, on))
	parent.add_child(c)
	layer_checks[key] = c


func _zoom_to(sname: String) -> void:
	var ch = Timeline.current_chapter()
	if ch == null:
		return
	var views: Array = ch.scale_views
	if views.is_empty():
		views = [
			{"name": "landscape", "pos": Vector3(1500, 4500, 7500), "look": Vector3(0, 60, 0)},
			{"name": "outcrop", "pos": main.gbr + Vector3(420, 120, 330), "look": main.gbr},
		]
	for v in views:
		if v["name"].begins_with(sname.substr(0, 4)):
			if v.has("t"):
				Timeline.set_t(v["t"])
			main.camera.set_near(v.get("near", 0.5))
			main.camera.fly_to(v["pos"], v["look"], 2.2)
			return
	if sname in ["vesicle", "microstructure"]:
		Timeline.go_to_chapter(3, false)
		_zoom_to(sname)


static func _plain(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[([^\\]]+)\\]")
	return rx.sub(text, "$1", true)


func _on_chapter(i: int) -> void:
	if i < 0:
		return
	for k in chapter_buttons.size():
		chapter_buttons[k].set_pressed_no_signal(k == i)
	var ch = Timeline.chapters[i]
	var adv := AppState.ui_mode == "advanced"
	var text := "[b]%s[/b]\n" % ch.title
	var defs := ""
	if main.tour.on and not show_text_in_tour and not adv:
		text += "[i]Narrated. 'Chapter text' shows the written version.[/i]\n[i]Source: %s[/i]" % ch.refs
	elif adv or show_full_narration:
		var body: String = ch.narration
		var rx := RegEx.new()
		rx.compile("\\[([^\\]]+)\\]")
		var out := ""
		var pos := 0
		Glossary.reset_chapter()
		for m in rx.search_all(body):
			out += body.substr(pos, m.get_start() - pos)
			var term: String = m.get_string(1)
			var d := Glossary.first_use(term)
			out += "[color=#9fd3ff]%s[/color]" % term
			if d != "":
				defs += "[color=#9fd3ff]•[/color] %s\n" % d
			pos = m.get_end()
		out += body.substr(pos)
		text += out + "\n[i]Source: %s[/i]" % ch.refs
	else:
		var short: String = ch.basic_narration if ch.basic_narration != "" else _plain(ch.narration)
		text += short + "\n[i]Source: %s[/i]" % ch.refs
	narration.text = text
	glossary_box.text = defs
	scrub_title.text = "Chapter scrubber: %s  (%s)" % [ch.scrub_label, ch.scrub_units]
	var ev := "[b]Evidence this chapter rests on[/b]\n"
	for e in ch.evidence:
		ev += "• %s [i](%s)[/i]\n" % [e["text"], e["ref"]]
	ev += "\n[b]What is what in this chapter[/b]\n"
	for k in ch.tiers:
		ev += "[color=%s]%s[/color]: %s\n" % [AppState.TIER_COLORS[k.to_lower().replace("-", "_")].to_html(false), k, ch.tiers[k]]
	evidence_text.text = ev
	for c in evidence_charts.get_children():
		c.queue_free()
	for p in ch.charts:
		var tr := TextureRect.new()
		tr.texture = load(p)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.custom_minimum_size = Vector2(620, 0)
		evidence_charts.add_child(tr)
	_build_chapter_controls(ch)
	caption.text = main.tour.current_caption()
	_refresh_key()
	_shrink_left()
	strip.queue_redraw()


func _build_chapter_controls(ch) -> void:
	for c in ch_controls.get_children():
		c.queue_free()
	if ch.id == "present":
		var l := Label.new()
		l.text = "Why no carnelian in outcrop? Scenario (section 4.2):"
		l.add_theme_font_size_override("font_size", font_small)
		ch_controls.add_child(l)
		var ob := OptionButton.new()
		ob.add_item("1: source eroded away; supply thins with every flood")
		ob.add_item("2: hidden source under alluvium, floods replenish it (paper)")
		ob.fit_to_longest_item = false
		ob.clip_text = true
		ob.custom_minimum_size = Vector2(330, 0)
		ob.select(ch.scenario)
		var l2 := Label.new()
		l2.text = "Scenario 1 expressed as:"
		l2.add_theme_font_size_override("font_size", font_small - 1)
		l2.visible = ch.scenario == 0
		ch_controls.add_child(ob)
		ch_controls.add_child(l2)
		var dm := OptionButton.new()
		dm.add_item("colluvium thins AND the bar is not replenished")
		dm.add_item("colluvial store thins around GBR only")
		dm.add_item("bar stock dwindles only (cover unchanged)")
		dm.fit_to_longest_item = false
		dm.clip_text = true
		dm.custom_minimum_size = Vector2(330, 0)
		dm.visible = ch.scenario == 0
		dm.select({"both": 0, "colluvium": 1, "bar": 2}[AppState.depletion_mode])
		dm.item_selected.connect(func(k):
			AppState.depletion_mode = ["both", "colluvium", "bar"][k]
			Timeline.set_t(Timeline.t))
		ch_controls.add_child(dm)
		ob.item_selected.connect(func(k):
			ch.scenario = k
			l2.visible = k == 0
			dm.visible = k == 0
			Timeline.set_t(Timeline.t))
	elif ch.id == "precipitation":
		var l := Label.new()
		l.text = "Candidate precipitation zone shown:"
		l.add_theme_font_size_override("font_size", font_small)
		ch_controls.add_child(l)
		var zb := OptionButton.new()
		zb.add_item("Both A and B (the paper does not choose)")
		zb.add_item("A only: vesicle-rich gabbroid sheets, upper 40 m")
		zb.add_item("B only: amygdaloidal flow top")
		zb.fit_to_longest_item = false
		zb.clip_text = true
		zb.custom_minimum_size = Vector2(330, 0)
		zb.select({"both": 0, "A": 1, "B": 2}[AppState.candidate_zone])
		zb.item_selected.connect(func(k):
			AppState.candidate_zone = ["both", "A", "B"][k]
			Timeline.set_t(Timeline.t))
		ch_controls.add_child(zb)
		var l2 := Label.new()
		l2.text = "Mixing ratio (varied; explains the d18O spread, section 5.3):"
		l2.add_theme_font_size_override("font_size", font_small)
		ch_controls.add_child(l2)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = ch.mix_ratio
		s.value_changed.connect(func(v):
			ch.mix_ratio = v
			Timeline.set_t(Timeline.t))
		ch_controls.add_child(s)
		var l3 := Label.new()
		l3.text = "hydrothermal-dominated  <->  meteoric-dominated (no numeric ratio is given)"
		l3.add_theme_font_size_override("font_size", font_small - 2)
		ch_controls.add_child(l3)


## The key lists the subsurface layers currently drawn (chapter era + toggles), the chapter's extra items,
## and the feature lines that are on.
func _refresh_key() -> void:
	for c in key_rows.get_children():
		c.queue_free()
	var ch = Timeline.current_chapter()
	var vol: Node = main.volumes
	var era: Array = vol.era_keys
	var n := 0
	if ch != null and ch.id != "basement" and ch.id != "worm" and AppState.ui_mode == "basic":
		# basic mode (polish pass): one row per formation, not one per modelled slab
		for grp in KEY_GROUPS:
			var members: Array = grp[1]
			if grp[0] == "zone_a":
				members = vol.zone_a_keys()
			var first: Dictionary = {}
			var count := 0
			for e in vol.manifest["layers"]:
				if not members.has(e["key"]) or (not era.is_empty() and not era.has(e["key"])) or not AppState.is_layer_visible(e["key"]):
					continue
				if ch.id == "precipitation" and ((e.get("group", "") == "zone_a" and AppState.candidate_zone == "B") or (e["key"] == "amygdaloidal_top" and AppState.candidate_zone == "A")):
					continue
				if first.is_empty():
					first = e
				count += 1
			if count == 0:
				continue
			var label: String = grp[2]
			if grp[0] == "zone_a":
				label = "Candidate zone A: %d vesicle-rich sheets, 5-39 m below the flow top" % count
			_key_row(Color.html(first["color"]), label, first["tier"])
			n += 1
	elif ch != null and ch.id != "basement" and ch.id != "worm":
		var groups_done := {}
		for e in vol.manifest["layers"]:
			if not era.is_empty() and not era.has(e["key"]):
				continue
			if not AppState.is_layer_visible(e["key"]):
				continue
			if ch.id == "precipitation":
				if e.get("group", "") == "zone_a" and AppState.candidate_zone == "B":
					continue
				if e["key"] == "amygdaloidal_top" and AppState.candidate_zone == "A":
					continue
			if e.has("group"):
				if groups_done.has(e["group"]):
					continue
				groups_done[e["group"]] = true
				var za: Dictionary = vol.manifest.get("zone_a", {})
				_key_row(Color.html(e["color"]), "Candidate zone A: %d vesicle-rich gabbroid sheets, %.0f-%.0f m below the flow top" % [za.get("keys", []).size(), 145.0 - float(za.get("top_offset_m", 140.0)), 145.0 - float(za.get("base_offset_m", 106.0))], e["tier"])
				n += 1
				continue
			_key_row(Color.html(e["color"]), e["name"], e["tier"])
			n += 1
	if ch != null:
		for it in ch.key_items:
			_key_row(it["color"], it["name"], it.get("tier", ""), it.get("shape", "box"))
			n += 1
	if ch != null and ch.id != "basement" and ch.id != "worm":
		for fk in FEATURE_KEY:
			if main.features.groups.has(fk[0]) and main.features.groups[fk[0]].visible and AppState.is_layer_visible(fk[0]):
				_key_row(fk[2], fk[1], fk[3], "line")
				n += 1
	key_scroll.custom_minimum_size.y = clampf(n * 19.0 + 4.0, 24.0, 210.0)
	_layout_bottom_left()


func _key_row(col: Color, name: String, tier: String, shape := "box") -> void:
	var row := HBoxContainer.new()
	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(16, 4) if shape == "line" else Vector2(16, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_small - 2)
	l.text = name
	l.clip_text = true
	l.custom_minimum_size = Vector2(230, 0)
	l.tooltip_text = name + ("  [" + AppState.tier_name(tier) + "]" if tier != "" else "")
	row.add_child(l)
	if tier != "":
		var tl := Label.new()
		tl.add_theme_font_size_override("font_size", font_small - 3)
		tl.text = {"observed": "Obs", "inferred": "Inf", "illustrative": "Ill", "mindat_reported": "Mindat"}.get(tier, "")
		tl.modulate = AppState.tier_color(tier).lerp(Color.WHITE, 0.3)
		row.add_child(tl)
	key_rows.add_child(row)


func _on_t(t: float) -> void:
	scrub.set_value_no_signal(t)
	var ch = Timeline.current_chapter()
	if ch:
		scrub_value.text = ch.scrub_text(t)
	play_btn.text = "Pause" if Timeline.playing else "Play"
	strip.queue_redraw()


func _on_state() -> void:
	vexag_label.text = "Vertical exaggeration: %.1fx" % AppState.vexag
	if AppState.thicken_on:
		legend_thick.text = "Thin layers thickened up to x%d for visibility (glass rind, vesicle sheets, flow top, Jps1, aureole): true values in every info panel. Toggle: T" % int(AppState.thicken_factor)
	else:
		legend_thick.text = "Layers at TRUE thickness (T to thicken)"
	_refresh_readout()
	_refresh_key()


func _refresh_readout() -> void:
	pass


func _process(_dt: float) -> void:
	if main == null:
		return
	var ci: Dictionary = main.camera.camera_info()
	var sel_tier := "none selected"
	if not AppState.selected.is_empty():
		sel_tier = AppState.tier_name(AppState.selected.get("tier", ""))
	var txt := "Camera elevation %.1f m" % ci["y"]
	if ci["depth"] > 0.0:
		txt += "  (%.1f m BELOW ground)" % ci["depth"]
	else:
		txt += "  (%.1f m above ground)" % (-ci["depth"])
	txt += "\nGround here: %.1f m" % ci["ground"]
	txt += "\nSelected: %s" % sel_tier
	if AppState.vexag != 1.0:
		txt += "\nVERTICAL EXAGGERATION %.1fx" % AppState.vexag
	if not main.volumes.tilted:
		txt += "\nBeds shown UNTILTED (as deposited)"
	readout.text = txt
	play_btn.text = "Pause" if Timeline.playing else "Play"
	orient.queue_redraw()


func show_info(info: Dictionary, at: Vector2, pinned: bool) -> void:
	if info.is_empty():
		if not info_pinned:
			info_panel.visible = false
		return
	if info_pinned and not pinned:
		return
	info_pinned = pinned
	var tier: String = info.get("tier", "")
	var col: Color = AppState.tier_color(tier)
	info_text.text = "[b]%s[/b]\n[color=%s]%s[/color]\n%s\n[i]Source: %s[/i]%s" % [info.get("title", ""), col.to_html(false), AppState.tier_name(tier),
		info.get("body", ""), info.get("ref", ""), "\n[color=#888888](pinned: click elsewhere to release)[/color]" if pinned else ""]
	info_panel.visible = true
	var vp := get_viewport().get_visible_rect().size
	info_panel.reset_size()
	var p := at + Vector2(18, 18)
	if p.x + 380 > vp.x:
		p.x = at.x - 390
	if p.y + info_panel.size.y > vp.y - 140:
		p.y = maxf(50, vp.y - BOTTOM_H - 6 - info_panel.size.y)
	info_panel.position = p


## Dismiss the info pop-up (pinned or not).
func hide_info() -> void:
	info_pinned = false
	info_panel.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and info_panel != null and not info_pinned:
		info_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and info_pinned:
		info_pinned = false
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_ESCAPE:
			hide_info()
			return
		if k >= KEY_1 and k <= KEY_8:
			Timeline.go_to_chapter(k - KEY_1)
		elif k == KEY_SPACE:
			Timeline.playing = not Timeline.playing
			if Timeline.playing and Timeline.t >= 1.0:
				Timeline.set_t(0.0)
		elif k == KEY_R:
			_reset_view()
		elif k == KEY_G:
			main.tour.toggle()
		elif k == KEY_N:
			main.tour.skip()
		elif k == KEY_I:
			show_intro()
		elif k == KEY_M:
			AppState.ui_mode = "basic" if AppState.ui_mode == "advanced" else "advanced"
		elif k == KEY_C:
			AppState.cut_enabled = not AppState.cut_enabled
		elif k == KEY_T:
			AppState.thicken_on = not AppState.thicken_on
		elif k == KEY_V:
			AppState.tier_styling = not AppState.tier_styling
		elif k == KEY_H:
			for c in $Root.get_children():
				if c != orient and c != info_panel:
					c.visible = not c.visible
			if AppState.ui_mode == "basic":
				right.visible = false


## The Mindat API records fetched by scripts/fetch_mindat.py (data/vectors/mindat_*.json), when present.
static func _mindat_about() -> String:
	var nj: Variant = AppState.load_json("res://data/vectors/mindat_nj_carnelian.json")
	var cards: Variant = AppState.load_json("res://data/vectors/mindat_minerals.json")
	if not (nj is Dictionary) and not (cards is Dictionary):
		return ""
	var out := "
[b]Mindat API[/b]
"
	if cards is Dictionary:
		var fetched := ""
		for k in cards:
			fetched = str(cards[k].get("fetched", ""))
		out += "• The five marker records and the Chalcedony, Carnelian, Moganite and Quartz property cards were refreshed through the Mindat API (api.mindat.org) on %s; the marker positions and their stated precision are unchanged. The glossary's mineral entries carry the cards.
" % fetched
	if nj is Dictionary:
		var locs: Array = nj.get("localities", [])
		var inside: Array = []
		var outside: Array = []
		for e in locs:
			var nm: String = str(e.get("name", "")).replace(", New Jersey, USA", "")
			if bool(e.get("in_study_area", false)):
				inside.append("#%d %s" % [int(e.get("mindat_id", 0)), nm])
			else:
				outside.append(nm)
		out += "• Every New Jersey locality listing carnelian on Mindat (%d on %s): inside the study area %s; elsewhere in the state: %s.
" % [locs.size(), str(nj.get("fetched", "")), ("; ".join(inside) if not inside.is_empty() else "none beyond the five markers"), ("; ".join(outside) if not outside.is_empty() else "none")]
	return out


const ABOUT_TEXT := """[b]NJ Carnelian: an explorable 3D time-lapse of the Volkert et al. (2023) argument[/b]

[b]Primary source (adapted under CC BY 4.0, the licence printed in the article):[/b]
Volkert, R.A., Gorring, M.L., Peck, W.H., Stanford, S.D. (2023). Characterization and Origin of Basalt-Derived Carnelian in the Mesozoic Newark Basin, New Jersey, USA. Minerals 13(10), 1249. https://doi.org/10.3390/min13101249

[b]Maps and papers also read for the model[/b]
• Monteverde, D.H. & Volkert, R.A. (2005). Bedrock Geologic Map of the Chatham Quadrangle. NJGS GMS 04-02 (dip 9.5 deg from its cross-section A-A'; unit thicknesses; Watchung syncline limbs 6-15 deg).
• Stanford, S.D. (2007). Surficial Geology of the Chatham Quadrangle. NJGS OFM 69 (glacier limits M1/M2 from its Figure 1; cover-thickness maxima).
• Puffer, J.H. & Volkert, R.A. (2001). Pegmatoid and gabbroid layers in Jurassic Preakness and Hook Mountain Basalts. J. Geol. 109, 585-601 (positions of the vesicular gabbroid sheets and the Berkeley Heights lens).
• Faust, G.T. (1978). Joint systems in the Watchung basalt flows. USGS Prof. Paper 864-B (column dimensions).
• Steckler, M.S. et al. (1993) Geology 21, 735-738; El-Tabakh, M. et al. (1997) Sedimentology 44, 767-790; Rddad, L. et al. (2022) Geochemistry 82, 125918 (fluid temperatures and mixing, chapters 1 and 4).

[b]Data[/b]
• Elevation: USGS 3DEP 1 m lidar DEM, project NJ_NE6County_B23 (2023), via The National Map. Public domain.
• Hydrography: USGS National Hydrography Dataset (Best Resolution, HU4 0203). Public domain.
• Bedrock geology 1:24,000: NJ Geological and Water Survey DGS15-1 (Chatham quadrangle, from GMS 04-02). Surficial geology 1:24,000: NJGWS DGS10-2 (from OFM 69). Source credit: NJDEP Geographic Information System (GIS). Statewide 1:100,000 layers (NJDEP) were downloaded as a fallback.
• Mindat localities: mindat.org, read 2026-11-04. Mindat.org is an outreach project of the Hudson Institute of Mineralogy. Cite: Ralph, J. et al. (2025) Mindat.org: The open access mineralogy database to accelerate data-intensive geoscience research. American Mineralogist 110(6), 833–844. doi:10.2138/am-2024-9486. Mindat data are user-contributed and are shown here as their own "Mindat-reported" class under Mindat's non-commercial terms (CC BY-NC-SA 4.0).

[b]Certainty tiers[/b]
Observed = measured or mapped; Inferred = the paper's interpretation; Illustrative = this app's reconstruction with no direct source; Mindat-reported = user-contributed. Every assumption is logged in ASSUMPTIONS.md with its tier and reference.

[b]Software[/b]  Godot Engine 4.7.2 (MIT licence). Pipeline: Python with rasterio, GDAL, geopandas, shapely, numpy, scipy, trimesh, matplotlib, PyMuPDF.

Scene origin = centre of the study area (UTM 18N E 547 500, N 4 500 500). Study bbox E 540 500–554 500, N 4 494 500–4 506 500.
"""
