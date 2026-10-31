-- Underground view while designing lines (see replacement.script.tl for the hooks into the line manager):
-- - the state of the view, kept for the whole game session
-- - the underground mode on the layer config of the line manager modes
-- - a small window at the top right with the switch, shown while the line manager is open; it also
--   receives the underground key of the construction tools (G by default)

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local construction_react_util = ug_require "::/gui/construction/construction_react_util.tl" as ConstructionReactUtil
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local layer_react_util = ug_require "::/gui/layers/layer_react_util.tl" as LayerReactUtil
local manager_window = ug_require "::/gui/line_vehicle_mgmt/manager_window.tl" as ManagerWindow
local react = ug_require "::/gui/main/react.lua" as React

--- input action of the underground switch in the construction tools (construction_react_util.tl)
local UndergroundInputAction <const> = "IA_UNDERGOUND_MODE_TOGGLE"
--- Builtin.WindowParam.id and window container key of the bar window. Without "_": CSS selectors
--- (Window#id in underground_line_design.css.lua) did not match the id with underscores.
local BarWindowId <const> = "undergroundline.bar"

local underground : UldUnderground = {}

underground.InputAction = UndergroundInputAction

local enabled = false
--- number of mounted line manager modes (the bar is visible while it is above 0)
local mountedModes = 0
--- game context the bar window was added for (a new game has a new window container)
local barAddedFor : GameContext = nil
--- diagnostics: the underground mode reached a layer config of the line manager
local loggedApplied = false

underground.isEnabled = function() : boolean
	return enabled
end

underground.setEnabled = function(value : boolean)
	if enabled ~= value then
		enabled = value
		loggedApplied = false
		log.message("[underground_line_design] underground view " .. (value and "on" or "off"))
	end
end

underground.apply = function(layerConfig : LayerConfig)
	if not enabled or layerConfig == nil then
		return
	end
	layerConfig.undergroundMode = true
	-- the white screen of the construction tools, keeping the line and vehicle colors of the line manager
	local layerColors = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/layers/layer_colors.gres")).data as LayerColors
	local colorPassFn = layerConfig.colorPassFn
	if colorPassFn ~= nil then
		colorPassFn.fallbackColor = layer_react_util.createDefaultFallbackColor(
			layerColors.Construction.Fallback.Surface, layerColors.Construction.Fallback.Details, true, true)
		layerConfig.colorPassFn = colorPassFn
	end
	if not loggedApplied then
		loggedApplied = true
		log.message("[underground_line_design] underground mode set on the layer config of the line manager")
	end
end

--- The window container sends Esc (IA_CLOSE_TOPMOST_WINDOW) to the topmost window. The switch window is
--- added after the line manager and is raised when clicked, so the line manager is moved back on top.
local function raiseLineManager(gameCtx : GameContext)
	xpcall(function()
		gameCtx.windowContainer:get():getApi().moveSingletonWindowToFront(manager_window.ManagerToolWindow)
	end, function(err : any)
		log.message("[underground_line_design] error raising the line manager window: " .. tostring(err))
	end)
end

local UndergroundSwitch = react.RegisterRecipe("UldUndergroundSwitch", function(params : UldUnderground.BarParams) : TreeNodeId
	-- polled every step, so the buttons also follow the key
	local current = engine_react_util.useStepState(function() : boolean
		return enabled
	end) as ReactStateT<boolean>
	-- the underground key, only received here (not in the line manager modes or its window content)
	react.useInputAction(UndergroundInputAction, react.iaHandler(function()
		underground.setEnabled(not enabled)
	end, function() : boolean
		return mountedModes > 0
	end, _("Underground Mode")))
	-- the same parameter as the construction tools (name, tooltip and button texts)
	local param = construction_react_util.makeUndergroundParam(function(value : integer) : integer
		return value == 1 and 0 or 1
	end)
	-- The buttons of script_param_util use the "Uniform" layout, which shares the available width: in a
	-- window sized by its content they get no width at all. The buttons here size to their texts.
	local buttons : {Builtin.ToggleButtonGroupChildParam} = {}
	for i, text in ipairs(param.values) do
		buttons[i] = {
			meta = { tooltip = param.tooltip },
			content = builtin.TextView{
				meta = { class = "font-scale-body" },
				text = text,
			},
		}
	end
	-- the content of a window must be a layout
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.TextView{
				meta = { class = "font-scale-body", tooltip = param.tooltip },
				text = param.name,
			},
			builtin.ToggleButtonGroup{
				buttons = buttons,
				layout = "Horizontal",
				-- values are { Yes, No }
				selected = current:old() and 1 or 2,
				onValueChange = function(index : integer)
					underground.setEnabled(index == 1)
					raiseLineManager(params.gameCtx)
				end,
			},
		},
	}
end)

local UndergroundBar = react.RegisterWrapperRecipe("UldUndergroundBar", builtin.Window, function(params : UldUnderground.BarParams) : TreeNodeId
	return builtin.Window{
		meta = { class = "no-close-button" },
		id = BarWindowId,
		title = "",
		closable = false,
		movable = false,
		pinnable = false,
		compact = true,
		autoFocusOnBecomingVisible = false,
		autoVisibilityOnFocusChange = false,
		-- position from underground_line_design.css.lua
		tool = "management",
		content = UndergroundSwitch{ gameCtx = params.gameCtx },
	}
end)

local function showBar(gameCtx : GameContext, visible : boolean)
	xpcall(function()
		if visible and barAddedFor ~= gameCtx then
			local wc = gameCtx.windowContainer:get():getApi()
			wc.addWindow(UndergroundBar, BarWindowId, { gameCtx = gameCtx })
			barAddedFor = gameCtx
		end
		if barAddedFor ~= nil then
			api.gui.byId.setVisible(BarWindowId, visible)
		end
		if visible then
			raiseLineManager(gameCtx)
		end
	end, function(err : any)
		log.message("[underground_line_design] error showing the underground switch: " .. tostring(err))
	end)
end

underground.useBar = function(gameCtx : GameContext)
	react.onMount(function()
		mountedModes = mountedModes + 1
		if mountedModes == 1 then
			showBar(gameCtx, true)
		end
	end)
	react.onUnmount(function()
		mountedModes = math.max(mountedModes - 1, 0)
		if mountedModes == 0 then
			showBar(gameCtx, false)
		end
	end)
end

return underground
