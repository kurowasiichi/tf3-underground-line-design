-- Hooks the underground view into the line manager (registered by replacement.res.lua):
-- - line_util.makeLineActionDescriptor builds the action of every line manager mode (main, segment,
--   move stop, move waypoint, send vehicles). The wrapper re-renders the mode when the view changes and
--   shows the switch window while a mode is mounted.
-- - The layer config is created inside makeLineActionDescriptor. builtin.LayerConfig is wrapped, only while
--   makeLineActionDescriptor runs, to set the underground mode.
-- - The line manager window lets only a fixed list of input actions through: the underground key is added.

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local line_util = ug_require "::/gui/line_vehicle_mgmt/line_util.tl" as LineUtil
local underground = ug_require "/gui/underground_line_design/underground.tl" as UldUnderground

local record LayerConfigNodeParam
	config : LayerConfig
end

--- makeLineActionDescriptor is running
local insideLineAction = false
--- diagnostics: the wrapper is reached by the line manager
local loggedFirstCall = false

local function wrapLayerConfig()
	local builtinTable = builtin as {string : any}
	if builtinTable.uldOriginalLayerConfig ~= nil then
		return
	end
	local original = builtinTable.LayerConfig as function(LayerConfigNodeParam) : TreeNodeId
	builtinTable.uldOriginalLayerConfig = original
	builtinTable.LayerConfig = function(param : LayerConfigNodeParam) : TreeNodeId
		if insideLineAction and param ~= nil then
			xpcall(underground.apply, function(err : any)
				log.message("[underground_line_design] error setting the underground mode: " .. tostring(err))
			end, param.config)
		end
		return original(param)
	end
end

local function wrapLineActionDescriptor()
	local utilTable = line_util as {string : any}
	if utilTable.uldOriginalMakeLineActionDescriptor ~= nil then
		return
	end
	local original = utilTable.makeLineActionDescriptor as function(any, GameContext, ...: any) : TreeNodeId
	utilTable.uldOriginalMakeLineActionDescriptor = original
	utilTable.makeLineActionDescriptor = function(commonParams : any, gameCtx : GameContext, ...: any) : TreeNodeId
		if not loggedFirstCall then
			loggedFirstCall = true
			log.message("[underground_line_design] first call of makeLineActionDescriptor")
		end
		-- polled every step: switching re-renders the mode with the new layer config
		engine_react_util.useStepState(function() : boolean
			return underground.isEnabled()
		end)
		underground.useBar(gameCtx)
		insideLineAction = true
		local ok, result = pcall(original, commonParams, gameCtx, ...)
		insideLineAction = false
		if not ok then
			error(result)
		end
		return result as TreeNodeId
	end
end

--- id of the line manager window (manager_window.tl)
local ManagerWindowId <const> = "menu.management"

--- The line manager window only lets the input actions of a fixed list bubble up to the mode actions
--- (manager_window.ManagerToolWindow: InputActionBubbleUpFilter.allowOnly). The filter is a C++ object
--- whose list cannot be read or changed, so the list of manager_window.tl is copied here with the
--- underground key added, and replaces the filter when builtin.Window is called for that window.
local ManagerWindowInputActions <const> : {string} = {
	"IA_MANAGEMENT_MODE",
	"IA_MENU", "IA_MENU_BACK", "IA_GAME_PAUSE_OR_CYCLE_SPEED", "gamePause", "gameCycleSpeed",
	"IA_CONTEXT_HELP", "IA_GUIDE", "IA_CLOSE_TOPMOST_WINDOW", "IA_SKIP_VOICEOVER_AND_CUTSCENE",
	"IA_ACCEPT", "IA_SELECT", "IA_APPLY",
	"IA_UP", "IA_DOWN", "IA_LEFT", "IA_RIGHT", "IA_NAV_UP", "IA_NAV_DOWN", "IA_NAV_LEFT", "IA_NAV_RIGHT",
	"IA_OPTION1",
	"IA_CAMERA_PAN", "IA_CAMERA_ROTATE_X", "IA_CAMERA_TILT", "IA_CAMERA_ZOOM_IN", "IA_CAMERA_ZOOM_OUT",
	"cameraMoveUp", "cameraMoveDown", "cameraMoveLeft", "cameraMoveRight",
	"cameraRotateLeft", "cameraRotateRight", "cameraTiltUp", "cameraTiltDown", "cameraZoomIn", "cameraZoomOut",
	"IA_GAME_DEBUG_TOGGLE_DEBUG_WINDOW", "IA_DEBUG_OUTPUT_COMPONENT_UNDER_CURSOR", "IA_DEBUG_OUTUPUT_FOCUSED_COMPONENT",
	"IA_DEBUG_RELOAD_REACT_COMPONENT", "IA_DEBUG_RELOAD_DEFINITIONS", "IA_DEBUG_RELOAD_SHADERS",
	"IA_DEBUG_RELOAD_STATE_PROVIDER", "uiCloseAll",
	underground.InputAction,
}

local function wrapManagerWindow()
	local builtinTable = builtin as {string : any}
	if builtinTable.uldOriginalWindow ~= nil then
		return
	end
	local original = builtinTable.Window as function(Builtin.WindowParam) : TreeNodeId
	builtinTable.uldOriginalWindow = original
	local logged = false
	builtinTable.Window = function(param : Builtin.WindowParam) : TreeNodeId
		if param ~= nil and param.id == ManagerWindowId and param.inputActionBubbleUpFilter ~= nil then
			xpcall(function()
				param.inputActionBubbleUpFilter = builtin.type.InputActionBubbleUpFilter.allowOnly(ManagerWindowInputActions)
				if not logged then
					logged = true
					log.message("[underground_line_design] underground key let through the line manager window")
				end
			end, function(err : any)
				log.message("[underground_line_design] error changing the input filter of the line manager window: " .. tostring(err))
			end)
		end
		return original(param)
	end
end

local function doReplaceFn(_replacementApi : ReactReplacementApi)
	wrapLayerConfig()
	wrapLineActionDescriptor()
	wrapManagerWindow()
	log.message("[underground_line_design] line manager hooks installed")
end

local result = {
	doReplaceFn = doReplaceFn,
}

return result
