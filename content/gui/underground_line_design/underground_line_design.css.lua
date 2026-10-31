-- The underground switch window (underground.tl) at the top right, styled like the construction bottom bar
-- (R::ConstructionParamsContent#menu.construction.bottomparams.react in construction.css.lua).
local color_util = require "::/gui/main/color_util.tl"
local ssu = require "::/gui/main/stylesheetutil.lua"

local function build(result)
	local a = ssu.makeAdder(result)

	local colorDefault = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data
	local transparency = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/transparency.gres")).data

	-- below the top edge of the screen, clear of the line manager window at the left
	a("Window#undergroundline.bar", {
		anchorPoint = { 1, 0 },
		gravity = { 1, 0 },
		margin = { 80, 20, 0, 0 },
		padding = { 8, 8, 8, 8 },
		size = { 314, -1 },
		backgroundImage1 = {
			fileName = "::/gui/builtin/window/design/surface_simple.tga",
			horizontal = { 0, 40, 42, 92 },
			vertical = { 0, 50, 52, 92 },
		},
		borderImage = {
			fileName = "::/gui/builtin/window/design/contour_simple.tga",
			horizontal = { 0, 40, 42, 92 },
			vertical = { 0, 50, 52, 92 },
		},
		backgroundColor1 = color_util.withTransparencyRaw(colorDefault.BaseDarkMedium, transparency.VeryLow),
		borderColor = color_util.withTransparencyRaw(colorDefault.NeutralMedium, transparency.Medium),
	})
	a("Window#undergroundline.bar:hover", {
		borderColor = colorDefault.AccentLight,
	})
	a("Window#undergroundline.bar Window::Content", {
		padding = { 8, 8, 8, 8 },
	})
	a("Window#undergroundline.bar Window::Content > BoxLayout", {
		innerSpacing = { 8, 8 },
		minSize = { -1, 28 },
	})
	-- label and buttons as the construction parameters (script-param-wrap)
	a("Window#undergroundline.bar Window::Content > BoxLayout > TextView", {
		minSize = { 110, -1 },
		gravity = { -1, 0.5 },
	})
	a("Window#undergroundline.bar ToggleButtonGroup", {
		gravity = { 1, 0.5 },
	})
	a("Window#undergroundline.bar ToggleButton", {
		padding = { 4, 4, 4, 4 },
	})
	a("Window#undergroundline.bar ToggleButton > FloatingLayout > TextView", {
		size = { 50, 24 },
		textAlignment = { 0.5, 0.5 },
	})
end

function data()
	local result = {}
	local ok, err = pcall(build, result)
	if not ok then
		print("[underground_line_design] stylesheet error: " .. tostring(err))
	end
	return result
end
