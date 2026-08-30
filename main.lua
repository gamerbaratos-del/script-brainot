-- ============================================
-- ROBLOX FLY SCRIPT - PROFISSIONAL
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ============================================
-- CONFIGURAÇÕES
-- ============================================

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

-- ============================================
-- VARIÁVEIS GLOBAIS
-- ============================================

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
	lastMinimizedPos = UDim2.new(0, 20, 0.5, -25) -- Posição da bolinha
}

local values = {
	flySpeed = CONFIG.FLY_SPEED,
	jumpPower = CONFIG.JUMP_POWER,
	walkSpeed = CONFIG.WALK_SPEED
}

local uiElements = {}

-- ============================================
-- FUNÇÕES UTILITÁRIAS
-- ============================================

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
		direction = direction + Vector3.new(0, 0, -1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		direction = direction + Vector3.new(0, 0, 1)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction = direction + Vector3.new(-1, 0, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction = direction + Vector3.new(1, 0, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		direction = direction + Vector3.new(0, 1, 0)
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		direction = direction + Vector3.new(0, -1, 0)
	end

	return direction
end

-- ============================================
-- MINIMIZAR/EXPANDIR COM ANIMAÇÃO SUAVE
-- ============================================

local function toggleMinimize()
	flyState.minimized = not flyState.minimized
	
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	
	if flyState.minimized then
		-- Minimizar para bolinha - mantém posição atual
		local currentPos = uiElements.panel.Position
		flyState.lastMinimizedPos = currentPos
		
		TweenService:Create(uiElements.panel, tweenInfo, {
			Size = UDim2.new(0, 55, 0, 55),
			Position = UDim2.new(currentPos.X.Scale, currentPos.X.Offset, currentPos.Y.Scale, currentPos.Y.Offset)
		}):Play()
		
		task.wait(0.1)
		
		-- Esconder elementos
		uiElements.titleBar.Visible = false
		uiElements.toggleButton.Visible = false
		uiElements.statusDot.Visible = false
		uiElements.statusLabel.Visible = false
		uiElements.sliderContainer.Visible = false
		
		-- Mostrar botão de expandir (transformar em +)
		uiElements.minimizeButton.Text = "+"
		uiElements.minimizeButton.Visible = true
		uiElements.minimizeButton.Size = UDim2.new(1, 0, 1, 0)
		uiElements.minimizeButton.Position = UDim2.new(0, 0, 0, 0)
		uiElements.minimizeButton.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
		
	else
		-- Expandir para painel normal - volta para posição salva
		local currentPos = flyState.lastMinimizedPos
		
		TweenService:Create(uiElements.panel, tweenInfo, {
			Size = UDim2.new(0, 280, 0, 370),
			Position = UDim2.new(currentPos.X.Scale, currentPos.X.Offset, currentPos.Y.Scale, currentPos.Y.Offset)
		}):Play()
		
		task.wait(0.2)
		
		-- Mostrar elementos
		uiElements.titleBar.Visible = true
		uiElements.toggleButton.Visible = true
		uiElements.statusDot.Visible = true
		uiElements.statusLabel.Visible = true
		uiElements.sliderContainer.Visible = true
		
		-- Restaurar botão minimizar
		uiElements.minimizeButton.Text = "−"
		uiElements.minimizeButton.Visible = true
		uiElements.minimizeButton.Size = UDim2.new(0, 30, 0, 30)
		uiElements.minimizeButton.Position = UDim2.new(1, -40, 0, 6)
		uiElements.minimizeButton.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
	end
end

-- ============================================
-- CRIAR UI
-- ============================================

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

	-- Shadow/Glow effect
	local panelShadow = Instance.new("UIStroke")
	panelShadow.Color = Color3.fromRGB(100, 150, 255)
	panelShadow.Thickness = 1
	panelShadow.Transparency = 0.7
	panelShadow.Parent = panel

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

	-- Botão Minimizar
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Name = "MinimizeBtn"
	minimizeButton.Size = UDim2.new(0, 30, 0, 30)
	minimizeButton.Position = UDim2.new(1, -40, 0, 7.5)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
	minimizeButton.BorderSizePixel = 0
	minimizeButton.AutoButtonColor = false
	minimizeButton.Text = "−"
	minimizeButton.Font = Enum.Font.GothamBold
	minimizeButton.TextSize = 18
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.ZIndex = 10
	minimizeButton.Parent = titleBar

	local minimizeCorner = Instance.new("UICorner")
	minimizeCorner.CornerRadius = UDim.new(0, 8)
	minimizeCorner.Parent = minimizeButton

	minimizeButton.MouseEnter:Connect(function()
		if not flyState.minimized then
			TweenService:Create(minimizeButton, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(255, 120, 120)
			}):Play()
		end
	end)

	minimizeButton.MouseLeave:Connect(function()
		if not flyState.minimized then
			TweenService:Create(minimizeButton, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(240, 100, 100)
			}):Play()
		end
	end)

	-- Botão Toggle Fly
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

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = toggleButton

	toggleButton.MouseEnter:Connect(function()
		TweenService:Create(toggleButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(80, 100, 150)
		}):Play()
	end)

	toggleButton.MouseLeave:Connect(function()
		if not flyState.flying then
			TweenService:Create(toggleButton, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(70, 80, 120)
			}):Play()
		end
	end)

	-- Container para sliders
	local sliderContainer = Instance.new("Frame")
	sliderContainer.Name = "SliderContainer"
	sliderContainer.Size = UDim2.new(1, 0, 1, -115)
	sliderContainer.Position = UDim2.new(0, 0, 0, 110)
	sliderContainer.BackgroundTransparency = 1
	sliderContainer.Parent = panel

	-- Status Indicator
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

-- ============================================
-- CRIAR SLIDERS
-- ============================================

local function createSlider(container, yPosition, labelText, minValue, maxValue, defaultValue, callback)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -30, 0, 24)
	header.Position = UDim2.new(0, 15, 0, yPosition)
	header.BackgroundTransparency = 1
	header.Parent = container

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.6, 0, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = labelText
	valueLabel.Font = Enum.Font.GothamSemibold
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = header

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
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local thumb = Instance.new("TextButton")
	thumb.Size = UDim2.new(0, 18, 0, 18)
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

	-- Sombra do thumb
	local thumbShadow = Instance.new("UIStroke")
	thumbShadow.Color = Color3.fromRGB(100, 150, 255)
	thumbShadow.Thickness = 2
	thumbShadow.Transparency = 0.5
	thumbShadow.Parent = thumb

	local function setValueFromPercent(percent)
		percent = math.clamp(percent, 0, 1)
		local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
		numberLabel.Text = tostring(value)

		local trackWidth = track.AbsoluteSize.X
		if trackWidth > 0 then
			local thumbX = percent * trackWidth
			thumb.Position = UDim2.new(0, thumbX, 0.5, 0)
			fill.Size = UDim2.new(0, thumbX, 1, 0)
		end

		callback(value)
	end

	local function updateFromInput(input)
		local trackWidth = track.AbsoluteSize.X
		if trackWidth <= 0 then return end

		local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
		setValueFromPercent(percent)
	end

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			flyState.sliderDragging = track
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

-- ============================================
-- FLY FUNCTIONS
-- ============================================

local function setUIFlying(state)
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad)

	if state then
		TweenService:Create(uiElements.toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		}):Play()

		TweenService:Create(uiElements.statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 255, 120)
		}):Play()

		uiElements.toggleButton.Text = "■  DESATIVAR FLY  [F]"
		uiElements.statusLabel.Text = "● FLYING"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
	else
		TweenService:Create(uiElements.toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(70, 80, 120)
		}):Play()

		TweenService:Create(uiElements.statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(150, 150, 180)
		}):Play()

		uiElements.toggleButton.Text = "▶  ATIVAR FLY  [F]"
		uiElements.statusLabel.Text = "● IDLE"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	end
end

local function enableFly()
	local root = getRootPart()

	if root:FindFirstChild("FlyVelocity") then
		root.FlyVelocity:Destroy()
	end
	if root:FindFirstChild("FlyGyro") then
		root.FlyGyro:Destroy()
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

-- ============================================
-- INPUT HANDLING
-- ============================================

local function setupInputHandling()
	UserInputService.InputChanged:Connect(function(input)
		if not flyState.sliderDragging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement or 
		   input.UserInputType == Enum.UserInputType.Touch then
			local track = flyState.sliderDragging
			local trackWidth = track.AbsoluteSize.X

			if trackWidth > 0 then
				local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
				percent = math.clamp(percent, 0, 1)

				local minValue, maxValue
				local callbackFn

				if track.Name == "Fly SpeedSlider" then
					minValue, maxValue = CONFIG.SPEED_MIN, CONFIG.SPEED_MAX
					callbackFn = function(v) values.flySpeed = v end
				elseif track.Name == "JumpPowerSlider" then
					minValue, maxValue = CONFIG.JUMP_MIN, CONFIG.JUMP_MAX
					callbackFn = function(v) values.jumpPower = v; applyCharacterValues() end
				else
					minValue, maxValue = CONFIG.WALK_MIN, CONFIG.WALK_MAX
					callbackFn = function(v) values.walkSpeed = v; applyCharacterValues() end
				end

				local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
				callbackFn(value)

				local thumb = track:FindFirstChildOfClass("TextButton")
				local fill = track:FindFirstChildOfClass("Frame")

				if thumb then
					thumb.Position = UDim2.new(0, percent * trackWidth, 0.5, 0)
				end

				if fill then
					fill.Size = UDim2.new(percent, 0, 1, 0)
				end

				local parent = track.Parent
				for _, child in ipairs(parent:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= track.Name then
						for _, label in ipairs(child:GetChildren()) do
							if label:IsA("TextLabel") and label.TextColor3 == Color3.fromRGB(100, 200, 255) then
								label.Text = tostring(value)
								break
							end
						end
					end
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			flyState.sliderDragging = nil
			flyState.draggingPanel = false
		end
	end)

	local function setupPanelDrag(dragArea)
		dragArea.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			   input.UserInputType == Enum.UserInputType.Touch then
				flyState.draggingPanel = true
				flyState.dragStart = input.Position
				flyState.panelStart = uiElements.panel.Position
			end
		end)
	end

	setupPanelDrag(uiElements.titleBar)
	setupPanelDrag(uiElements.panel)

	UserInputService.InputChanged:Connect(function(input)
		if flyState.draggingPanel and (input.UserInputType == Enum.UserInputType.MouseMovement or 
		   input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - flyState.dragStart

			uiElements.panel.Position = UDim2.new(
				flyState.panelStart.X.Scale,
				flyState.panelStart.X.Offset + delta.X,
				flyState.panelStart.Y.Scale,
				flyState.panelStart.Y.Offset + delta.Y
			)

			-- Atualizar posição última se minimizado
			if flyState.minimized then
				flyState.lastMinimizedPos = uiElements.panel.Position
			end
		end
	end)

	uiElements.toggleButton.Activated:Connect(toggleFly)
	uiElements.minimizeButton.Activated:Connect(toggleMinimize)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
			toggleFly()
		end
	end)
end

-- ============================================
-- HEARTBEAT
-- ============================================

local function setupFlightLoop()
	RunService.Heartbeat:Connect(function()
		if not flyState.flying or not flyState.bodyVel or not flyState.bodyGyro then
			return
		end

		local root = getRootPart()
		local camera = workspace.CurrentCamera
		local inputDirection = getInputDirection()

		if not camera then return end

		local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or 
						 UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local speed = sprinting and values.flySpeed * CONFIG.SPRINT_MULT or values.flySpeed

		if inputDirection.Magnitude > 0 then
			local worldDirection = camera.CFrame:VectorToWorldSpace(inputDirection).Unit
			flyState.bodyVel.Velocity = worldDirection * speed

			local lookDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
			if lookDirection.Magnitude > 0.01 then
				flyState.bodyGyro.CFrame = CFrame.lookAt(
					root.Position,
					root.Position + lookDirection
				)
			end
		else
			flyState.bodyVel.Velocity = flyState.bodyVel.Velocity * 0.85
		end
	end)
end

-- ============================================
-- CHARACTER RESPAWN
-- ============================================

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

-- ============================================
-- INICIALIZAR
-- ============================================

createUI()
createSlider(uiElements.sliderContainer, 0, "Fly Speed", CONFIG.SPEED_MIN, CONFIG.SPEED_MAX, CONFIG.FLY_SPEED, 
	function(value) values.flySpeed = value end)
createSlider(uiElements.sliderContainer, 65, "JumpPower", CONFIG.JUMP_MIN, CONFIG.JUMP_MAX, CONFIG.JUMP_POWER, 
	function(value) values.jumpPower = value; applyCharacterValues() end)
createSlider(uiElements.sliderContainer, 130, "WalkSpeed", CONFIG.WALK_MIN, CONFIG.WALK_MAX, CONFIG.WALK_SPEED, 
	function(value) values.walkSpeed = value; applyCharacterValues() end)

setupInputHandling()
setupFlightLoop()
setupCharacterHandling()

applyCharacterValues()
