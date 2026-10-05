--!strict
-- Tiny closure-based signal used by the client store, controllers and UI.
-- Handlers run via task.spawn so one erroring listener never breaks the others.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { [Connection]: (...any) -> () } = {}
	local signal: Signal

	local function connect(_: Signal, fn: (...any) -> ()): Connection
		local connection: Connection
		connection = {
			Connected = true,
			Disconnect = function(self: Connection)
				self.Connected = false
				handlers[connection] = nil
			end,
		}
		handlers[connection] = fn
		return connection
	end

	signal = {
		Connect = connect,
		Once = function(self: Signal, fn: (...any) -> ()): Connection
			local connection: Connection? = nil
			connection = connect(self, function(...)
				if connection then
					connection:Disconnect()
				end
				fn(...)
			end)
			return connection :: Connection
		end,
		Fire = function(_: Signal, ...: any)
			local connections: { Connection } = {}
			local fns: { (...any) -> () } = {}
			for connection, fn in handlers do
				table.insert(connections, connection)
				table.insert(fns, fn)
			end
			for i, connection in connections do
				if connection.Connected then
					task.spawn(fns[i], ...)
				end
			end
		end,
		Wait = function(self: Signal): ...any
			local thread = coroutine.running()
			self:Once(function(...)
				task.spawn(thread, ...)
			end)
			return coroutine.yield()
		end,
		DisconnectAll = function(_: Signal)
			for connection in handlers do
				connection.Connected = false
			end
			table.clear(handlers)
		end,
	}
	return signal
end

return Signal
