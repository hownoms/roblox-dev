--!strict
-- Review-only sink. It never writes player data, awards coins/certifications or creates trophies.
local Adapter = {}
export type Context = {
	EventInstanceId: string,
	EventId: string,
	SourceId: string,
	ContentVersion: number,
	Participants: { any },
	[string]: any,
}
function Adapter.new()
	local contexts: { Context } = {}
	local seen: { [string]: boolean } = {}
	local self = {}
	function self.Submit(context: Context): (boolean, string)
		if seen[context.EventInstanceId] then
			return false, "ReviewOnly: already captured; no permanent reward granted"
		end
		seen[context.EventInstanceId] = true
		table.insert(contexts, context)
		if #contexts > 20 then
			local oldest = table.remove(contexts, 1)
			if oldest then seen[oldest.EventInstanceId] = nil end
		end
		print("[SpringVault REVIEW ADAPTER] validated context captured; NO rewards granted", context.EventInstanceId)
		return false, "ReviewOnly: adventure complete; permanent rewards are not connected"
	end
	function self.Contexts(): { Context }
		return table.clone(contexts)
	end
	return self
end
return Adapter
