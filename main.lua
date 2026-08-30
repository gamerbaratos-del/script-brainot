-- ============================================
-- ROBLOX FLY SCRIPT - VERSÃO OTIMIZADA
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
	
	-- Limites de valores
	SPEED_MIN = 1,
	SPEED_MAX = 1000,
	JUMP_MIN = 0,
	JUMP_MAX = 3000,
	WALK_MIN = 0,
	WALK_MAX = 3000,
	
	-- Valores padrão
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
	panelStart = nil
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
-- CRIAR UI
-- ============================================

local function createUI()
	-- Limpar UI antiga
	local oldGui = playerGui:FindFirstChild("FlyControlUI")
	if oldGui then
		oldGui:Destroy()
	end

	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FlyControlUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Painel Principal
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

	-- Barra de Título
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

	-- Botão Toggle
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

	-- Status Indicator
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

	-- Guardar elementos da UI
	uiElements = {
		screenGui = screenGui,
		panel = panel,
		titleBar = titleBar,
		toggleButton = toggleButton,
		statusDot = statusDot,
		statusLabel = statusLabel
	}

	return panel, toggleButton, statusDot, statusLabel
end

-- ============================================
-- CRIAR SLIDERS
-- ============================================

local function createSlider(panel, yPosition, labelText, minValue, maxValue, defaultValue, callback)
	-- Frame do Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, -30, 0, 24)
	header.Position = UDim2.new(0, 15, 0, yPosition)
	header.BackgroundTransparency = 1
	header.Parent = panel

	-- Label do texto
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.5, 0, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = labelText
	valueLabel.Font = Enum.Font.GothamSemibold
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = header

	-- Label do número
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

	-- Track do slider
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

	-- Fill do track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 100, 240)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- Thumb do slider
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

	-- Funções do Slider
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

	-- Inicializar posição
	local percent = (defaultValue - minValue) / (maxValue - minValue)
	task.defer(function()
		setValueFromPercent(percent)
	end)
end

-- ============================================
-- FLY FUNCTIONS
-- ============================================

local function setUIFlying(state)
	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)

	if state then
		TweenService:Create(uiElements.toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 100, 240),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()

		TweenService:Create(uiElements.statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(100, 220, 130)
		}):Play()

		uiElements.toggleButton.Text = "■  Desativar Fly  [F]"
		uiElements.statusLabel.Text = "Flying"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(80, 180, 110)
	else
		TweenService:Create(uiElements.toggleButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(245, 245, 250),
			TextColor3 = Color3.fromRGB(60, 60, 80)
		}):Play()

		TweenService:Create(uiElements.statusDot, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(200, 200, 210)
		}):Play()

		uiElements.toggleButton.Text = "▶  Ativar Fly  [F]"
		uiElements.statusLabel.Text = "Idle"
		uiElements.statusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	end
end

local function enableFly()
	local root = getRootPart()

	-- Limpar objetos antigos
	if root:FindFirstChild("FlyVelocity") then
		root.FlyVelocity:Destroy()
	end
	if root:FindFirstChild("FlyGyro") then
		root.FlyGyro:Destroy()
	end

	-- Criar BodyVelocity
	flyState.bodyVel = Instance.new("BodyVelocity")
	flyState.bodyVel.Name = "FlyVelocity"
	flyState.bodyVel.Velocity = Vector3.zero
	flyState.bodyVel.MaxForce = Vector3.new(100000, 100000, 100000)
	flyState.bodyVel.Parent = root

	-- Criar BodyGyro
	flyState.bodyGyro = Instance.new("BodyGyro")
	flyState.bodyGyro.Name = "FlyGyro"
	flyState.bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
	flyState.bodyGyro.D = 50
	flyState.bodyGyro.CFrame = root.CFrame
	flyState.bodyGyro.Parent = root

	-- Desabilitar controle normal
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
	-- Slider dragging
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
					callbackFn = function(v) values.jumpPower = v applyCharacterValues() end
				else
					minValue, maxValue = CONFIG.WALK_MIN, CONFIG.WALK_MAX
					callbackFn = function(v) values.walkSpeed = v applyCharacterValues() end
				end

				local value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
				callbackFn(value)

				-- Atualizar visual
				local thumb = track:FindFirstChildOfClass("TextButton")
				local fill = track:FindFirstChildOfClass("Frame")

				if thumb then
					thumb.Position = UDim2.new(0, percent * trackWidth, 0.5, 0)
				end

				if fill then
					fill.Size = UDim2.new(percent, 0, 1, 0)
				end

				-- Atualizar número exibido
				local parent = track.Parent
				for _, child in ipairs(parent:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= track.Name then
						for _, label in ipairs(child:GetChildren()) do
							if label:IsA("TextLabel") and label.TextColor3 == Color3.fromRGB(100, 100, 240) then
								label.Text = tostring(value)
								break
							end
						end
					end
				end
			end
		end
	end)

	-- Fim do drag
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			flyState.sliderDragging = nil
			flyState.draggingPanel = false
		end
	end)

	-- Drag do painel
	uiElements.titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			flyState.draggingPanel = true
			flyState.dragStart = input.Position
			flyState.panelStart = uiElements.panel.Position
		end
	end)

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
		end
	end)

	-- Toggle fly com botão ou tecla
	uiElements.toggleButton.Activated:Connect(toggleFly)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
			toggleFly()
		end
	end)
end

-- ============================================
-- HEARTBEAT (Fly Movement)
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
-- CHARACTER RESPAWN HANDLING
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
-- INICIALIZAR SCRIPT
-- ============================================

local function initialize()
	createUI()
	createSlider(uiElements.panel, 110, "Fly Speed", CONFIG.SPEED_MIN, CONFIG.SPEED_MAX, CONFIG.FLY_SPEED, 
		function(value) values.flySpeed = value end)
	createSlider(uiElements.panel, 175, "JumpPower", CONFIG.JUMP_MIN, CONFIG.JUMP_MAX, CONFIG.JUMP_POWER, 
		function(value) values.jumpPower = value applyCharacterValues() end)
	createSlider(uiElements.panel, 240, "WalkSpeed", CONFIG.WALK_MIN, CONFIG.WALK_MAX, CONFIG.WALK_SPEED, 
		function(value) values.walkSpeed = value applyCharacterValues() end)
	
	setupInputHandling()
	setupFlightLoop()
	setupCharacterHandling()
	
	applyCharacterValues()
end

-- Executar
initialize()
