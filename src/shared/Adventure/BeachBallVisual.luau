--!strict
-- Local spherical sectors with smooth normals; original primitive fallback if unavailable.
-- The fixed contact sphere never squashes. No physics impulse or gameplay authority lives here.
local Build = require(script.Parent.Parent.Models.Build)
local Kit = require(script.Parent.Parent.Models.Expansion1)
local Ball = {}
local COLORS = { Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold }

-- A single spherical surface eliminates intersections altogether. Face colors share
-- radial normals across sector boundaries, so gutters are color changes, not ridges.
-- This creates only local Content; it never uploads or enables a place permission.
local function smoothShell(model: Model, diameter: number, center: Vector3, cancelled: (() -> boolean)?): MeshPart?
	local mesh: EditableMesh? = nil
	local shell: MeshPart? = nil
	local function checkActive()
		if cancelled and cancelled() then
			error("Local ball decoration cancelled")
		end
	end
	local ok, failure = pcall(function()
		checkActive()
		local assetService = game:GetService("AssetService")
		local created = assetService:CreateEditableMesh()
		if not created then
			error("Local editable mesh budget unavailable")
		end
		mesh = created
		local longitudeCount, latitudeCount = 96, 48
		local vertices: { { number } } = {}
		local normals: { { number } } = {}
		local cream = created:AddColor(Kit.Palette.Cream, 1)
		local colors = {}
		for _, color in COLORS do
			table.insert(colors, created:AddColor(color, 1))
		end
		for latitude = 0, latitudeCount do
			local vertexRow, normalRow = {}, {}
			local elevation = -math.pi / 2 + latitude * math.pi / latitudeCount
			for longitude = 0, longitudeCount - 1 do
				local angle = longitude * math.pi * 2 / longitudeCount
				local direction = Vector3.new(
					math.cos(elevation) * math.sin(angle),
					math.sin(elevation),
					math.cos(elevation) * math.cos(angle)
				)
				table.insert(vertexRow, created:AddVertex(direction * (diameter / 2 + 0.02)))
				table.insert(normalRow, created:AddNormal(direction))
			end
			table.insert(vertices, vertexRow)
			table.insert(normals, normalRow)
			if latitude % 6 == 0 then
				task.wait()
				checkActive()
			end
		end
		local function triangle(
			rowA: number,
			colA: number,
			rowB: number,
			colB: number,
			rowC: number,
			colC: number,
			color: number
		)
			local face = created:AddTriangle(vertices[rowA][colA], vertices[rowB][colB], vertices[rowC][colC])
			created:SetFaceNormals(face, { normals[rowA][colA], normals[rowB][colB], normals[rowC][colC] })
			created:SetFaceColors(face, { color, color, color })
		end
		for latitude = 0, latitudeCount - 1 do
			for longitude = 0, longitudeCount - 1 do
				local column, nextColumn = longitude + 1, (longitude + 1) % longitudeCount + 1
				local sectorColumn = longitude % 16
				local gutter = sectorColumn == 0 or sectorColumn == 15 or latitude < 3 or latitude >= latitudeCount - 3
				local color = if gutter then cream else colors[math.floor(longitude / 16) % 3 + 1]
				if latitude > 0 then
					triangle(latitude + 1, column, latitude + 1, nextColumn, latitude + 2, column, color)
				end
				if latitude < latitudeCount - 1 then
					triangle(latitude + 1, nextColumn, latitude + 2, nextColumn, latitude + 2, column, color)
				end
			end
			if latitude % 6 == 0 then
				task.wait()
				checkActive()
			end
		end
		local part = assetService:CreateMeshPartAsync(Content.fromObject(created), {
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
		shell = part
		checkActive()
		part.Name = "ColorPanel"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(center)
		part.Parent = model
		part.Destroying:Connect(function()
			created:Destroy()
		end)
	end)
	if not ok then
		if shell then
			shell:Destroy()
		end
		if mesh then
			mesh:Destroy()
		end
		model:SetAttribute("BallGeometryMode", "PrimitiveFallback")
		if not (cancelled and cancelled()) then
			warn("Spring Vault local ball mesh unavailable; primitive fallback: " .. tostring(failure))
		end
		return nil
	end
	model:SetAttribute("BallGeometryMode", "LocalSmoothSectors")
	return shell
end

-- EditableMesh Content is process-local. A server-created shell did not render
-- on networked review clients, so every client constructs its own presentation.
-- Call asynchronously once per streamed ball; cleanup restores primitive visibility.
-- The same entry point can be called in Edit for local visual inspection.
function Ball.DecorateLocal(model: Model, cancelled: (() -> boolean)?): (() -> ())?
	local contact = model:FindFirstChild("ContactSphere")
	if not contact or not contact:IsA("BasePart") then
		return nil
	end
	local shell = smoothShell(model, Kit.Spec.BallDiameter, contact.Position, function()
		return not model:IsDescendantOf(workspace)
			or not contact:IsDescendantOf(model)
			or (cancelled and cancelled()) == true
	end)
	if not shell then
		return nil
	end
	if not model.Parent or not contact.Parent then
		shell:Destroy()
		return nil
	end
	local originalTransparency: { [BasePart]: number } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= shell and (part.Name == "ColorPanel" or part.Name == "ContactSphere") then
			originalTransparency[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	shell.CFrame = contact.CFrame
	local runService = game:GetService("RunService")
	local frameSignal = if runService:IsClient() then runService.RenderStepped else runService.Heartbeat
	local follow = frameSignal:Connect(function()
		if shell.Parent and contact.Parent then
			shell.CFrame = contact.CFrame
		end
	end)
	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		follow:Disconnect()
		shell:Destroy()
		for part, transparency in originalTransparency do
			if part.Parent then
				part.LocalTransparencyModifier = transparency
			end
		end
	end
	shell.Destroying:Once(function()
		if not cleaned then
			cleanup()
		end
	end)
	return cleanup
end

function Ball.Create(): Model
	local model = Build.model("landmark_spring_vault_ball")
	Build.root(model, CFrame.new())
	model:SetAttribute("ParentEntityId", "landmark_spring_vault")
	model:SetAttribute("EventId", "event_vault")
	model:SetAttribute("MovementMode", "ServerKinematic")
	local diameter = Kit.Spec.BallDiameter
	local center = Vector3.new(0, diameter / 2, 0)
	local contact = Build.ball(model, "ContactSphere", diameter, CFrame.new(center), Kit.Palette.Cream)
	-- Players can walk beside/through the visual cargo; it cannot pin or shove avatars.
	contact.CanCollide = false
	contact.CanQuery = true
	local attachment = Instance.new("Attachment")
	attachment.Name = "RollEffectOrigin"
	attachment.Parent = contact
	model:SetAttribute("BallGeometryMode", "PrimitiveFallback")
	-- Preserve the previous primitive presentation when local mesh creation is
	-- refused. Its cap intersection edges remain faceted; this is a fallback,
	-- not evidence that smooth sectors are available in that environment.
	for index, color in
		{ Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold, Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold }
	do
		local angle = (index - 1) * math.pi / 3
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (diameter / 2 - 2.9)
		Build.ball(model, "ColorPanel", 6, CFrame.new(center + offset), color)
	end
	return model
end

return Ball
