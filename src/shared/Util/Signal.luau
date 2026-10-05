--!strict
--[[
	Signal — tiny typed event object (no Instances, works on server and client).

		local changed = Signal.new() :: Signal.Signal<Player, number>
		local conn = changed:Connect(function(player, value) ... end)
		changed:Fire(player, 5)
		conn:Disconnect()

	Handlers run in their own thread (task.spawn), so a yielding or erroring handler never
	blocks the caller or other handlers.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	type Entry = { Handler: (T...) -> (), Connection: Connection }
	local entries: { Entry } = {}

	local function remove(connection: Connection)
		for i, entry in entries do
			if entry.Connection == connection then
				table.remove(entries, i)
				return
			end
		end
	end

	local self = {} :: Signal<T...>

	function self.Connect(_: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = {} :: Connection
		connection.Connected = true
		function connection.Disconnect(c: Connection)
			if c.Connected then
				c.Connected = false
				remove(c)
			end
		end
		table.insert(entries, { Handler = handler, Connection = connection })
		return connection
	end

	function self.Once(s: Signal<T...>, handler: (T...) -> ()): Connection
		local connection: Connection
		connection = s:Connect(function(...: T...)
			connection:Disconnect()
			handler(...)
		end)
		return connection
	end

	function self.Fire(_: Signal<T...>, ...: T...)
		-- Snapshot so handlers may connect/disconnect while we iterate.
		local snapshot = table.clone(entries)
		for _, entry in snapshot do
			if entry.Connection.Connected then
				task.spawn(entry.Handler, ...)
			end
		end
	end

	function self.Wait(s: Signal<T...>): T...
		local thread = coroutine.running()
		s:Once(function(...: T...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function self.DisconnectAll(_: Signal<T...>)
		for _, entry in entries do
			entry.Connection.Connected = false
		end
		table.clear(entries)
	end

	return self
end

return Signal
