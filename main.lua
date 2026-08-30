-- FlyControl.lua (versão melhorada: responsiva, minimizar->bubble com snap, salvar configs, hover animations, limpeza)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Defaults
local DEFAULT_FLY_SPEED = 60
local DEFAULT_SPRINT_MULT = 2.5
local TOGGLE_KEY = Enum.KeyCode.F

local SPEED_MIN, SPEED_MAX = 1, 1000
local JUMP_MIN, JUMP_MAX = 0, 3000
local WALK_MIN, WALK_MAX = 0, 3000

local FLY_SPEED = DEFAULT_FLY_SPEED
local SPRINT_MULT = DEFAULT_SPRINT_MULT
local jumpPowerValue = 50
local walkSpeedValue = 16

-- Flight state
local flying = false
local bodyVel, bodyGyro = nil, nil

-- Collision group (no collide while flying)
local COLLISION_GROUP = "FlyNoCollide"
local noCollideConn = nil
local modifiedParts = {} -- map part -> original CanCollide

-- UI state
local sliderDragging = nil
local minimized = false
local savedPanelPosition = nil

-- Connection tracking for cleanup
local connections = {}

local function addConn(conn)
	if conn then table.insert(connections, conn) end
end

local function cleanupConnections()
	for _, c in ipairs(connections) do
		if c and typeof(c) == "RBXScriptConnection" and c.Connected then
			c:Disconnect()
		end
	end
	connections = {}
end

-- Ensure collision group exists and set non-collidable rules
local function ensureCollisionGroup()
	pcall(function()
		local existing = PhysicsService:GetCollisionGroups()
		local found = false
		for _, g in ipairs(existing) do
			if g.name == COLLISION_GROUP then found = true break end
		end
		if not found then
			PhysicsService:CreateCollisionGroup(COLLISION_GROUP)
		end
		-- Make group not collide with Default and itself
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
	end)
end

local function setCharacterNoCollide(character)
	if not character then return end
	ensureCollisionGroup()
	modifiedParts = {}
	-- Apply to current parts
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			modifiedParts[desc] = desc.CanCollide
			desc.CanCollide = false
			pcall(function() PhysicsService:SetPartCollisionGroup(desc, COLLISION_GROUP) end)
		end
	end
	-- Watch for parts added later
	if noCollideConn then
		noCollideConn:Disconnect()
		noCollideConn = nil
	end
	noCollideConn = character.DescendantAdded:Connect(function(desc)
		if desc and desc:IsA("BasePart") then
			modifiedParts[desc] = desc.CanCollide
			desc.CanCollide = false
			pcall(function() PhysicsService:SetPartCollisionGroup(desc, COLLISION_GROUP) end)
		end
	end)
	addConn(noCollideConn)
end

local function restoreCharacterCollisions()
	if noCollideConn then
		noCollideConn:Disconnect()
		noCollideConn = nil
	end
	for part, original in pairs(modifiedParts) do
		if part and part.Parent then
			part.CanCollide = (original == nil) and true or original
			pcall(function() PhysicsService:SetPartCollisionGroup(part, "Default") end)
		end
	end
	modifiedParts = {}
end

-- Utility: save/load settings on Player attribute (session persistence)
local SETTINGS_ATTR = "FlyControl_Settings"
local function saveSettings()
	local ok, json = pcall(function()
		return HttpService:JSONEncode({
			flySpeed = FLY_SPEED,
			jump = jumpPowerValue,
			walk = walkSpeedValue,
			sprint = SPRINT_MULT
		})
	end)
	if ok then
		pcall(function() player:SetAttribute(SETTINGS_ATTR, json) end)
	end
end

local function loadSettings()
	local json = player:GetAttribute(SETTINGS_ATTR)
	if type(json) == "string" then
		local ok, tbl = pcall(function() return HttpService:JSONDecode(json) end)
		if ok and type(tbl) == "table" then
			FLY_SPEED = tonumber(tbl.flySpeed) or FLY_SPEED
			jumpPowerValue = tonumber(tbl.jump) or jumpPowerValue
			walkSpeedValue = tonumber(tbl.walk) or walkSpeedValue
			SPRINT_MULT = tonumber(tbl.sprint) or SPRINT_MULT
		end
	end
end

-- Clean up existing GUI
local oldGui = playerGui:FindFirstChild("FlyControlUI")
if oldGui then
	oldGui:Destroy()
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyControlUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Responsive panel (uses Scale so it adapts)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0.24, 0, 0.55, 0) -- 24% width, 55% height
panel.Position = UDim2.new(0.02, 0, 0.22, 0) -- small margin from left/top
panel.AnchorPoint = Vector2.new(0, 0)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, 14)

-- Title Bar
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(248, 248, 252)
titleBar.BorderSizePixel = 0

local titleCorner = Instance.new("UICorner", titleBar)
titleCorner.CornerRadius = UDim.new(0, 14)

local titleFill = Instance.new("Frame", titleBar)
titleFill.Size = UDim2.new(1, 0, 0, 16)
titleFill.Position = UDim2.new(0, 0, 1, -16)
titleFill.BackgroundColor3 = titleBar.BackgroundColor3
titleFill.BorderSizePixel = 0

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1, -96, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Painel de Controle"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(30, 30, 40)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true

-- Minimize / close controls
local minimizeButton = Instance.new("TextButton", titleBar)
minimizeButton.Size = UDim2.new(0, 36, 0, 36)
minimizeButton.Position = UDim2.new(1, -46, 0, 6)
minimizeButton.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "—"
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 20
minimizeButton.TextColor3 = Color3.fromRGB(80, 80, 90)
minimizeButton.AutoButtonColor = false
local minimizeCorner = Instance.new("UICorner", minimizeButton)
minimizeCorner.CornerRadius = UDim.new(0, 8)

-- Optional small icon area (for future icons)
local iconLabel = Instance.new("TextLabel", titleBar)
iconLabel.Size = UDim2.new(0, 28, 0, 28)
iconLabel.Position = UDim2.new(1, -94, 0, 10)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "✦"
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextSize = 18
iconLabel.TextColor3 = Color3.fromRGB(100, 100, 240)
iconLabel.TextScaled = true

-- CONTENT area
local content = Instance.new("Frame", panel)
content.Size = UDim2.new(1, -24, 1, -68)
content.Position = UDim2.new(0, 12, 0, 56)
content.BackgroundTransparency = 1

-- Use UIListLayout for neat stacking
local listLayout = Instance.new("UIListLayout", content)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 12)

local function createSection(titleText)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 72)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = 1

	local label = Instance.new("TextLabel", frame)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(70, 70, 90)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true

	return frame
end

-- Toggle fly button
local toggleButton = Instance.new("TextButton", content)
toggleButton.Name = "ToggleFly"
toggleButton.Size = UDim2.new(1, 0, 0, 44)
toggleButton.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
toggleButton.BorderSizePixel = 0
toggleButton.AutoButtonColor = false
toggleButton.Text = "▶  Ativar Fly  [F]"
toggleButton.Font = Enum.Font.GothamSemibold
toggleButton.TextSize = 14
toggleButton.TextColor3 = Color3.fromRGB(60, 60, 80)
toggleButton.TextScaled = true
local toggleCorner = Instance.new("UICorner", toggleButton)
toggleCorner.CornerRadius = UDim.new(0, 10)

-- Small status row
local statusRow = Instance.new("Frame", content)
statusRow.Size = UDim2.new(1, 0, 0, 24)
statusRow.BackgroundTransparency = 1
local statusDot = Instance.new("Frame", statusRow)
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(0, 0, 0, 7)
statusDot.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
statusDot.BorderSizePixel = 0
local statusDotCorner = Instance.new("UICorner", statusDot)
statusDotCorner.CornerRadius = UDim.new(1, 0)
local statusLabel = Instance.new("TextLabel", statusRow)
statusLabel.Size = UDim2.new(1, -18, 1, 0)
statusLabel.Position = UDim2.new(0, 18, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Idle"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextScaled = true

-- Slider creation (keeps behavior from original, but text scaled)
local function createSlider(yOrder, labelText, minValue, maxValue, defaultValue, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 56)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = yOrder

	local header = Instance.new("Frame", frame)
	header.Size = UDim2.new(1, 0, 0, 20)
	header.BackgroundTransparency = 1

	local label = Instance.new("TextLabel", header)
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(70, 70, 90)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true

	local numberLabel = Instance.new("TextLabel", header)
	numberLabel.Size = UDim2.new(0.4, -6, 1, 0)
	numberLabel.Position = UDim2.new(0.6, 6, 0, 0)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(defaultValue)
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.TextSize = 14
	numberLabel.TextColor3 = Color3.fromRGB(100, 100, 240)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Right
	numberLabel.TextScaled = true

	local track = Instance.new("Frame", frame)
	track.Name = labelText .. "Slider"
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Position = UDim2.new(0, 0, 0, 28)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	track.BorderSizePixel = 0
	track.Active = true
	local trackCorner = Instance.new("UICorner", track)
	trackCorner.CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 100, 240)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner", fill)
	fillCorner.CornerRadius = UDim.new(1, 0)
	local thumb = Instance.new("TextButton", track)
	thumb.Size = UDim2.new(0, 20, 0, 20)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new(0, 0, 0.5, 0)
	thumb.Text = ""
	thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	thumb.BorderSizePixel = 0
	thumb.AutoButtonColor = false
	thumb.ZIndex = 3
	local thumbCorner = Instance.new("UICorner", thumb)
	thumbCorner.CornerRadius = UDim.new(1, 0)

	local function setValueFromPercent(percent)
		percent = math.clamp(percent, 0, 1)
		local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
		numberLabel.Text = tostring(value)
		local trackWidth = track.AbsoluteSize.X
		local thumbX = percent * trackWidth
		thumb.Position = UDim2.new(0, thumbX, 0.5, 0)
		fill.Size = UDim2.new(0, thumbX, 1, 0)
		callback(value)
		saveSettings()
	end

	local function updateFromInput(input)
		local trackWidth = track.AbsoluteSize.X
		if trackWidth <= 0 then return end
		local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
		setValueFromPercent(percent)
	end

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = track
			updateFromInput(input)
		end
	end

	track.InputBegan:Connect(beginDrag)
	thumb.InputBegan:Connect(beginDrag)

	-- initialize from defaultValue
	task.defer(function()
		local percent = (defaultValue - minValue) / math.max(1, (maxValue - minValue))
		setValueFromPercent(percent)
	end)

	return frame
end

-- Create sliders
local flySlider = createSlider(2, "Fly Speed", SPEED_MIN, SPEED_MAX, FLY_SPEED, function(v) FLY_SPEED = v end)
flySlider.Parent = content
local jumpSlider = createSlider(3, "JumpPower", JUMP_MIN, JUMP_MAX, jumpPowerValue, function(v) jumpPowerValue = v; 
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.UseJumpPower = true; humanoid.JumpPower = jumpPowerValue end
end)
jumpSlider.Parent = content
local walkSlider = createSlider(4, "WalkSpeed", WALK_MIN, WALK_MAX, walkSpeedValue, function(v) walkSpeedValue = v;
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = walkSpeedValue end
end)
walkSlider.Parent = content

-- Status initialization
local function setUIFlying(state)
	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
	if state then
		TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = Color3.fromRGB(100,100,240), TextColor3 = Color3.fromRGB(255,255,255)}):Play()
		TweenService:Create(statusDot, tweenInfo, {BackgroundColor3 = Color3.fromRGB(100,220,130)}):Play()
		toggleButton.Text = "■  Desativar Fly  [F]"
		statusLabel.Text = "Flying"
		statusLabel.TextColor3 = Color3.fromRGB(80,180,110)
	else
		TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245,245,250), TextColor3 = Color3.fromRGB(60,60,80)}):Play()
		TweenService:Create(statusDot, tweenInfo, {BackgroundColor3 = Color3.fromRGB(200,200,210)}):Play()
		toggleButton.Text = "▶  Ativar Fly  [F]"
		statusLabel.Text = "Idle"
		statusLabel.TextColor3 = Color3.fromRGB(160,160,180)
	end
end

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function applyCharacterValues()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpPowerValue
		humanoid.WalkSpeed = walkSpeedValue
	end
end

-- Flight enable/disable (keeps BodyVelocity/BodyGyro)
local function getRootPart()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart")
end

local function enableFly()
	local root = getRootPart()
	-- remove previous
	if root:FindFirstChild("FlyVelocity") then root.FlyVelocity:Destroy() end
	if root:FindFirstChild("FlyGyro") then root.FlyGyro:Destroy() end

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.Name = "FlyVelocity"
	bodyVel.Velocity = Vector3.new(0,0,0)
	bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
	bodyVel.P = 1250
	bodyVel.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "FlyGyro"
	bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
	bodyGyro.D = 50
	bodyGyro.CFrame = root.CFrame
	bodyGyro.Parent = root

	local humanoid = getHumanoid()
	if humanoid then humanoid.PlatformStand = true end

	-- disable collisions
	local character = player.Character
	if character then setCharacterNoCollide(character) end

	flying = true
	setUIFlying(true)
end

local function disableFly()
	if bodyVel then bodyVel:Destroy(); bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end

	local humanoid = getHumanoid()
	if humanoid then humanoid.PlatformStand = false end

	restoreCharacterCollisions()

	flying = false
	setUIFlying(false)
end

local function toggleFly()
	if flying then disableFly() else enableFly() end
end

-- Input direction function
local function getInputDirection()
	local direction = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then direction += Vector3.new(0,0,-1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then direction += Vector3.new(0,0,1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then direction += Vector3.new(-1,0,0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then direction += Vector3.new(1,0,0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0,1,0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then direction += Vector3.new(0,-1,0) end
	return direction
end

-- Toggle bindings
toggleButton.Activated:Connect(toggleFly)
addConn(toggleButton.Activated)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == TOGGLE_KEY then toggleFly() end
end)
addConn(UserInputService.InputBegan)

-- Heartbeat movement
local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function()
	if not flying or not bodyVel or not bodyGyro then return end
	local root = getRootPart()
	local camera = workspace.CurrentCamera
	local inputDirection = getInputDirection()
	if not camera then return end
	local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local speed = sprinting and FLY_SPEED * SPRINT_MULT or FLY_SPEED

	if inputDirection.Magnitude > 0 then
		local worldDirection = camera.CFrame:VectorToWorldSpace(inputDirection).Unit
		bodyVel.Velocity = worldDirection * speed
		local lookDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
		if lookDirection.Magnitude > 0.01 then
			bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDirection)
		end
	else
		bodyVel.Velocity = bodyVel.Velocity * 0.85
	end
end)
addConn(heartbeatConn)

-- Character respawn handling
local charAddedConn
charAddedConn = player.CharacterAdded:Connect(function()
	-- reset state
	flying = false
	bodyVel = nil
	bodyGyro = nil
	restoreCharacterCollisions()
	task.wait(0.5)
	applyCharacterValues()
	setUIFlying(false)
end)
addConn(charAddedConn)

-- Slider dragging input handling
local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
	if not sliderDragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local track = sliderDragging
		local trackWidth = track.AbsoluteSize.X
		if trackWidth > 0 then
			local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
			local minValue, maxValue
			if track.Name == "Fly SpeedSlider" then minValue, maxValue = SPEED_MIN, SPEED_MAX
			elseif track.Name == "JumpPowerSlider" then minValue, maxValue = JUMP_MIN, JUMP_MAX
			else minValue, maxValue = WALK_MIN, WALK_MAX end
			local value = math.floor(minValue + math.clamp(percent,0,1) * (maxValue - minValue) + 0.5)
			-- Update by simulating the setValueFromPercent used on creation:
			for _, obj in ipairs(track.Parent:GetChildren()) do end -- (keeps compatibility)
			local percentValue = (value - minValue) / math.max(1, (maxValue - minValue))
			local thumb = track:FindFirstChildOfClass("TextButton")
			local fill = track:FindFirstChildOfClass("Frame")
			if thumb then thumb.Position = UDim2.new(0, percentValue * trackWidth, 0.5, 0) end
			if fill then fill.Size = UDim2.new(percentValue, 0, 1, 0) end
			-- update actual values
			if track.Name == "Fly SpeedSlider" then FLY_SPEED = value
			elseif track.Name == "JumpPowerSlider" then jumpPowerValue = value
			else walkSpeedValue = value end
			applyCharacterValues()
			saveSettings()
		end
	end
end)
addConn(inputChangedConn)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = nil
	end
end)
addConn(UserInputService.InputEnded)

-- Dragging panel (titleBar)
local draggingPanel = false
local dragStart, panelStart = nil, nil
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingPanel = true
		dragStart = input.Position
		panelStart = panel.Position
	end
end)
addConn(titleBar.InputBegan)
local panelChangedConn = UserInputService.InputChanged:Connect(function(input)
	if draggingPanel and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X, panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
	end
end)
addConn(panelChangedConn)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingPanel = false
	end
end)
addConn(UserInputService.InputEnded)

-- ===== Minimizar / bubble com snap =====
-- Bubble creation (pixel size, mas posicionada com base na viewport)
local bubble = Instance.new("TextButton", screenGui)
bubble.Name = "MinimizedBubble"
bubble.Size = UDim2.new(0, 64, 0, 64)
bubble.BackgroundColor3 = Color3.fromRGB(100,100,240)
bubble.Position = UDim2.new(panel.Position.X.Scale, panel.AbsolutePosition.X + panel.AbsoluteSize.X - 72, panel.Position.Y.Scale, panel.AbsolutePosition.Y + 12)
bubble.Text = "⦿"
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 32
bubble.TextColor3 = Color3.fromRGB(255,255,255)
bubble.BorderSizePixel = 0
bubble.Visible = false
bubble.AutoButtonColor = false
local bubbleCorner = Instance.new("UICorner", bubble)
bubbleCorner.CornerRadius = UDim.new(1, 0)

-- dragging bubble
local draggingBubble = false
local bubbleDragStart, bubbleStartPosition = nil, nil

bubble.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingBubble = true
		bubbleDragStart = input.Position
		bubbleStartPosition = bubble.Position
	end
end)
addConn(bubble.InputBegan)

local bubbleInputChangedConn = UserInputService.InputChanged:Connect(function(input)
	if draggingBubble and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - bubbleDragStart
		local newPos = UDim2.new(bubbleStartPosition.X.Scale, bubbleStartPosition.X.Offset + delta.X, bubbleStartPosition.Y.Scale, bubbleStartPosition.Y.Offset + delta.Y)
		-- clamp to screen
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
		local ox = math.clamp(newPos.X.Offset, 8, vp.X - bubble.AbsoluteSize.X - 8)
		local oy = math.clamp(newPos.Y.Offset, 8, vp.Y - bubble.AbsoluteSize.Y - 8)
		bubble.Position = UDim2.new(0, ox, 0, oy)
	end
end)
addConn(bubbleInputChangedConn)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if draggingBubble then
			-- snap to nearest edge
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local centerX = bubble.AbsolutePosition.X + bubble.AbsoluteSize.X/2
			local centerY = bubble.AbsolutePosition.Y + bubble.AbsoluteSize.Y/2
			local leftDist = centerX
			local rightDist = vp.X - centerX
			local topDist = centerY
			local bottomDist = vp.Y - centerY
			local minEdge = math.min(leftDist, rightDist, topDist, bottomDist)
			local targetX, targetY = bubble.AbsolutePosition.X, bubble.AbsolutePosition.Y
			if minEdge == leftDist then
				targetX = 8
			elseif minEdge == rightDist then
				targetX = vp.X - bubble.AbsoluteSize.X - 8
			elseif minEdge == topDist then
				targetY = 8
			else
				targetY = vp.Y - bubble.AbsoluteSize.Y - 8
			end
			TweenService:Create(bubble, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Position = UDim2.new(0, targetX, 0, targetY)}):Play()
		end
		draggingBubble = false
	end
end)
addConn(UserInputService.InputEnded)

-- Minimize / Restore functions
local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
local function minimizePanel()
	if minimized then return end
	savedPanelPosition = panel.Position
	-- position bubble close to panel corner
	local abs = panel.AbsolutePosition
	local bw = bubble.AbsoluteSize.X
	bubble.Position = UDim2.new(0, math.clamp(abs.X + panel.AbsoluteSize.X - bw - 8, 8, workspace.CurrentCamera.ViewportSize.X - bw - 8), 0, math.clamp(abs.Y + 8, 8, workspace.CurrentCamera.ViewportSize.Y - bubble.AbsoluteSize.Y - 8))
	bubble.Visible = true
	-- animate panel shrink then hide
	local shrink = TweenService:Create(panel, tweenInfo, {Size = UDim2.new(0.16,0,0.1,0)})
	shrink:Play()
	task.delay(0.18, function()
		panel.Visible = false
		panel.Size = UDim2.new(0.24,0,0.55,0) -- restore size so next open is normal
	end)
	minimized = true
end

local function restorePanel()
	if not minimized then return end
	panel.Position = savedPanelPosition or UDim2.new(0.02,0,0.22,0)
	panel.Visible = true
	bubble.Visible = false
	minimized = false
end

minimizeButton.Activated:Connect(function() 
	if minimized then restorePanel() else minimizePanel() end
end)
addConn(minimizeButton.Activated)

bubble.Activated:Connect(function() restorePanel() end)
addConn(bubble.Activated)

-- Hover animations for important buttons (toggle & minimize)
local function addHoverTweens(btn)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = btn.BackgroundColor3:Lerp(Color3.fromRGB(220,220,230), 0.35)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = btn.BackgroundColor3}):Play()
	end)
end
addHoverTweens(toggleButton)
addHoverTweens(minimizeButton)
addHoverTweens(bubble)

-- Save settings when slider values are changed by using saveSettings() already called in slider callbacks

-- Load settings on start
loadSettings()
applyCharacterValues()

-- UI cleanup on destroy
screenGui.Destroying:Connect(function()
	-- restore collisions if needed
	restoreCharacterCollisions()
	cleanupConnections()
end)

-- Final: expose some convenience to console (optional)
_G.FlyControl = {
	Enable = enableFly,
	Disable = disableFly,
	Toggle = toggleFly,
	IsFlying = function() return flying end,
	SaveSettings = saveSettings,
	LoadSettings = loadSettings
}
