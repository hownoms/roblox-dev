--!strict
-- Only the production Viewport's preference dependency is replaced in this isolated place.
-- No production State.Init, remotes, player data, or gameplay services run here.
local State = {}

function State.GetSetting(key: string, default: any): any
	return if key == "ReducedMotion" then true else default
end

return State
