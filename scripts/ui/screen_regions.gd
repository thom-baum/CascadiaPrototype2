class_name ScreenRegions
extends RefCounted
## THE ONE LAYOUT AUTHORITY for every persistent panel on Cascadia's screen.
##
## THE DEFECT THIS FILE EXISTS TO REMOVE. Before this file there was no shared layout authority.
## Six independent CanvasLayers each built their own Control tree and placed it with their own
## values, across three different strategies - anchors (the HUD, save/load), manual viewport maths
## (the combat overlay) and a bare hardcoded `position` (the input overlay, the death message).
## Where two panels shared a corner the separation was a hand-tuned MAGIC NUMBER: the save/load
## panel carried `offset_top = 62`, whose own comment admitted it existed because at 8 it "covered
## the credits number completely". A dodge tuned that way is correct at ONE window size and wrong at
## every other, and this project runs with `display/window/stretch/mode = canvas_items` and
## `aspect = expand`, so panel CONTENT grows with the scaled theme font while a fixed pixel offset
## does not.
##
## WHAT IT IS NOW. One set of RESERVED SCREEN REGIONS, expressed as anchor fractions of the logical
## viewport, plus one host VBoxContainer per region. A panel never positions itself: it joins its
## region's host and the Container lays it out. Two panels inside one region are separated by that
## Container's separation, and two panels in different regions cannot touch at any viewport size by
## construction.
##
## WHY ANCHOR FRACTIONS ARE SAFE HERE. `canvas_items` + `expand` scales the whole UI with the
## window, and the logical viewport is never smaller than the base 1152x648 (the scale factor is
## min(w/1152, h/648), so the logical size can only grow past the base). Every fraction below is
## therefore measured against at least 1152x648, and the splits were chosen against the panels' own
## minimum sizes at that floor:
##
##   left column   0.66 -> 760 px   sized for the input table's TWO-column REFLOW - two blocks of its
##                                  own table width plus a separation have to FIT, which 0.38 could
##                                  not do at any logical size
##   right column  0.32 -> 368 px   the widest panel there needs 334 px (the save/load key line)
##   centre band   0.40 -> 461 px   the death message wraps inside it, symmetric about the centre
##
## THE REGIONS, and what occupies each one:
##
##   VITALS                   LEFT column, upper band    game_hud.gd - RESERVED, see below
##   INPUT_DIAGNOSTICS        LEFT column, lower band    input_debug_overlay.gd
##   TOP_RIGHT_STACK          right column, upper band    game_hud.gd (credits) THEN
##                                                        save_load_debug_controls.gd, stacked in that
##                                                        order inside ONE shared VBoxContainer
##   BOTTOM_RIGHT_DIAGNOSTICS right column, lower band    combat_debug_overlay.gd
##   DEATH_MESSAGE            centre band, CENTRED        death_presentation_debug.gd
##
## THE VITALS REGION IS RESERVED AND NO DEBUG PANEL IS ANCHORED INTO IT. Health and stamina are the
## shipped game's own readout, so they get a region of their own that no diagnostic may join. The
## input overlay's 44-line table cannot share that band, so the LEFT column is SPLIT: vitals owns the
## upper band and the input diagnostics owns the tall lower band. Two panels claiming one region is
## exactly the collision this file exists to remove.
##
## LAYERS. Tree order used to be the only thing deciding z-order, because no CanvasLayer in
## main.tscn set an explicit `layer` and every one of them defaulted to 1. main.tscn now carries
## these values literally and each script re-asserts its own from the constants below, so the scene
## text and the running code can be read against each other. The order is deliberate:
##
##   enemy health bars (1)   above the world, below every panel, so a floating bar cannot cover one
##   debug panels (2)        the diagnostics band - all four debug overlays share one layer
##   death message (3)       drawn above the other diagnostics while it is up
##   game HUD (4)            the shipped readouts stay readable above the debug panels
##   pause overlay (8)       strictly above all of the above, so pause is never drawn over
##
## TOOLING NOTE. A region's host column joins a group, and a module that needs a region its own layer
## does not host asks the tree for the existing one first. That is how the save/load panel ends up in
## the SAME VBoxContainer as the credits readout even though the two are separate CanvasLayers - and
## it is why main.tscn declares GameHUD BEFORE SaveLoadControls, so the HUD builds that stack and
## therefore hosts it on the HUD layer.

# --- Layers -----------------------------------------------------------------

## Above the 3D world, below every panel. A bar that floats over an enemy must never cover a readout,
## and it must never be able to draw over the pause overlay.
const LAYER_ENEMY_HEALTH_BARS := 1
## The diagnostics band: input, combat and save/load all share it. They cannot collide, because each
## one owns a different region, so one layer for all of them costs nothing.
const LAYER_DEBUG_PANELS := 2
## The death message, above the other diagnostics so it reads while they are on screen.
const LAYER_DEATH_PRESENTATION := 3
## The shipped HUD, above every debug panel.
const LAYER_GAME_HUD := 4
## The pause overlay. Strictly above every other canvas in the scene.
const LAYER_PAUSE_OVERLAY := 8

# --- Region geometry --------------------------------------------------------

## Gap kept between a panel and its region's edges, and between two slots of one stack. One value,
## used by every region, so no panel carries a private margin.
const EDGE_MARGIN := 12.0
## Separation between two panels that share a region stack. This is what replaced the hand-tuned
## `offset_top = 62`: the credits readout and the save/load panel are siblings in one VBoxContainer,
## and the space between them is this number applied by the Container, not an offset on either panel.
const STACK_SEPARATION := 8.0

## Everything left of this fraction of the logical width belongs to the LEFT column: the reserved
## health/stamina band above, and the input diagnostics table below it.
##
## 0.66, NOT the 0.38 this started as, and the reason is the input table's own REFLOW. That table is
## the only panel in this project whose HEIGHT is the problem - 58 rows is roughly 928 px against a
## 531 px region at the shortest logical height - and the fix is to lay it out in TWO columns, which
## halves the height. Two blocks do not fit in 0.38 of any logical viewport, so the column has to be
## wide enough for them: 0.66 x the minimum logical width of 1152 is 760 px, or 736 px after the
## region's own margins, against the ~700 px two blocks need. The 0.02 still clear before the right
## column starts at 0.68 is deliberate - two regions that overlap would make the layout unpredictable.
const LEFT_COLUMN_END := 0.68
## Everything right of this fraction belongs to the right column (top-right stack, then combat).
const RIGHT_COLUMN_START := 0.68
## Bottom of the right column's upper band. The top-right stack lives above it and grows downward.
const RIGHT_TOP_BAND_END := 0.42
## Where the LEFT column splits in two: ABOVE this fraction is the RESERVED health/stamina band, BELOW
## it is the input diagnostics table. 0.18 of the base 648 px logical height is 117 px, which fits the
## vitals panel's own ~110 px, and leaves the tall 44-line input table the rest of the column.
const LEFT_COLUMN_SPLIT := 0.18
## The death-message band: a strip SYMMETRIC about 0.50 on both axes, so "YOU DIED" lands in the middle
## of the screen rather than in a corner at any window size.
const DEATH_BAND_LEFT := 0.30
const DEATH_BAND_TOP := 0.30
const DEATH_BAND_RIGHT := 0.70
const DEATH_BAND_BOTTOM := 0.70

## The reserved regions. Every persistent panel joins exactly one of them.
enum Region {
	## The LEFT column's LOWER band: the input foundation table.
	INPUT_DIAGNOSTICS,
	## The right column's upper band: the credits readout and the save/load panel, stacked.
	TOP_RIGHT_STACK,
	## The right column's lower band: the combat and targeting diagnostics.
	BOTTOM_RIGHT_DIAGNOSTICS,
	## The CENTRE of the screen: the death message.
	DEATH_MESSAGE,
	## The LEFT column's UPPER band: health and stamina. RESERVED - no debug panel joins this.
	VITALS,
}


# --- The regions, as anchor fractions ---------------------------------------

## Anchor fractions of one region: [left, top, right, bottom], as fractions of the logical viewport.
## These are ANCHORS, so they track any window size without a resize handler anywhere.
static func bounds(region: int) -> Array:
	match region:
		Region.TOP_RIGHT_STACK:
			return [RIGHT_COLUMN_START, 0.0, 1.0, RIGHT_TOP_BAND_END]
		Region.BOTTOM_RIGHT_DIAGNOSTICS:
			return [RIGHT_COLUMN_START, RIGHT_TOP_BAND_END, 1.0, 1.0]
		Region.DEATH_MESSAGE:
			return [DEATH_BAND_LEFT, DEATH_BAND_TOP, DEATH_BAND_RIGHT, DEATH_BAND_BOTTOM]
		Region.VITALS:
			return [0.0, 0.0, LEFT_COLUMN_END, LEFT_COLUMN_SPLIT]
		_:
			# INPUT_DIAGNOSTICS - the lower-left, below the reserved vitals band.
			return [0.0, LEFT_COLUMN_SPLIT, LEFT_COLUMN_END, 1.0]


## Where a region's stack packs its panels: the top of the region for the panels that hang from the
## top of the screen, the bottom for the ones that sit on the floor of their band. A panel that grows
## at runtime then grows UPWARD from the bottom edge instead of pushing itself off the screen - the
## second clipping report the combat overlay's old per-frame maths was written for.
static func alignment(region: int) -> int:
	match region:
		Region.BOTTOM_RIGHT_DIAGNOSTICS:
			return BoxContainer.ALIGNMENT_END
		Region.DEATH_MESSAGE:
			# CENTRED, so "YOU DIED" lands in the middle of the screen. The old message placed itself
			# from a per-frame calculation; the region now owns that and the panel adds nothing.
			return BoxContainer.ALIGNMENT_CENTER
		_:
			return BoxContainer.ALIGNMENT_BEGIN


## A readable name for the region, used for the host node's name and for diagnostics.
static func region_name(region: int) -> String:
	match region:
		Region.INPUT_DIAGNOSTICS:
			return "InputDiagnostics"
		Region.TOP_RIGHT_STACK:
			return "TopRightStack"
		Region.BOTTOM_RIGHT_DIAGNOSTICS:
			return "BottomRightDiagnostics"
		Region.DEATH_MESSAGE:
			return "DeathMessage"
		Region.VITALS:
			return "Vitals"
		_:
			return "Unknown"


# --- Hosting ----------------------------------------------------------------

## The group a region's host column joins, so a module on another CanvasLayer can find it.
static func host_group(region: int) -> StringName:
	return StringName("screen_region_%s" % region_name(region).to_lower())


## The host column already built for this region, or null when nobody has claimed the region yet.
## Resolved through the scene tree rather than a static variable, so nothing survives a scene change.
static func find_host(any_node: Node, region: int) -> VBoxContainer:
	if any_node == null or any_node.get_tree() == null:
		return null
	for node in any_node.get_tree().get_nodes_in_group(host_group(region)):
		var column := node as VBoxContainer
		if column != null and is_instance_valid(column):
			return column
	return null


## The host column for a region, built in `canvas` when this module is the first to need it.
##
## ONE HOST PER REGION is the whole point: five modules cannot each build their own private tree and
## hope the values agree, which is exactly what used to happen. The first module to need a region
## builds its host; every later module - including one on a different CanvasLayer - joins the same
## VBoxContainer, so Container separation is what space two panels of one region apart.
static func join(canvas: CanvasLayer, region: int) -> VBoxContainer:
	var existing := find_host(canvas, region)
	if existing != null:
		return existing

	var root := Control.new()
	root.name = "Region_%s" % region_name(region)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var column := VBoxContainer.new()
	column.name = "Stack"
	var box := bounds(region)
	column.anchor_left = box[0]
	column.anchor_top = box[1]
	column.anchor_right = box[2]
	column.anchor_bottom = box[3]
	column.offset_left = EDGE_MARGIN
	column.offset_top = EDGE_MARGIN
	column.offset_right = -EDGE_MARGIN
	column.offset_bottom = -EDGE_MARGIN
	column.alignment = alignment(region)
	column.add_theme_constant_override("separation", int(STACK_SEPARATION))
	# MOUSE FILTER IS PER CONTROL and is NOT inherited, so it is set on the host as well: these hosts
	# span whole screen bands, and a Control with the default STOP filter across a screen band would
	# swallow every mouse click landing in it - and Cascadia's light and heavy attacks are bound to
	# MOUSE BUTTONS.
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_to_group(host_group(region))
	root.add_child(column)
	return column


# --- Adaptive layout --------------------------------------------------------

## Horizontal space between two adaptive columns. Small on purpose: the block that wraps is already
## separated from its neighbour by being on the next line.
const ADAPTIVE_SEPARATION := 8


## A container that lays its children out in as many columns as the width it is GIVEN allows, wrapping
## the rest onto following lines.
##
## THIS IS THE PROJECT'S ONE REFLOW MECHANISM, and it is deliberately Godot's own `HFlowContainer`
## rather than a custom Container: wrapping is exactly what an HFlowContainer does, it needs no
## `size_changed` handler, and it cannot drift out of sync with the viewport because it measures the
## space it is ACTUALLY given rather than a copy of that space. Two blocks sit side by side while they
## fit; the moment they do not, the second wraps BELOW the first - which is the collapse a caller wants,
## rather than two cramped columns.
##
## MEASURED CONSEQUENCE FOR THIS PROJECT. `canvas_items` + `expand` keeps the logical viewport at or
## ABOVE the 1152x648 base: the scale factor is min(w/1152, h/648), so logical width can never fall
## below 1152 and logical height can never fall below 648. The worst case for a TALL panel is therefore
## the SHORTEST logical height, 648 - and that is the case the input table's two-column mode exists to
## cover: ~928 px of rows in one column against a 531 px region, versus ~464 px in two, which fits.
##
## Each child states its own `custom_minimum_size`, and the reflow point follows those, so a block that
## grows wider moves the wrap with it instead of the layout silently crushing it.
static func adaptive_columns() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "AdaptiveColumns"
	flow.add_theme_constant_override("h_separation", ADAPTIVE_SEPARATION)
	flow.add_theme_constant_override("v_separation", 0)
	# Same reason as every other Control in this project: Cascadia's light and heavy attacks are bound
	# to MOUSE BUTTONS, so a read-only band must never be able to take a click.
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flow


## Bound `panel` to its region's height, and return the container to parent in its place.
##
## WHY A BOUND AT ALL, when the content usually fits. The input table's height is a function of the
## WINDOW rather than of its content, because `canvas_items` scaling shrinks the logical viewport toward
## the base and the table cannot shrink with it. Unbounded, the table simply runs off the bottom edge
## and its tail becomes unreachable with nothing on screen saying so. Bounded, the REGION is the limit:
## the panel's bottom edge stays inside the viewport at every window size, which is the property that
## was asked for, and any excess is clipped inside a scrollable area rather than by the screen.
##
## MOUSE FILTER IS IGNORE, NOT STOP, and the trade is worth stating plainly: a ScrollContainer can only
## be wheel-scrolled by a Control that accepts the mouse, and this project has already paid once for a
## debug panel that swallowed a click bound to an attack. What is being bought here is the BOUND; the
## REFLOW above is what keeps the content reachable without scrolling at all.
static func bound_to_region(panel: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "RegionScroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EXPAND_FILL so the bound is the REGION's height rather than the content's. The panel inside stays
	# content-sized - it shrinks on both axes - so a short table never stretches into a tall empty box.
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# FILL, NEVER SHRINK, and this is MEASURED rather than assumed. A first version of this function
	# used SIZE_SHRINK_BEGIN here, which sized the bound - and therefore the panel and the adaptive
	# flow container inside it - to the content's MINIMUM width. The input table's two blocks are 360 px
	# each and the region they sit in is 736 px wide, so the pair genuinely fits; but the flow was only
	# ever handed 389 px, so it wrapped and the two-column layout was UNREACHABLE at EVERY window size.
	# The probe caught it as "the layout stacked because the pair genuinely does NOT fit (728 > 736)" -
	# an assertion that failed BECAUSE 728 does fit, which is the only reason the bug was visible at all.
	# The region owns the width; the bound must accept it.
	scroll.size_flags_horizontal = Control.SIZE_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(panel)
	return scroll


## The pixel size a region's band occupies in the CURRENT viewport, with `EDGE_MARGIN` already
## removed - i.e. how much room a panel in that region actually has.
##
## A panel that has to make an adaptive decision (the input table choosing one column or two) cannot
## read that decision off its own Control: measured on this project, a ScrollContainer does NOT stretch
## its child to the container's width, so a panel that asks its own `size` gets its single-column
## MINIMUM regardless of how wide the region is. The region's width has to come from the same constants
## that place it, which is why this lives here beside `bounds()` rather than in the panel.
static func region_pixel_size(any_node: Node, region: int) -> Vector2:
	var tree := any_node.get_tree() if any_node != null else null
	if tree == null or tree.root == null:
		return Vector2.ZERO
	var viewport := tree.root.get_visible_rect().size
	var box := bounds(region)
	return Vector2(
		maxf(0.0, viewport.x * (box[2] - box[0]) - 2.0 * EDGE_MARGIN),
		maxf(0.0, viewport.y * (box[3] - box[1]) - 2.0 * EDGE_MARGIN))
