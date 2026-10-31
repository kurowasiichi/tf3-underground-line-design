recordDef = true

--- Underground view while designing lines in the line manager.
global record UldUnderground
	--- Parameters of the bar window with the underground switch.
	record BarParams is IRecipeParamWithMeta
		gameCtx : GameContext
	end

	--- input action of the underground switch in the construction tools (spelled as in the game)
	InputAction : string

	--- the underground view is on (kept for the whole game session)
	isEnabled : function() : boolean
	setEnabled : function(enabled : boolean)

	--- Sets the underground mode on a layer config of the line manager, when the view is on.
	apply : function(layerConfig : LayerConfig)

	--- Called inside every line manager mode: shows the bar while at least one mode is mounted.
	useBar : function(gameCtx : GameContext)
end
