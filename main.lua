local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	FLY_SPEED = 60,
	SPRINT_MULT = 2.5,
	TOGGLE_KEY = Enum.KeyCode.F,

	SPEED_MIN = 1,
	SPEED_MAX = 1000,
	JUMP_MIN = 0,
	JUMP_MAX = 3000,
	WALK_MIN = 0,
	WALK_MAX = 3000,

	JUMP_POWER = 50,
	WALK_SPEED = 16
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local flyState = {
	flying = false,
	bodyVel = nil,
	bodyGyro = nil,
	sliderDragging = nil,
	draggingPanel = false,
	dragStart = nil,
	panelStart = nil,
	minimized = false,
	lastMinimizedPos = UDim2.new(0, 20, 0.5, -185)
}

local values = {
	flySpeed = CONFIG.FLY_SPEED,
	jumpPower = CONFIG.JUMP_POWER,
	walkSpeed = CONFIG.WALK_SPEED
}

local uiElements = {}

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart")
end

local function applyCharacterValues()
	local humanoid = getHumanoid()

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = values.jumpPower
		humanoid.WalkSpeed = values.walkSpeed
	end
end

local function getInputDirection()
	local direction = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		direction += Vector3.new(0, 0, -1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		direction += Vector3.new(0, 0, 1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction += Vector3.new(-1, 0, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
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

local function toggleMinimize()
	if flyState.minimized then
		flyState.minimized = false

		local position = flyState.lastMinimizedPos

		TweenService:Create(uiElements.panel, TweenInfo.new(
			0.4,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.InOut
		), {
			Size = UDim2.new(0, 280, 0, 370),
			Position = position
		}):Play()

		task.delay(0.2, function()
			uiElements.titleBar.Visible = true
			uiElements.toggleButton.Visible = true
			uiElements.statusDot.Visible = true
			uiElements.statusLabel.Visible = true
			uiElements.sliderContainer.Visible = true

			uiElements.minimizeButton.Text = "−"
			uiElements.minimizeButton.Size = UDim2.new(0, 30, 0, 30)
			uiElements.minimizeButton.Position = UDim2.new(1, -40, 0, 6)
			uiElements.minimizeButton.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
			uiElements.minimizeButton.ZIndex = 10
		end)
	else
		flyState.minimized = true
		flyState.lastMinimizedPos = uiElements.panel.Position

		uiElements.titleBar.Visible = false
		uiElements.toggleButton.Visible = false
		uiElements.statusDot.Visible = false
		uiElements.statusLabel.Visible = false
		uiElements.sliderContainer.Visible = false

		uiElements.minimizeButton.Text = "+"
		uiElements.minimizeButton.Size = UDim2.new(1, 0, 1, 0)
		uiElements.minimizeButton.Position = UDim2.new(0, 0, 0, 0)
		uiElements.minimizeButton.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
		uiElements.minimizeButton.ZIndex = 20
		uiElements.minimizeButton.Visible = true

		TweenService:Create(uiElements.panel, TweenInfo.new(
			0.4,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.InOut
		), {
			Size = UDim2.new(0, 55, 0, 55)
		}):Play()
	end
end

local function createUI()
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
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(100, 150, 255)
	panelStroke.Thickness = 1
	panelStroke.Transparency = 0.7
	panelStroke.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 45)
	titleBar.BackgroundColor3 = Color3.fromRGB(40, 45, 70)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 16)
	titleCorner.Parent = titleBar

	local titleFill = Instance.new("Frame")
	titleFill.Size = UDim2.new(1, 0, 0, 20)
	titleFill.Position = UDim2.new(0, 0, 1, -20)
	titleFill.BackgroundColor3 = Color3.fromRGB(40, 45, 70)
	titleFill.BorderSizePixel = 0
	titleFill.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.7, -30, 1, 0)
	titleText.Position = UDim2.new(0, 15, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "✈ FLY CONTROL"
	titleText.Font = Enum.Font.GothamBold
	titleText.TextSize = 15
	titleText.TextColor3 = Color3.fromRGB(100, 150, 255)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.Parent = titleBar

	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Name = "MinimizeBtn"
	minimizeButton.Size = UDim2.new(0, 30, 0, 30)
	minimizeButton.Position = UDim2.new(1, -40, 0, 6)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
	minimizeButton.BorderSizePixel = 0
	minimizeButton.AutoButtonColor = false
	minimizeButton.Text = "−"
	minimizeButton.Font = Enum.Font.GothamBold
	minimizeButton.TextSize = 18
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.ZIndex = 20

	-- O botão fica no painel para continuar clicável quando minimizado.
	minimizeButton.Parent = panel

	local minimizeCorner = Instance.new("UICorner")
	minimizeCorner.CornerRadius = UDim.new(0, 8)
	minimizeCorner.Parent = minimizeButton

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleFly"
	toggleButton.Size = UDim2.new(1, -30, 0, 45)
	toggleButton.Position = UDim2.new(0, 15, 0, 55)
	toggleButton.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
	toggleButton.BorderSizePixel = 0
	toggleButton.AutoButtonColor = false
	toggleButton.Text = "▶  ATIVAR FLY  [F]"
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextSize = 14
	toggleButton.TextColor3 = Color3.fromRGB(180, 200, 255)
	toggleButton.Parent = panel

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggleButton

	local sliderContainer = Instance.new("Frame")
	sliderContainer.Name = "SliderContainer"
	sliderContainer.Size = UDim2.new(1, 0, 1, -115)
	sliderContainer.Position = UDim2.new(0, 0, 0, 110)
	sliderContainer.BackgroundTransparency = 1
	sliderContainer.Parent = panel

	local statusDot = Instance.new("Frame")
	statusDot.Size = UDim2.new(0, 10, 0, 10)
	statusDot.Position = UDim2.new(0, 15, 0, 348)
	statusDot.BackgroundColor3 = Color3.fromRGB(150, 150, 180)
	statusDot.BorderSizePixel = 0
	statusDot.Parent = panel

	local statusDotCorner = Instance.new("UICorner")
	statusDotCorner.CornerRadius = UDim.new(1, 0)
	statusDotCorner.Parent = statusDot

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -50, 0, 20)
	statusLabel.Position = UDim2.new(0, 30, 0, 341)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "● IDLE"
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = panel

	uiElements = {
		screenGui = screenGui,
		panel = panel,
		titleBar = titleBar,
		toggleButton = toggleButton,
		statusDot = statusDot,
		statusLabel = statusLabel,
		minimizeButton = minimizeButton,
		sliderContainer = sliderContainer
	}
end

local function createSlider(container, yPosition, labelText, minValue, maxValue, defaultValue, callback)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -30, 0, 24)
	header.Position = UDim2.new(0, 15, 0, yPosition)
	header.BackgroundTransparency = 1
	header.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(150, 150, 200)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = header

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0.4, 0, 1, 0)
	numberLabel.Position = UDim2.new(0.6, 0, 0, 0)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(defaultValue)
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.TextSize = 13
	numberLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Right
	numberLabel.Parent = header

	local track = Instance.new("Frame")
	track.Name = labelText .. "Slider"
	track.Size = UDim2.new(1, -30, 0, 6)
	track.Position = UDim2.new(0, 15, 0, yPosition + 30)
	track.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
	track.BorderSizePixel = 0
	track.Active = true
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local thumb = Instance.new("TextButton")
	thumb.Size = UDim2.new(0, 18, 0, 18)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Text = ""
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.AutoButtonColor = false
	thumb.ZIndex = 3
	thumb.Parent = track

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	local function setValue(percent)
		percent = math.clamp(percent, 0, 1)

		local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
		local width = track.AbsoluteSize.X

		numberLabel.Text = tostring(value)

		if width > 0 then
			local x = percent * width
			thumb.Position = UDim2.new(0, x, 0.5, 0)
			fill.Size = UDim2.new(0, x, 1, 0)
		end

		callback(value)
	end

	local function update(input)
		local width = track.AbsoluteSize.X

		if width > 0 then
			setValue((input.Position.X - track.AbsolutePosition.X) / width)
		end
	end

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			flyState.sliderDragging = track
			update(input)
		end
	end

	track.InputBegan:Connect(beginDrag)
	thumb.InputBegan:Connect(beginDrag)

	task.defer(function()
		setValue((defaultValue - minValue) / (maxValue - minValue))
	end)
end

local function setUIFlying(state)
	if state then
		uiElements.toggleButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		uiElements.statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 120)
		uiElements.toggleButton.Text = "■  DESATIVAR FLY  [F]"
		uiElements.statusLabel.Text = "● FLYING"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
	else
		uiElements.toggleButton.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
		uiElements.statusDot.BackgroundColor3 = Color3.fromRGB(150, 150, 180)
		uiElements.toggleButton.Text = "▶  ATIVAR FLY  [F]"
		uiElements.statusLabel.Text = "● IDLE"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	end
end

local function enableFly()
	local root = getRootPart()

	local oldVelocity = root:FindFirstChild("FlyVelocity")
	local oldGyro = root:FindFirstChild("FlyGyro")

	if oldVelocity then
		oldVelocity:Destroy()
	end

	if oldGyro then
		oldGyro:Destroy()
	end

	flyState.bodyVel = Instance.new("BodyVelocity")
	flyState.bodyVel.Name = "FlyVelocity"
	flyState.bodyVel.Velocity = Vector3.zero
	flyState.bodyVel.MaxForce = Vector3.new(100000, 100000, 100000)
	flyState.bodyVel.Parent = root

	flyState.bodyGyro = Instance.new("BodyGyro")
	flyState.bodyGyro.Name = "FlyGyro"
	flyState.bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
	flyState.bodyGyro.D = 50
	flyState.bodyGyro.CFrame = root.CFrame
	flyState.bodyGyro.Parent = root

	local humanoid = getHumanoid()

	if humanoid then
		humanoid.PlatformStand = true
	end

	flyState.flying = true
	setUIFlying(true)
end

local function disableFly()
	if flyState.bodyVel then
		flyState.bodyVel:Destroy()
		flyState.bodyVel = nil
	end

	if flyState.bodyGyro then
		flyState.bodyGyro:Destroy()
		flyState.bodyGyro = nil
	end

	local humanoid = getHumanoid()

	if humanoid then
		humanoid.PlatformStand = false
	end

	flyState.flying = false
	setUIFlying(false)
end

local function toggleFly()
	if flyState.flying then
		disableFly()
	else
		enableFly()
	end
end

local function setupInputHandling()
	UserInputService.InputChanged:Connect(function(input)
		if not flyState.sliderDragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local track = flyState.sliderDragging
		local width = track.AbsoluteSize.X

		if width <= 0 then
			return
		end

		local percent = math.clamp(
			(input.Position.X - track.AbsolutePosition.X) / width,
			0,
			1
		)

		local minValue
		local maxValue
		local callback

		if track.Name == "Fly SpeedSlider" then
			minValue = CONFIG.SPEED_MIN
			maxValue = CONFIG.SPEED_MAX
			callback = function(value)
				values.flySpeed = value
			end
		elseif track.Name == "JumpPowerSlider" then
			minValue = CONFIG.JUMP_MIN
			maxValue = CONFIG.JUMP_MAX
			callback = function(value)
				values.jumpPower = value
				applyCharacterValues()
			end
		else
			minValue = CONFIG.WALK_MIN
			maxValue = CONFIG.WALK_MAX
			callback = function(value)
				values.walkSpeed = value
				applyCharacterValues()
			end
		end

		local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
		callback(value)

		local thumb = track:FindFirstChildOfClass("TextButton")
		local fill = track:FindFirstChildOfClass("Frame")

		if thumb then
			thumb.Position = UDim2.new(0, percent * width, 0.5, 0)
		end

		if fill then
			fill.Size = UDim2.new(percent, 0, 1, 0)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			flyState.sliderDragging = nil
			flyState.draggingPanel = false
		end
	end)

	local function setupPanelDrag(area)
		area.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				flyState.draggingPanel = true
				flyState.dragStart = input.Position
				flyState.panelStart = uiElements.panel.Position
			end
		end)
	end

	setupPanelDrag(uiElements.titleBar)

	uiElements.toggleButton.Activated:Connect(toggleFly)
	uiElements.minimizeButton.Activated:Connect(toggleMinimize)

	UserInputService.InputChanged:Connect(function(input)
		if not flyState.draggingPanel then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - flyState.dragStart

		uiElements.panel.Position = UDim2.new(
			flyState.panelStart.X.Scale,
			flyState.panelStart.X.Offset + delta.X,
			flyState.panelStart.Y.Scale,
			flyState.panelStart.Y.Offset + delta.Y
		)

		if flyState.minimized then
			flyState.lastMinimizedPos = uiElements.panel.Position
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
			toggleFly()
		end
	end)
end

local function setupFlightLoop()
	RunService.Heartbeat:Connect(function()
		if not flyState.flying
			or not flyState.bodyVel
			or not flyState.bodyGyro then
			return
		end

		local root = getRootPart()
		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		local direction = getInputDirection()
		local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		local speed = values.flySpeed

		if sprinting then
			speed *= CONFIG.SPRINT_MULT
		end

		if direction.Magnitude > 0 then
			local worldDirection = camera.CFrame:VectorToWorldSpace(direction).Unit
			flyState.bodyVel.Velocity = worldDirection * speed

			local lookDirection = Vector3.new(
				worldDirection.X,
				0,
				worldDirection.Z
			)

			if lookDirection.Magnitude > 0.01 then
				flyState.bodyGyro.CFrame = CFrame.lookAt(
					root.Position,
					root.Position + lookDirection
				)
			end
		else
			flyState.bodyVel.Velocity *= 0.85
		end
	end)
end

local function setupCharacterHandling()
	player.CharacterAdded:Connect(function()
		flyState.flying = false
		flyState.bodyVel = nil
		flyState.bodyGyro = nil

		task.wait(0.5)
		applyCharacterValues()
		setUIFlying(false)
	end)
end

createUI()

createSlider(
	uiElements.sliderContainer,
	0,
	"Fly Speed",
	CONFIG.SPEED_MIN,
	CONFIG.SPEED_MAX,
	CONFIG.FLY_SPEED,
	function(value)
		values.flySpeed = value
	end
)

createSlider(
	uiElements.sliderContainer,
	65,
	"JumpPower",
	CONFIG.JUMP_MIN,
	CONFIG.JUMP_MAX,
	CONFIG.JUMP_POWER,
	function(value)
		values.jumpPower = value
		applyCharacterValues()
	end
)

createSlider(
	uiElements.sliderContainer,
	130,
	"WalkSpeed",
	CONFIG.WALK_MIN,
	CONFIG.WALK_MAX,
	CONFIG.WALK_SPEED,
	function(value)
		values.walkSpeed = value
		applyCharacterValues()
	end
)

setupInputHandling()
setupFlightLoop()
setupCharacterHandling()
applyCharacterValues()
