local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

if getgenv().destroyHub then
	getgenv().destroyHub()
end

local SilentAim = {
	Settings = {
		Enabled = true,
		HitPart = "Head",
		HitChance = 100,
		SkipUnarmed = true,
		FieldOfView = {
			Enabled = true,
			Radius = 150,
			Draw = true,
			Color = Color3.fromRGB(255, 255, 255),
		},
	},
}
getgenv().SilentAim = SilentAim

local ESP = {
	Settings = {
		Enabled = false,
		ShowAllies = false,
		ShowDistance = true,
		ShowWeapon = true,
		ShowTracers = true,
		ShowHealthNumber = true,
		ShowO5 = true,
		BoxThickness = 1,
		TextSize = 13,
		BoxPadding = 4,
		MaxDistance = 500,
		MaxPlayers = 10,
		TracerOrigin = "Bottom",
		MinimumBrightness = 0.35,
		EnemyColor = Color3.fromRGB(200, 30, 30),
		TracerColor = Color3.fromRGB(255, 255, 255),
		InfiltratorColor = Color3.fromRGB(50, 160, 50),
	},
}
getgenv().ESP = ESP

local FoundationTeams = {
	["Scientific Department"] = true,
	["Security Department"] = true,
	["Mobile Task Force"] = true,
	["Intelligence Agency"] = true,
	["Internal Security Department"] = true,
	["Rapid Response Team"] = true,
	["Medical Department"] = true,
	["Administrative Department"] = true,
}

local HostileTeams = {
	["Chaos Insurgency"] = true,
	["Class - D"] = true,
}

local UnarmedTeams = {
	["Scientific Department"] = true,
	["Medical Department"] = true,
}

local ColorPresets = {
	["Red"]    = Color3.fromRGB(220, 50, 50),
	["Green"]  = Color3.fromRGB(50, 200, 80),
	["Blue"]   = Color3.fromRGB(50, 120, 220),
	["White"]  = Color3.fromRGB(255, 255, 255),
	["Yellow"] = Color3.fromRGB(230, 200, 50),
	["Cyan"]   = Color3.fromRGB(50, 200, 220),
	["Purple"] = Color3.fromRGB(160, 50, 220),
	["Orange"] = Color3.fromRGB(230, 130, 50),
}
local ColorPresetNames = { "Red", "Green", "Blue", "White", "Yellow", "Cyan", "Purple", "Orange" }

local HEAD_TOP_OFFSET = 2.06
local FEET_BOTTOM_OFFSET = 3.02
local CHARACTER_WIDTH_RATIO = 0.394

local enemyCache = {}

local function invalidateEnemyCache(player)
	enemyCache[player] = nil
end

local function isInfiltrator(player)
	if player == localPlayer then return false end
	local lastRoleplayTeam = player:GetAttribute("LastRoleplayTeam")
	if not lastRoleplayTeam then return false end
	if not HostileTeams[lastRoleplayTeam] then return false end
	local currentTeam = player.Team
	if not currentTeam then return false end
	return FoundationTeams[currentTeam.Name] == true
end

local function isEnemy(player)
	if player == localPlayer then return false end
	if isInfiltrator(player) then return true end
	local localTeam = localPlayer.Team
	local targetTeam = player.Team
	if not localTeam or not targetTeam then return false end
	if HostileTeams[localTeam.Name] then
		return FoundationTeams[targetTeam.Name] == true
	end
	if FoundationTeams[localTeam.Name] then
		return HostileTeams[targetTeam.Name] == true
	end
	return false
end

local function getCachedIsEnemy(player)
	if enemyCache[player] == nil then
		enemyCache[player] = isEnemy(player)
	end
	return enemyCache[player]
end

local function getPlayerColor(player)
	if isInfiltrator(player) then
		return getgenv().ESP.Settings.InfiltratorColor
	end
	if isEnemy(player) then
		return getgenv().ESP.Settings.EnemyColor
	end
	local team = player.Team
	if not team then return Color3.fromRGB(255, 255, 255) end
	local color = team.TeamColor.Color
	local minimumBrightness = getgenv().ESP.Settings.MinimumBrightness
	local perceivedBrightness = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	if perceivedBrightness < minimumBrightness then
		local boostFactor = minimumBrightness / math.max(perceivedBrightness, 0.001)
		color = Color3.new(
			math.min(color.R * boostFactor, 1),
			math.min(color.G * boostFactor, 1),
			math.min(color.B * boostFactor, 1)
		)
	end
	return color
end

local function getMuzzlePosition()
	local character = localPlayer.Character
	if not character then return nil end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool then return nil end
	local handle = tool:FindFirstChild("Handle")
	return handle and handle.Position or nil
end

local function getNearestTarget()
	local camera = workspace.CurrentCamera
	local mousePosition = UserInputService:GetMouseLocation()
	local silentAimSettings = getgenv().SilentAim.Settings
	local fieldOfViewSettings = silentAimSettings.FieldOfView
	local maximumScreenDistance = fieldOfViewSettings.Enabled and fieldOfViewSettings.Radius or math.huge

	local nearestArmed = nil
	local nearestArmedDistance = maximumScreenDistance
	local nearestUnarmed = nil
	local nearestUnarmedDistance = maximumScreenDistance

	for _, player in ipairs(Players:GetPlayers()) do
		if not getCachedIsEnemy(player) then continue end
		local character = player.Character
		if not character then continue end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end
		local screenPosition, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		if not onScreen then continue end
		local screenDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude
		local playerIsUnarmed = silentAimSettings.SkipUnarmed
			and not isInfiltrator(player)
			and player.Team ~= nil
			and UnarmedTeams[player.Team.Name] == true
		if playerIsUnarmed then
			if screenDistance < nearestUnarmedDistance then
				nearestUnarmed = player
				nearestUnarmedDistance = screenDistance
			end
		else
			if screenDistance < nearestArmedDistance then
				nearestArmed = player
				nearestArmedDistance = screenDistance
			end
		end
	end

	return nearestArmed or nearestUnarmed
end

getgenv().getNearestTarget = getNearestTarget

local fieldOfViewCircle = Drawing.new("Circle")
fieldOfViewCircle.Radius = SilentAim.Settings.FieldOfView.Radius
fieldOfViewCircle.Color = SilentAim.Settings.FieldOfView.Color
fieldOfViewCircle.Thickness = 1
fieldOfViewCircle.Filled = false
fieldOfViewCircle.NumSides = 64
fieldOfViewCircle.Visible = false

if not getgenv().SilentAim_Hooked then
	local controller = localPlayer.PlayerScripts:WaitForChild("Controller", 2)
	if controller then
		local env = getsenv(controller)
		local realBulletHit
		realBulletHit = hookfunction(env.BulletHit, newcclosure(function(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			if activeCast.UserData._SilentAimProcessed then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			activeCast.UserData._SilentAimProcessed = true
			local silentAimSettings = getgenv().SilentAim and getgenv().SilentAim.Settings
			if not silentAimSettings or not silentAimSettings.Enabled then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			if silentAimSettings.HitChance < 100 and math.random(1, 100) > silentAimSettings.HitChance then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			local target = getgenv().getNearestTarget and getgenv().getNearestTarget()
			if not target or not target.Character then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			local hitPart = target.Character:FindFirstChild(silentAimSettings.HitPart)
				or target.Character:FindFirstChild("HumanoidRootPart")
			if not hitPart then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			local muzzlePosition = getMuzzlePosition()
			if not muzzlePosition then
				return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
			end
			local aimDirection = (hitPart.Position - muzzlePosition).Unit
			local aimResult = workspace:Raycast(muzzlePosition, aimDirection * 2048, activeCast.RayInfo.Parameters)
			if aimResult and aimResult.Instance and aimResult.Instance:IsDescendantOf(target.Character) then
				return realBulletHit(activeCast, aimResult, velocity, cosmeticBullet, isPiercing)
			end
			return realBulletHit(activeCast, raycastResult, velocity, cosmeticBullet, isPiercing)
		end))
		getgenv().SilentAim_Hooked = true
	end
end

local playerDrawings = {}
local espWasEnabled = false
local playerAddedConnection
local playerRemovingConnection

local function hideAllDrawings(drawings)
	for _, object in pairs(drawings.visuals) do
		object.Visible = false
	end
end

local function createPlayerDrawings(player)
	if playerDrawings[player] then return end
	local visuals = {}
	local connections = {}

	for index = 1, 8 do
		local cornerLine = Drawing.new("Line")
		cornerLine.Thickness = ESP.Settings.BoxThickness
		cornerLine.Visible = false
		visuals["Corner" .. index] = cornerLine
	end

	local nameLabel = Drawing.new("Text")
	nameLabel.Size = ESP.Settings.TextSize
	nameLabel.Outline = true
	nameLabel.Center = true
	nameLabel.Visible = false
	visuals.NameLabel = nameLabel

	local subdivisionLabel = Drawing.new("Text")
	subdivisionLabel.Size = ESP.Settings.TextSize - 2
	subdivisionLabel.Color = Color3.fromRGB(200, 200, 200)
	subdivisionLabel.Outline = true
	subdivisionLabel.Center = true
	subdivisionLabel.Visible = false
	visuals.SubdivisionLabel = subdivisionLabel

	local o5Label = Drawing.new("Text")
	o5Label.Size = ESP.Settings.TextSize - 2
	o5Label.Color = Color3.fromRGB(255, 215, 0)
	o5Label.Outline = true
	o5Label.Center = true
	o5Label.Visible = false
	visuals.O5Label = o5Label

	local healthBackground = Drawing.new("Line")
	healthBackground.Thickness = 3
	healthBackground.Color = Color3.fromRGB(50, 50, 50)
	healthBackground.Visible = false
	visuals.HealthBackground = healthBackground

	local healthFill = Drawing.new("Line")
	healthFill.Thickness = 3
	healthFill.Visible = false
	visuals.HealthFill = healthFill

	local healthNumberLabel = Drawing.new("Text")
	healthNumberLabel.Size = ESP.Settings.TextSize - 2
	healthNumberLabel.Color = Color3.fromRGB(220, 220, 220)
	healthNumberLabel.Outline = true
	healthNumberLabel.Center = false
	healthNumberLabel.Visible = false
	visuals.HealthNumberLabel = healthNumberLabel

	local distanceLabel = Drawing.new("Text")
	distanceLabel.Size = ESP.Settings.TextSize - 2
	distanceLabel.Color = Color3.fromRGB(180, 180, 180)
	distanceLabel.Outline = true
	distanceLabel.Center = true
	distanceLabel.Visible = false
	visuals.DistanceLabel = distanceLabel

	local weaponLabel = Drawing.new("Text")
	weaponLabel.Size = ESP.Settings.TextSize - 2
	weaponLabel.Color = Color3.fromRGB(255, 200, 100)
	weaponLabel.Outline = true
	weaponLabel.Center = true
	weaponLabel.Visible = false
	visuals.WeaponLabel = weaponLabel

	local tracerLine = Drawing.new("Line")
	tracerLine.Thickness = 1
	tracerLine.Visible = false
	visuals.TracerLine = tracerLine

	local cachedSubdivision = player:GetAttribute("Subdivision") or ""
	local cachedIsO5 = player:GetAttribute("O5") == true

	table.insert(connections, player:GetPropertyChangedSignal("Team"):Connect(function()
		invalidateEnemyCache(player)
		hideAllDrawings({ visuals = visuals })
	end))
	table.insert(connections, player:GetAttributeChangedSignal("Subdivision"):Connect(function()
		cachedSubdivision = player:GetAttribute("Subdivision") or ""
	end))
	table.insert(connections, player:GetAttributeChangedSignal("O5"):Connect(function()
		cachedIsO5 = player:GetAttribute("O5") == true
	end))
	table.insert(connections, player:GetAttributeChangedSignal("LastRoleplayTeam"):Connect(function()
		invalidateEnemyCache(player)
	end))

	playerDrawings[player] = {
		visuals = visuals,
		connections = connections,
		getCachedSubdivision = function() return cachedSubdivision end,
		getCachedIsO5 = function() return cachedIsO5 end,
	}
end

local function removePlayerDrawings(player)
	local drawings = playerDrawings[player]
	if not drawings then return end
	for _, object in pairs(drawings.visuals) do
		object:Remove()
	end
	for _, connection in ipairs(drawings.connections) do
		connection:Disconnect()
	end
	enemyCache[player] = nil
	playerDrawings[player] = nil
end

getgenv().destroyHub = function()
	RunService:UnbindFromRenderStep("HubRender")
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
	end
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
	end
	fieldOfViewCircle:Remove()
	for _, drawings in pairs(playerDrawings) do
		for _, object in pairs(drawings.visuals) do
			object:Remove()
		end
		for _, connection in ipairs(drawings.connections) do
			connection:Disconnect()
		end
	end
	local coreGui = game:GetService("CoreGui")
	local puppyGui = coreGui:FindFirstChild("SCP:RP")
		or localPlayer.PlayerGui:FindFirstChild("SCP:RP")
	if puppyGui and puppyGui.Parent then
		puppyGui:Destroy()
	end
	getgenv().destroyHub = nil
end

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= localPlayer then
		createPlayerDrawings(player)
	end
end

playerAddedConnection = Players.PlayerAdded:Connect(function(player)
	createPlayerDrawings(player)
end)

playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
	removePlayerDrawings(player)
end)

RunService:BindToRenderStep("HubRender", Enum.RenderPriority.Last.Value, function()
	local camera = workspace.CurrentCamera
	local viewportSize = camera.ViewportSize
	local mousePosition = UserInputService:GetMouseLocation()
	local localCharacter = localPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	local silentAimSettings = getgenv().SilentAim.Settings
	local espSettings = getgenv().ESP.Settings

	fieldOfViewCircle.Radius = silentAimSettings.FieldOfView.Radius
	fieldOfViewCircle.Position = mousePosition
	fieldOfViewCircle.Color = silentAimSettings.FieldOfView.Color
	fieldOfViewCircle.Visible = silentAimSettings.FieldOfView.Enabled
		and silentAimSettings.FieldOfView.Draw
		and silentAimSettings.Enabled

	if not espSettings.Enabled then
		if espWasEnabled then
			for _, drawings in pairs(playerDrawings) do
				hideAllDrawings(drawings)
			end
			espWasEnabled = false
		end
		return
	end
	espWasEnabled = true

	local visibleEnemies = {}
	local visibleAllies = {}

	for player, drawings in pairs(playerDrawings) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not localRoot then continue end
		local distance = (rootPart.Position - localRoot.Position).Magnitude
		if distance > espSettings.MaxDistance then continue end
		if getCachedIsEnemy(player) then
			table.insert(visibleEnemies, { player = player, distance = distance })
		elseif espSettings.ShowAllies then
			table.insert(visibleAllies, { player = player, distance = distance })
		end
	end

	table.sort(visibleEnemies, function(a, b) return a.distance < b.distance end)

	local allowedPlayers = {}
	for index = 1, math.min(#visibleEnemies, espSettings.MaxPlayers) do
		local entry = visibleEnemies[index]
		allowedPlayers[entry.player] = entry.distance
	end
	for _, entry in ipairs(visibleAllies) do
		allowedPlayers[entry.player] = entry.distance
	end

	for player, drawings in pairs(playerDrawings) do
		if not allowedPlayers[player] then
			hideAllDrawings(drawings)
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not rootPart then
			hideAllDrawings(drawings)
			continue
		end
		local hrpScreenPosition, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		if not onScreen then
			hideAllDrawings(drawings)
			continue
		end

		local topScreenPosition = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, HEAD_TOP_OFFSET, 0))
		local bottomScreenPosition = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, -FEET_BOTTOM_OFFSET, 0))
		local visuals = drawings.visuals
		local centerX = hrpScreenPosition.X
		local boxPadding = espSettings.BoxPadding
		local boxTop = topScreenPosition.Y - boxPadding
		local boxBottom = bottomScreenPosition.Y + boxPadding
		local boxHeight = boxBottom - boxTop
		local boxWidth = boxHeight * CHARACTER_WIDTH_RATIO
		local boxLeft = centerX - boxWidth / 2
		local boxRight = centerX + boxWidth / 2
		local armLength = math.min(boxWidth, boxHeight) * 0.25
		local boxColor = getPlayerColor(player)
		local boxThickness = espSettings.BoxThickness

		visuals.Corner1.From = Vector2.new(boxLeft, boxTop)
		visuals.Corner1.To = Vector2.new(boxLeft + armLength, boxTop)
		visuals.Corner1.Color = boxColor
		visuals.Corner1.Thickness = boxThickness
		visuals.Corner1.Visible = true
		visuals.Corner2.From = Vector2.new(boxLeft, boxTop)
		visuals.Corner2.To = Vector2.new(boxLeft, boxTop + armLength)
		visuals.Corner2.Color = boxColor
		visuals.Corner2.Thickness = boxThickness
		visuals.Corner2.Visible = true
		visuals.Corner3.From = Vector2.new(boxRight - armLength, boxTop)
		visuals.Corner3.To = Vector2.new(boxRight, boxTop)
		visuals.Corner3.Color = boxColor
		visuals.Corner3.Thickness = boxThickness
		visuals.Corner3.Visible = true
		visuals.Corner4.From = Vector2.new(boxRight, boxTop)
		visuals.Corner4.To = Vector2.new(boxRight, boxTop + armLength)
		visuals.Corner4.Color = boxColor
		visuals.Corner4.Thickness = boxThickness
		visuals.Corner4.Visible = true
		visuals.Corner5.From = Vector2.new(boxLeft, boxBottom)
		visuals.Corner5.To = Vector2.new(boxLeft + armLength, boxBottom)
		visuals.Corner5.Color = boxColor
		visuals.Corner5.Thickness = boxThickness
		visuals.Corner5.Visible = true
		visuals.Corner6.From = Vector2.new(boxLeft, boxBottom - armLength)
		visuals.Corner6.To = Vector2.new(boxLeft, boxBottom)
		visuals.Corner6.Color = boxColor
		visuals.Corner6.Thickness = boxThickness
		visuals.Corner6.Visible = true
		visuals.Corner7.From = Vector2.new(boxRight - armLength, boxBottom)
		visuals.Corner7.To = Vector2.new(boxRight, boxBottom)
		visuals.Corner7.Color = boxColor
		visuals.Corner7.Thickness = boxThickness
		visuals.Corner7.Visible = true
		visuals.Corner8.From = Vector2.new(boxRight, boxBottom - armLength)
		visuals.Corner8.To = Vector2.new(boxRight, boxBottom)
		visuals.Corner8.Color = boxColor
		visuals.Corner8.Thickness = boxThickness
		visuals.Corner8.Visible = true

		local subdivision = drawings.getCachedSubdivision()
		local isO5 = drawings.getCachedIsO5()

		visuals.NameLabel.Text = player.Name
		visuals.NameLabel.Size = espSettings.TextSize
		visuals.NameLabel.Color = boxColor
		visuals.NameLabel.Position = Vector2.new(centerX, boxTop - 15)
		visuals.NameLabel.Visible = true

		if subdivision ~= "" then
			visuals.SubdivisionLabel.Text = "[" .. subdivision .. "]"
			visuals.SubdivisionLabel.Size = espSettings.TextSize - 2
			visuals.SubdivisionLabel.Position = Vector2.new(centerX, boxTop - 29)
			visuals.SubdivisionLabel.Visible = true
		else
			visuals.SubdivisionLabel.Visible = false
		end

		if espSettings.ShowO5 and isO5 then
			local o5LabelTop = boxTop - (subdivision ~= "" and 42 or 29)
			visuals.O5Label.Text = "◆ O5 ◆"
			visuals.O5Label.Size = espSettings.TextSize - 2
			visuals.O5Label.Position = Vector2.new(centerX, o5LabelTop)
			visuals.O5Label.Visible = true
		else
			visuals.O5Label.Visible = false
		end

		local healthPercent = humanoid.MaxHealth > 0 and (humanoid.Health / humanoid.MaxHealth) or 0
		local healthBarX = boxLeft - 5
		local healthBarFillY = boxBottom - (boxHeight * healthPercent)

		visuals.HealthBackground.From = Vector2.new(healthBarX, boxTop)
		visuals.HealthBackground.To = Vector2.new(healthBarX, boxBottom)
		visuals.HealthBackground.Visible = true

		visuals.HealthFill.From = Vector2.new(healthBarX, healthBarFillY)
		visuals.HealthFill.To = Vector2.new(healthBarX, boxBottom)
		visuals.HealthFill.Color = Color3.new(
			math.min(2 * (1 - healthPercent), 1),
			math.min(2 * healthPercent, 1),
			0
		)
		visuals.HealthFill.Visible = true

		if espSettings.ShowHealthNumber then
			visuals.HealthNumberLabel.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
			visuals.HealthNumberLabel.Size = espSettings.TextSize - 2
			visuals.HealthNumberLabel.Position = Vector2.new(boxLeft + 2, boxTop + boxHeight * 0.5 - 6)
			visuals.HealthNumberLabel.Visible = true
		else
			visuals.HealthNumberLabel.Visible = false
		end

		local distance = allowedPlayers[player]

		if espSettings.ShowDistance then
			visuals.DistanceLabel.Text = math.floor(distance) .. " studs"
			visuals.DistanceLabel.Size = espSettings.TextSize - 2
			visuals.DistanceLabel.Position = Vector2.new(centerX, boxBottom + 4)
			visuals.DistanceLabel.Visible = true
		else
			visuals.DistanceLabel.Visible = false
		end

		if espSettings.ShowWeapon then
			local tool = character:FindFirstChildWhichIsA("Tool")
			if tool then
				local weaponLabelY = espSettings.ShowDistance and (boxBottom + 17) or (boxBottom + 4)
				visuals.WeaponLabel.Text = tool.Name
				visuals.WeaponLabel.Size = espSettings.TextSize - 2
				visuals.WeaponLabel.Position = Vector2.new(centerX, weaponLabelY)
				visuals.WeaponLabel.Visible = true
			else
				visuals.WeaponLabel.Visible = false
			end
		else
			visuals.WeaponLabel.Visible = false
		end

		if espSettings.ShowTracers then
			local tracerOrigin
			if espSettings.TracerOrigin == "Top" then
				tracerOrigin = Vector2.new(viewportSize.X / 2, 0)
			elseif espSettings.TracerOrigin == "Center" then
				tracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
			else
				tracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y)
			end
			visuals.TracerLine.From = tracerOrigin
			visuals.TracerLine.To = Vector2.new(centerX, boxBottom)
			visuals.TracerLine.Color = espSettings.TracerColor
			visuals.TracerLine.Visible = true
		else
			visuals.TracerLine.Visible = false
		end
	end
end)

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/imagoodpersond/puppyware/main/lib"))()
local window = library:new({ name = "SCP:RP", accent = Color3.fromRGB(0, 180, 165), textsize = 13 })

local combatTab = window:page({ name = "Combat" })
local visualsTab = window:page({ name = "Visuals" })

local silentAimSection = combatTab:section({ name = "Silent Aim", side = "left", size = 200 })
local fieldOfViewSection = combatTab:section({ name = "Field of View", side = "right", size = 150 })

silentAimSection:toggle({ name = "Enabled", def = SilentAim.Settings.Enabled, callback = function(value)
	getgenv().SilentAim.Settings.Enabled = value
end })
silentAimSection:dropdown({ name = "Hit Part", def = SilentAim.Settings.HitPart, max = 3, options = { "Head", "UpperTorso", "HumanoidRootPart" }, callback = function(value)
	getgenv().SilentAim.Settings.HitPart = value
end })
silentAimSection:slider({ name = "Hit Chance", def = SilentAim.Settings.HitChance, min = 1, max = 100, rounding = true, callback = function(value)
	getgenv().SilentAim.Settings.HitChance = value
end })
silentAimSection:toggle({ name = "Skip Unarmed", def = SilentAim.Settings.SkipUnarmed, callback = function(value)
	getgenv().SilentAim.Settings.SkipUnarmed = value
end })

fieldOfViewSection:toggle({ name = "Enabled", def = SilentAim.Settings.FieldOfView.Enabled, callback = function(value)
	getgenv().SilentAim.Settings.FieldOfView.Enabled = value
end })
fieldOfViewSection:toggle({ name = "Draw Circle", def = SilentAim.Settings.FieldOfView.Draw, callback = function(value)
	getgenv().SilentAim.Settings.FieldOfView.Draw = value
end })
fieldOfViewSection:slider({ name = "Radius", def = SilentAim.Settings.FieldOfView.Radius, min = 10, max = 500, rounding = true, callback = function(value)
	getgenv().SilentAim.Settings.FieldOfView.Radius = value
end })
fieldOfViewSection:dropdown({ name = "Circle Color", def = "White", max = 8, options = ColorPresetNames, callback = function(value)
	getgenv().SilentAim.Settings.FieldOfView.Color = ColorPresets[value]
	fieldOfViewCircle.Color = ColorPresets[value]
end })

local espSection = visualsTab:section({ name = "ESP", side = "left", size = 200 })
local tracerSection = visualsTab:section({ name = "Tracers", side = "left", size = 200 })
local boxSection = visualsTab:section({ name = "Box", side = "right", size = 200 })

espSection:toggle({ name = "Enabled", def = ESP.Settings.Enabled, callback = function(value)
	getgenv().ESP.Settings.Enabled = value
end })
espSection:toggle({ name = "Show Allies", def = ESP.Settings.ShowAllies, callback = function(value)
	getgenv().ESP.Settings.ShowAllies = value
end })
espSection:toggle({ name = "Show Distance", def = ESP.Settings.ShowDistance, callback = function(value)
	getgenv().ESP.Settings.ShowDistance = value
end })
espSection:toggle({ name = "Show Weapon", def = ESP.Settings.ShowWeapon, callback = function(value)
	getgenv().ESP.Settings.ShowWeapon = value
end })
espSection:toggle({ name = "Show Health", def = ESP.Settings.ShowHealthNumber, callback = function(value)
	getgenv().ESP.Settings.ShowHealthNumber = value
end })
espSection:toggle({ name = "Show O5", def = ESP.Settings.ShowO5, callback = function(value)
	getgenv().ESP.Settings.ShowO5 = value
end })
espSection:dropdown({ name = "Enemy Color", def = "Red", max = 8, options = ColorPresetNames, callback = function(value)
	getgenv().ESP.Settings.EnemyColor = ColorPresets[value]
end })

tracerSection:toggle({ name = "Enabled", def = ESP.Settings.ShowTracers, callback = function(value)
	getgenv().ESP.Settings.ShowTracers = value
end })
tracerSection:dropdown({ name = "Origin", def = ESP.Settings.TracerOrigin, max = 3, options = { "Top", "Center", "Bottom" }, callback = function(value)
	getgenv().ESP.Settings.TracerOrigin = value
end })
tracerSection:dropdown({ name = "Color", def = "White", max = 8, options = ColorPresetNames, callback = function(value)
	getgenv().ESP.Settings.TracerColor = ColorPresets[value]
end })

boxSection:slider({ name = "Max Enemies", def = ESP.Settings.MaxPlayers, min = 1, max = 20, rounding = true, callback = function(value)
	getgenv().ESP.Settings.MaxPlayers = value
end })
boxSection:slider({ name = "Max Distance", def = ESP.Settings.MaxDistance, min = 50, max = 2000, rounding = true, callback = function(value)
	getgenv().ESP.Settings.MaxDistance = value
end })
boxSection:slider({ name = "Box Thickness", def = ESP.Settings.BoxThickness, min = 1, max = 5, rounding = true, callback = function(value)
	getgenv().ESP.Settings.BoxThickness = value
end })
boxSection:slider({ name = "Text Size", def = ESP.Settings.TextSize, min = 8, max = 20, rounding = true, callback = function(value)
	getgenv().ESP.Settings.TextSize = value
end })
