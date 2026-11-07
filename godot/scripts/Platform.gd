extends Node
## Everything that differs between the Windows build and the web build, in one place (autoload "Platform").
##
## The web build runs the same project under the Compatibility renderer (WebGL 2, set per platform in
## project.godot by `rendering_method.web`), single-threaded, in a browser tab. This script owns:
##  - which command-line flags the app honours (on the web: the page's query string, and only `smoke`);
##  - the renderer look correction (the Compatibility renderer clips at 1.0 where Forward+ tone-maps HDR, so the
##    same scene reads washed out without it);
##  - the graphics quality profile (High / Low), persisted in the preferences; Low is the web default.
## The rest of the app asks this script rather than testing OS.has_feature("web") itself.

signal quality_changed(q: String)

## Quality profiles. terrain_stride: one terrain vertex every N cells of the 4 m heightmap (2 -> 8 m, 4 -> 16 m;
## the 1 m detail patches at the sample sites are not affected). max_3d_lines: the 3D scene is rendered at most
## this many pixels tall and scaled up to the window (0 = native), which bounds the cost on high-DPI screens.
const QUALITY := {
	"high": {"terrain_stride": 2, "shadow_size": 4096, "msaa": Viewport.MSAA_2X, "max_3d_lines": 0},
	"low": {"terrain_stride": 4, "shadow_size": 2048, "msaa": Viewport.MSAA_DISABLED, "max_3d_lines": 1080},
}
const QUALITY_NAMES := {"high": "High", "low": "Low"}

## Query-string flags honoured by the web build (?smoke runs the self-test in the browser; its result goes to the
## browser console). Capture and movie modes write files and quit, so they stay desktop-only.
const WEB_FLAGS := ["smoke"]

## Look correction under the Compatibility renderer, applied to the sun at start-up. Found by comparing
## `--capture <dir> --quick` under both renderers: with the sun casting shadows, that renderer lights every
## surface in a second, additive pass that also re-adds the sky ambient and the fog, which washed the landscape
## out to near white; without sun shadows the same scene matches the desktop build closely. (Its other difference,
## fog on additive passes, is handled in outline.gdshader and shimmer.gdshader.) Terrain relief still reads from
## the sun's shading and the hillshade, and skipping the shadow pass also halves the terrain's cost on the web.
const COMPAT_SUN_SHADOWS := false

var is_web := OS.has_feature("web")
var quality := "high"


func _ready() -> void:
	var q := str(AppState.get_pref("quality", "low" if is_web else "high"))
	quality = q if QUALITY.has(q) else "high"
	get_viewport().size_changed.connect(_apply_viewport)
	_apply_viewport()


## True when the scene is drawn by the Compatibility renderer (the web build, or the desktop build run with
## --rendering-method gl_compatibility to preview it).
func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## The app's own flags (what follows `--` on the desktop command line; the query string on the web).
func user_args() -> PackedStringArray:
	if not is_web:
		return OS.get_cmdline_user_args()
	var out := PackedStringArray()
	var search: Variant = JavaScriptBridge.eval("window.location.search", true)
	if search is String:
		for part in (search as String).trim_prefix("?").split("&", false):
			if part in WEB_FLAGS:
				out.append("--" + part)
	return out


func profile() -> Dictionary:
	return QUALITY[quality]


func set_quality(q: String) -> void:
	if not QUALITY.has(q) or q == quality:
		return
	quality = q
	AppState.set_pref("quality", q)
	_apply_viewport()
	quality_changed.emit(q)


## Full screen on and off (the web build's button and F key; browsers allow it only from a click or key press).
func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Called once by Main with the scene's environment and sun.
func setup_scene(env: Environment, sun: DirectionalLight3D) -> void:
	if is_compatibility():
		sun.shadow_enabled = COMPAT_SUN_SHADOWS


func _apply_viewport() -> void:
	var p := profile()
	var vp := get_viewport()
	vp.msaa_3d = p["msaa"]
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	var lines: int = p["max_3d_lines"]
	var h := float(get_window().size.y)   # physical pixels (the stretch mode scales the UI, not the 3D)
	vp.scaling_3d_scale = 1.0 if lines <= 0 or h <= lines else lines / h
