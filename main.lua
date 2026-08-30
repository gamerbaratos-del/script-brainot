local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FLY_SPEED = 60
local SPRINT_MULT = 2.5
local TOGGLE_KEY = Enum.KeyCode.F

local SPEED_MIN = 1
local SPEED_MAX = 1000

local JUMP_MIN = 0
local JUMP_MAX = 3000
local WALK_MIN = 0
local WALK_MAX = 3000

local jumpPowerValue = 50
local walkSpeedValue = 16

local flying = false
local bodyVel = nil
local bodyGyro = nil
local sliderDragging = nil

local oldGui = playerGui:FindFirstChild("FlyControlUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyControlUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 280, 0, 370)
panel.Position = UDim2.new(0, 20, 0.5, -185)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(248, 248, 252)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = titleBar

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 16)
titleFill.Position = UDim2.new(0, 0, 1, -16)
titleFill.BackgroundColor3 = Color3.fromRGB(248, 248, 252)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Painel de Controle"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(30, 30, 40)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local function createLabel(text, position, size)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(70, 70, 90)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel
	return label
end

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleFly"
toggleButton.Size = UDim2.new(1, -30, 0, 40)
toggleButton.Position = UDim2.new(0, 15, 0, 55)
toggleButton.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
toggleButton.BorderSizePixel = 0
toggleButton.AutoButtonColor = false
toggleButton.Text = "▶  Ativar Fly  [F]"
toggleButton.Font = Enum.Font.GothamSemibold
toggleButton.TextSize = 13
toggleButton.TextColor3 = Color3.fromRGB(60, 60, 80)
toggleButton.Parent = panel

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = toggleButton

local function createSlider(yPosition, labelText, minValue, maxValue, defaultValue, callback)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -30, 0, 24)
	header.Position = UDim2.new(0, 15, 0, yPosition)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.5, 0, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = labelText
	valueLabel.Font = Enum.Font.GothamSemibold
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = header

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0.5, 0, 1, 0)
	numberLabel.Position = UDim2.new(0.5, 0, 0, 0)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(defaultValue)
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.TextSize = 12
	numberLabel.TextColor3 = Color3.fromRGB(100, 100, 240)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Right
	numberLabel.Parent = header

	local track = Instance.new("Frame")
	track.Name = labelText .. "Slider"
	track.Size = UDim2.new(1, -30, 0, 8)
	track.Position = UDim2.new(0, 15, 0, yPosition + 30)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	track.BorderSizePixel = 0
	track.Active = true
	track.Parent = panel

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 100, 240)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local thumb = Instance.new("TextButton")
	thumb.Size = UDim2.new(0, 20, 0, 20)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new(0, 0, 0.5, 0)
	thumb.Text = ""
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.AutoButtonColor = false
	thumb.ZIndex = 3
	thumb.Parent = track

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	local function setValueFromPercent(percent)
		percent = math.clamp(percent, 0, 1)

		local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
		numberLabel.Text = tostring(value)

		local trackWidth = track.AbsoluteSize.X
		local thumbX = percent * trackWidth

		thumb.Position = UDim2.new(0, thumbX, 0.5, 0)
		fill.Size = UDim2.new(0, thumbX, 1, 0)

		callback(value)
	end

	local function updateFromInput(input)
		local trackWidth = track.AbsoluteSize.X
		if trackWidth <= 0 then
			return
		end

		local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
		setValueFromPercent(percent)
	end

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = track
			updateFromInput(input)
		end
	end

	track.InputBegan:Connect(beginDrag)
	thumb.InputBegan:Connect(beginDrag)

	local percent = (defaultValue - minValue) / (maxValue - minValue)
	task.defer(function()
		setValueFromPercent(percent)
	end)
end

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 15, 0, 342)
statusDot.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
statusDot.BorderSizePixel = 0
statusDot.Parent = panel

local statusDotCorner = Instance.new("UICorner")
statusDotCorner.CornerRadius = UDim.new(1, 0)
statusDotCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 20)
statusLabel.Position = UDim2.new(0, 30, 0, 336)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Idle"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = panel

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

createSlider(110, "Fly Speed", SPEED_MIN, SPEED_MAX, FLY_SPEED, function(value)
	FLY_SPEED = value
end)

createSlider(175, "JumpPower", JUMP_MIN, JUMP_MAX, jumpPowerValue, function(value)
	jumpPowerValue = value
	applyCharacterValues()
end)

createSlider(240, "WalkSpeed", WALK_MIN, WALK_MAX, walkSpeedValue, function(value)
	walkSpeedValue = value
	applyCharacterValues()
end)

UserInputService.InputChanged:Connect(function(input)
	if not sliderDragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local track = sliderDragging
		local trackWidth = track.AbsoluteSize.X

		if trackWidth > 0 then
			local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
			local minValue
			local maxValue
			local defaultValue

			if track.Name == "Fly SpeedSlider" then
				minValue, maxValue, defaultValue = SPEED_MIN, SPEED_MAX, FLY_SPEED
			elseif track.Name == "JumpPowerSlider" then
				minValue, maxValue, defaultValue = JUMP_MIN, JUMP_MAX, jumpPowerValue
			else
				minValue, maxValue, defaultValue = WALK_MIN, WALK_MAX, walkSpeedValue
			end

			local value = math.floor(minValue + math.clamp(percent, 0, 1) * (maxValue - minValue) + 0.5)

			if track.Name == "Fly SpeedSlider" then
				FLY_SPEED = value
			elseif track.Name == "JumpPowerSlider" then
				jumpPowerValue = value
			else
				walkSpeedValue = value
			end

			for _, object in ipairs(track.Parent:GetChildren()) do
				if object:IsA("TextLabel") then
					local header = track.Parent:FindFirstChild("Frame")
					if header then
						break
					end
				end
			end

			local percentValue = (value - minValue) / (maxValue - minValue)
			local thumb = track:FindFirstChildOfClass("TextButton")
			local fill = track:FindFirstChildOfClass("Frame")

			if thumb then
				thumb.Position = UDim2.new(0, percentValue * trackWidth, 0.5, 0)
			end

			if fill then
				fill.Size = UDim2.new(percentValue, 0, 1, 0)
			end

			local header = track.Parent:FindFirstChildWhichIsA("Frame")
			if header then
				local labels = header:GetChildren()
				for _, object in ipairs(labels) do
					if object:IsA("TextLabel") and object.Text ~= "Fly Speed"
						and object.Text ~= "JumpPower" and object.Text ~= "WalkSpeed" then
						object.Text = tostring(value)
					end
				end
			end

			applyCharacterValues()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = nil
	end
end)

local draggingPanel = false
local dragStart
local panelStart

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingPanel = true
		dragStart = input.Position
		panelStart = panel.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingPanel and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart

		panel.Position = UDim2.new(
			panelStart.X.Scale,
			panelStart.X.Offset + delta.X,
			panelStart.Y.Scale,
			panelStart.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingPanel = false
	end
end)

local function setUIFlying(state)
	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)

	if state then
		TweenService:Create(toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 100, 240),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()

		TweenService:Create(statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 220, 130)
		}):Play()

		toggleButton.Text = "■  Desativar Fly  [F]"
		statusLabel.Text = "Flying"
		statusLabel.TextColor3 = Color3.fromRGB(80, 180, 110)
	else
		TweenService:Create(toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(245, 245, 250),
			TextColor3 = Color3.fromRGB(60, 60, 80)
		}):Play()

		TweenService:Create(statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(200, 200, 210)
		}):Play()

		toggleButton.Text = "▶  Ativar Fly  [F]"
		statusLabel.Text = "Idle"
		statusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	end
end

local function getRootPart()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart")
end

local function enableFly()
	local root = getRootPart()

	if root:FindFirstChild("FlyVelocity") then
		root.FlyVelocity:Destroy()
	end

	if root:FindFirstChild("FlyGyro") then
		root.FlyGyro:Destroy()
	end

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.Name = "FlyVelocity"
	bodyVel.Velocity = Vector3.zero
	bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVel.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "FlyGyro"
	bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.D = 50
	bodyGyro.CFrame = root.CFrame
	bodyGyro.Parent = root

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.PlatformStand = true
	end

	flying = true
	setUIFlying(true)
end

local function disableFly()
	if bodyVel then
		bodyVel:Destroy()
		bodyVel = nil
	end

	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.PlatformStand = false
	end

	flying = false
	setUIFlying(false)
end

local function getInputDirection()
	local direction = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		direction += Vector3.new(0, 0, -1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		direction += Vector3.new(0, 0, 1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction += Vector3.new(-1, 0, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction += Vector3.new(1, 0, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		direction += Vector3.new(0, 1, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		direction += Vector3.new(0, -1, 0)
	end

	return direction
end

local function toggleFly()
	if flying then
		disableFly()
	else
		enableFly()
	end
end

toggleButton.Activated:Connect(toggleFly)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TOGGLE_KEY then
		toggleFly()
	end
end)

RunService.Heartbeat:Connect(function()
	if not flying or not bodyVel or not bodyGyro then
		return
	end

	local root = getRootPart()
	local camera = workspace.CurrentCamera
	local inputDirection = getInputDirection()

	if not camera then
		return
	end

	local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	local speed = sprinting and FLY_SPEED * SPRINT_MULT or FLY_SPEED

	if inputDirection.Magnitude > 0 then
		local worldDirection = camera.CFrame:VectorToWorldSpace(inputDirection).Unit
		bodyVel.Velocity = worldDirection * speed

		local lookDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
		if lookDirection.Magnitude > 0.01 then
			bodyGyro.CFrame = CFrame.lookAt(
				root.Position,
				root.Position + lookDirection
			)
		end
	else
		bodyVel.Velocity = bodyVel.Velocity * 0.85
	end
end)

player.CharacterAdded:Connect(function()
	flying = false
	bodyVel = nil
	bodyGyro = nil

	task.wait(0.5)
	applyCharacterValues()
	setUIFlying(false)
end)

applyCharacterValues()
