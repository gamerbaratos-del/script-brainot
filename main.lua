-- FlyControl.lua
-- LocalScript (colocar em StarterPlayerScripts ou StarterCharacterScripts conforme preferir)
-- Versão: completa com UI responsiva, minimizar->bubble com snap, scroll arrows, presets, keybinds, tooltips, e "atravessar" via PhysicsService.
-- OBS: Presets são salvos nas Attributes do Player (persistem na sessão). Para persistência entre sessões, adicione um RemoteEvent + DataStore no servidor.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- =========================
-- Configurações padrão
-- =========================
local DEFAULTS = {
	FlySpeed = 60,
	SprintMult = 2.5,
	JumpPower = 50,
	WalkSpeed = 16,
	ToggleKey = Enum.KeyCode.F,
	InputMode = "Toggle" -- "Toggle" or "Hold"
}

local LIMITS = {
	Speed = {min = 1, max = 1000},
	Jump = {min = 0, max = 3000},
	Walk = {min = 0, max = 3000}
}

-- =========================
-- Util (helpers)
-- =========================
local Utils = {}
function Utils.clamp(v, a, b) return math.clamp(v, a, b) end

-- Tween helper
function Utils.tween(instance, props, time, style, dir)
	time = time or 0.18
	style = style or Enum.EasingStyle.Quad
	dir = dir or Enum.EasingDirection.Out
	local info = TweenInfo.new(time, style, dir)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

function Utils.copyTable(t)
	local out = {}
	for k,v in pairs(t) do out[k]=v end
	return out
end

-- JSON encode/decode safe
function Utils.safeEncode(t)
	local ok, s = pcall(function() return HttpService:JSONEncode(t) end)
	if ok then return s end
	return nil
end
function Utils.safeDecode(s)
	local ok, t = pcall(function() return HttpService:JSONDecode(s) end)
	if ok then return t end
	return nil
end

-- =========================
-- SettingsManager (atributos de player)
-- Presets armazenados em Attribute "FlyControl_Presets" (JSON: {name->tbl})
-- Config atual em Attribute "FlyControl_Config" (JSON)
-- =========================
local SettingsManager = {}
function SettingsManager.loadConfig()
	local raw = player:GetAttribute("FlyControl_Config")
	if type(raw) ~= "string" then
		return Utils.copyTable(DEFAULTS)
	end
	local tbl = Utils.safeDecode(raw)
	if type(tbl) ~= "table" then
		return Utils.copyTable(DEFAULTS)
	end
	-- ensure defaults
	for k,v in pairs(DEFAULTS) do
		if tbl[k] == nil then tbl[k] = v end
	end
	return tbl
end

function SettingsManager.saveConfig(tbl)
	if type(tbl) ~= "table" then return end
	local s = Utils.safeEncode(tbl)
	if s then
		player:SetAttribute("FlyControl_Config", s)
	end
end

function SettingsManager.getPresets()
	local raw = player:GetAttribute("FlyControl_Presets")
	if type(raw) ~= "string" then return {} end
	local tbl = Utils.safeDecode(raw)
	if type(tbl) ~= "table" then return {} end
	return tbl
end

function SettingsManager.savePresets(presets)
	local s = Utils.safeEncode(presets)
	if s then player:SetAttribute("FlyControl_Presets", s) end
end

function SettingsManager.savePreset(name, tbl)
	if type(name) ~= "string" or name == "" then return false end
	local presets = SettingsManager.getPresets()
	presets[name] = tbl
	SettingsManager.savePresets(presets)
	return true
end

function SettingsManager.deletePreset(name)
	local presets = SettingsManager.getPresets()
	presets[name] = nil
	SettingsManager.savePresets(presets)
end

-- =========================
-- FlyController
-- Encapsula ativar/desativar voo e "atravessar"
-- Usa BodyVelocity/BodyGyro (compatível). Modificar para VectorForce depois é possível.
-- =========================
local FlyController = {}
FlyController._flying = false
FlyController.bodyVel = nil
FlyController.bodyGyro = nil
FlyController.modifiedParts = {} -- [part] = original CanCollide
FlyController.noCollideConn = nil
FlyController.collisionGroup = "FlyNoCollide"

function FlyController.ensureCollisionGroup()
	pcall(function()
		local groups = PhysicsService:GetCollisionGroups()
		local exists = false
		for _,g in ipairs(groups) do
			if g.name == FlyController.collisionGroup then exists = true break end
		end
		if not exists then
			PhysicsService:CreateCollisionGroup(FlyController.collisionGroup)
		end
		PhysicsService:CollisionGroupSetCollidable(FlyController.collisionGroup, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(FlyController.collisionGroup, FlyController.collisionGroup, false)
	end)
end

function FlyController.setCharacterNoCollide(character)
	if not character then return end
	FlyController.ensureCollisionGroup()
	FlyController.modifiedParts = {}
	-- apply to existing parts
	for _,desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			FlyController.modifiedParts[desc] = desc.CanCollide
			desc.CanCollide = false
			pcall(function() PhysicsService:SetPartCollisionGroup(desc, FlyController.collisionGroup) end)
		end
	end
	-- watch for new parts
	if FlyController.noCollideConn then FlyController.noCollideConn:Disconnect() FlyController.noCollideConn = nil end
	FlyController.noCollideConn = character.DescendantAdded:Connect(function(desc)
		if desc and desc:IsA("BasePart") then
			FlyController.modifiedParts[desc] = desc.CanCollide
			desc.CanCollide = false
			pcall(function() PhysicsService:SetPartCollisionGroup(desc, FlyController.collisionGroup) end)
		end
	end)
end

function FlyController.restoreCharacterCollisions()
	if FlyController.noCollideConn then FlyController.noCollideConn:Disconnect() FlyController.noCollideConn = nil end
	for part,orig in pairs(FlyController.modifiedParts) do
		if part and part.Parent then
			part.CanCollide = (orig == nil) and true or orig
			pcall(function() PhysicsService:SetPartCollisionGroup(part, "Default") end)
		end
	end
	FlyController.modifiedParts = {}
end

function FlyController.enable(params)
	-- params: speed, sprintMult
	local root = (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) or (player.CharacterAdded and player.CharacterAdded:Wait() and player.Character:WaitForChild("HumanoidRootPart"))
	if not root then return end

	-- clean existing
	if root:FindFirstChild("FlyVelocity") then root.FlyVelocity:Destroy() end
	if root:FindFirstChild("FlyGyro") then root.FlyGyro:Destroy() end

	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Name = "FlyVelocity"
	bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
	bodyVel.Velocity = Vector3.new(0,0,0)
	bodyVel.Parent = root
	bodyVel.P = 1250

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "FlyGyro"
	bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
	bodyGyro.D = 50
	bodyGyro.CFrame = root.CFrame
	bodyGyro.Parent = root

	FlyController.bodyVel = bodyVel
	FlyController.bodyGyro = bodyGyro

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand = true end

	-- collisions off
	local character = player.Character
	if character then FlyController.setCharacterNoCollide(character) end

	FlyController._flying = true
end

function FlyController.disable()
	if FlyController.bodyVel then FlyController.bodyVel:Destroy(); FlyController.bodyVel = nil end
	if FlyController.bodyGyro then FlyController.bodyGyro:Destroy(); FlyController.bodyGyro = nil end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand = false end

	FlyController.restoreCharacterCollisions()
	FlyController._flying = false
end

function FlyController.isFlying()
	return FlyController._flying
end

-- =========================
-- InputManager
-- Gerencia keybind gravável e modo Toggle/Hold
-- =========================
local InputManager = {}
InputManager.currentKey = DEFAULTS.ToggleKey
InputManager.inputMode = DEFAULTS.InputMode -- "Toggle" or "Hold"
InputManager._recording = false
InputManager._recordConn = nil

function InputManager.loadFromConfig(cfg)
	if not cfg then return end
	if cfg.ToggleKey and typeof(cfg.ToggleKey) == "EnumItem" then
		InputManager.currentKey = cfg.ToggleKey
	elseif cfg.ToggleKey and type(cfg.ToggleKey) == "string" then
		-- try convert string to Enum.KeyCode
		local success, enum = pcall(function() return Enum.KeyCode[cfg.ToggleKey] end)
		if success and enum then InputManager.currentKey = enum end
	end
	InputManager.inputMode = cfg.InputMode or InputManager.inputMode
end

function InputManager.saveToConfig(cfg)
	if not cfg then return end
	cfg.ToggleKey = tostring(InputManager.currentKey.Name)
	cfg.InputMode = InputManager.inputMode
	return cfg
end

-- Start recording next key pressed (for keybind UI)
function InputManager.startRecord(callback)
	if InputManager._recording then return end
	InputManager._recording = true
	-- temporary bind to get next keyboard input
	InputManager._recordConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			InputManager.currentKey = key
			InputManager._recording = false
			if InputManager._recordConn then InputManager._recordConn:Disconnect(); InputManager._recordConn = nil end
			if callback then callback(key) end
		end
	end)
end

-- =========================
-- UIFactory: cria a GUI e retorna handles
-- =========================
local UIFactory = {}
function UIFactory.create()
	-- clean old
	local old = playerGui:FindFirstChild("FlyControlUI")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FlyControlUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- main panel (scale-based responsive)
	local panel = Instance.new("Frame", screenGui)
	panel.Name = "Panel"
	panel.Size = UDim2.new(0.24, 0, 0.55, 0)
	panel.Position = UDim2.new(0.02, 0, 0.22, 0)
	panel.BackgroundColor3 = Color3.fromRGB(255,255,255)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	local panelCorner = Instance.new("UICorner", panel)
	panelCorner.CornerRadius = UDim.new(0,14)

	-- titlebar
	local titleBar = Instance.new("Frame", panel)
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1,0,0,48)
	titleBar.BackgroundColor3 = Color3.fromRGB(248,248,252)
	titleBar.BorderSizePixel = 0
	local titleCorner = Instance.new("UICorner", titleBar)
	titleCorner.CornerRadius = UDim.new(0,14)

	local titleText = Instance.new("TextLabel", titleBar)
	titleText.Size = UDim2.new(1, -120, 1, 0)
	titleText.Position = UDim2.new(0, 16, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "Painel de Controle"
	titleText.Font = Enum.Font.GothamBold
	titleText.TextSize = 18
	titleText.TextColor3 = Color3.fromRGB(30,30,40)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.TextScaled = true

	-- minimize button
	local minBtn = Instance.new("TextButton", titleBar)
	minBtn.Name = "Minimize"
	minBtn.Size = UDim2.new(0,36,0,36)
	minBtn.Position = UDim2.new(1, -46, 0, 6)
	minBtn.BackgroundColor3 = Color3.fromRGB(245,245,250)
	minBtn.BorderSizePixel = 0
	minBtn.Text = "—"
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 20
	minBtn.TextColor3 = Color3.fromRGB(80,80,90)
	minBtn.AutoButtonColor = false
	local minCorner = Instance.new("UICorner", minBtn)
	minCorner.CornerRadius = UDim.new(0,8)

	-- content as ScrollingFrame
	local content = Instance.new("ScrollingFrame", panel)
	content.Name = "Content"
	content.Size = UDim2.new(1, -24, 1, -68)
	content.Position = UDim2.new(0, 12, 0, 56)
	content.BackgroundTransparency = 1
	content.ScrollBarThickness = 8
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarImageColor3 = Color3.fromRGB(150,150,200)
	content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

	local listLayout = Instance.new("UIListLayout", content)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0,12)
	local padding = Instance.new("UIPadding", content)
	padding.PaddingTop = UDim.new(0,6)
	padding.PaddingBottom = UDim.new(0,6)
	padding.PaddingLeft = UDim.new(0,6)
	padding.PaddingRight = UDim.new(0,6)

	-- Scroll arrows
	local upArrow = Instance.new("TextButton", panel)
	upArrow.Name = "UpArrow"
	upArrow.Size = UDim2.new(0,32,0,32)
	upArrow.Position = UDim2.new(0.5, -16, 0, 8)
	upArrow.BackgroundColor3 = Color3.fromRGB(240,240,245)
	upArrow.Text = "▲"
	upArrow.Font = Enum.Font.GothamBold
	upArrow.TextSize = 16
	upArrow.Visible = false
	local upCorner = Instance.new("UICorner", upArrow)
	upCorner.CornerRadius = UDim.new(0,8)

	local downArrow = Instance.new("TextButton", panel)
	downArrow.Name = "DownArrow"
	downArrow.Size = UDim2.new(0,32,0,32)
	downArrow.Position = UDim2.new(0.5, -16, 1, -40)
	downArrow.BackgroundColor3 = Color3.fromRGB(240,240,245)
	downArrow.Text = "▼"
	downArrow.Font = Enum.Font.GothamBold
	downArrow.TextSize = 16
	downArrow.Visible = false
	local downCorner = Instance.new("UICorner", downArrow)
	downCorner.CornerRadius = UDim.new(0,8)

	-- Toggle button
	local toggleBtn = Instance.new("TextButton", content)
	toggleBtn.Name = "ToggleFly"
	toggleBtn.Size = UDim2.new(1,0,0,44)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(245,245,250)
	toggleBtn.BorderSizePixel = 0
	toggleBtn.AutoButtonColor = false
	toggleBtn.Text = "▶  Ativar Fly  [F]"
	toggleBtn.Font = Enum.Font.GothamSemibold
	toggleBtn.TextSize = 14
	toggleBtn.TextColor3 = Color3.fromRGB(60,60,80)
	toggleBtn.TextScaled = true
	local toggleCorner = Instance.new("UICorner", toggleBtn)
	toggleCorner.CornerRadius = UDim.new(0,10)
	toggleBtn.LayoutOrder = 1

	-- status row
	local statusRow = Instance.new("Frame", content)
	statusRow.Size = UDim2.new(1,0,0,24)
	statusRow.BackgroundTransparency = 1
	statusRow.LayoutOrder = 2
	local statusDot = Instance.new("Frame", statusRow)
	statusDot.Size = UDim2.new(0,10,0,10); statusDot.Position = UDim2.new(0,0,0,7)
	statusDot.BackgroundColor3 = Color3.fromRGB(200,200,210)
	statusDot.BorderSizePixel = 0
	local sdCorner = Instance.new("UICorner", statusDot); sdCorner.CornerRadius = UDim.new(1,0)
	local statusLabel = Instance.new("TextLabel", statusRow)
	statusLabel.Size = UDim2.new(1,-18,1,0); statusLabel.Position = UDim2.new(0,18,0,0)
	statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Idle"
	statusLabel.Font = Enum.Font.Gotham; statusLabel.TextSize = 14; statusLabel.TextColor3 = Color3.fromRGB(160,160,180); statusLabel.TextScaled = true

	-- Helper to create sliders (returns frame)
	local function createSlider(labelText, minVal, maxVal, default, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1,0,0,64)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local header = Instance.new("Frame", frame)
		header.Size = UDim2.new(1,0,0,20)
		header.BackgroundTransparency = 1

		local label = Instance.new("TextLabel", header)
		label.Size = UDim2.new(0.6,0,1,0); label.BackgroundTransparency = 1
		label.Text = labelText; label.Font = Enum.Font.GothamSemibold; label.TextSize = 14; label.TextColor3 = Color3.fromRGB(70,70,90); label.TextScaled = true

		local numberLabel = Instance.new("TextLabel", header)
		numberLabel.Size = UDim2.new(0.4,-6,1,0); numberLabel.Position = UDim2.new(0.6,6,0,0)
		numberLabel.BackgroundTransparency = 1; numberLabel.Text = tostring(default)
		numberLabel.Font = Enum.Font.GothamBold; numberLabel.TextSize = 14; numberLabel.TextColor3 = Color3.fromRGB(100,100,240); numberLabel.TextScaled = true
		numberLabel.TextXAlignment = Enum.TextXAlignment.Right

		local track = Instance.new("Frame", frame)
		track.Name = labelText .. "Slider"
		track.Size = UDim2.new(1,0,0,12)
		track.Position = UDim2.new(0,0,0,32)
		track.BackgroundColor3 = Color3.fromRGB(45,45,58); track.BorderSizePixel = 0
		track.Active = true
		local tc = Instance.new("UICorner", track); tc.CornerRadius = UDim.new(1,0)
		local fill = Instance.new("Frame", track); fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(100,100,240); fill.BorderSizePixel = 0
		local fc = Instance.new("UICorner", fill); fc.CornerRadius = UDim.new(1,0)
		local thumb = Instance.new("TextButton", track); thumb.Size = UDim2.new(0,20,0,20); thumb.AnchorPoint = Vector2.new(0.5,0.5)
		thumb.Position = UDim2.new(0, 0, 0.5, 0); thumb.Text = ""; thumb.BackgroundColor3 = Color3.fromRGB(255,255,255); thumb.BorderSizePixel = 0; thumb.AutoButtonColor = false
		local thc = Instance.new("UICorner", thumb); thc.CornerRadius = UDim.new(1,0)

		-- set functions
		local function setPercent(p)
			p = Utils.clamp(p,0,1)
			local value = math.floor(minVal + p * (maxVal - minVal) + 0.5)
			numberLabel.Text = tostring(value)
			local w = track.AbsoluteSize.X
			local x = p * w
			thumb.Position = UDim2.new(0, x, 0.5, 0)
			fill.Size = UDim2.new(0, x, 1, 0)
			return value
		end

		-- handle dragging
		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliderDragging = track
				local pos = inp.Position
				local w = track.AbsoluteSize.X
				if w > 0 then
					local percent = (pos.X - track.AbsolutePosition.X) / w
					local val = setPercent(percent)
					return val
				end
			end
		end)
		thumb.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliderDragging = track
			end
		end)

		-- initialize
		task.defer(function()
			local p = (default - minVal) / math.max(1, (maxVal - minVal))
			setPercent(p)
		end)

		-- expose updateFromValue for external callback
		frame.SetValueFromPercent = function(percent)
			return setPercent(percent)
		end

		frame.GetTrack = function() return track end
		frame.GetNumberLabel = function() return numberLabel end

		return frame
	end

	-- create sliders
	local flySlider = createSlider("Fly Speed", LIMITS.Speed.min, LIMITS.Speed.max, DEFAULTS.FlySpeed, 3)
	flySlider.LayoutOrder = 3; flySlider.Parent = content
	local jumpSlider = createSlider("JumpPower", LIMITS.Jump.min, LIMITS.Jump.max, DEFAULTS.JumpPower, 4)
	jumpSlider.LayoutOrder = 4; jumpSlider.Parent = content
	local walkSlider = createSlider("WalkSpeed", LIMITS.Walk.min, LIMITS.Walk.max, DEFAULTS.WalkSpeed, 5)
	walkSlider.LayoutOrder = 5; walkSlider.Parent = content

	-- Keybind section (record key & mode)
	local kbFrame = Instance.new("Frame", content)
	kbFrame.Size = UDim2.new(1,0,0,48); kbFrame.LayoutOrder = 6; kbFrame.BackgroundTransparency = 1
	local kbLabel = Instance.new("TextLabel", kbFrame)
	kbLabel.Size = UDim2.new(0.5,0,1,0); kbLabel.BackgroundTransparency = 1; kbLabel.Text = "Keybind:"; kbLabel.Font = Enum.Font.GothamSemibold; kbLabel.TextScaled = true
	local keyBtn = Instance.new("TextButton", kbFrame)
	keyBtn.Size = UDim2.new(0.4, -6, 0.6, 0); keyBtn.Position = UDim2.new(0.5,6,0.2,0)
	keyBtn.Text = tostring(DEFAULTS.ToggleKey.Name); keyBtn.AutoButtonColor = false; keyBtn.Font = Enum.Font.GothamBold; keyBtn.TextScaled = true
	local modeToggle = Instance.new("TextButton", kbFrame)
	modeToggle.Size = UDim2.new(0.12,0,0.6,0); modeToggle.Position = UDim2.new(0.92, -36, 0.2, 0)
	modeToggle.Text = "T" -- T = Toggle, H = Hold
	modeToggle.AutoButtonColor = false; modeToggle.Font = Enum.Font.GothamBold; modeToggle.TextScaled = true

	-- Presets section (save/load)
	local presetFrame = Instance.new("Frame", content)
	presetFrame.Size = UDim2.new(1,0,0,140); presetFrame.LayoutOrder = 7; presetFrame.BackgroundTransparency = 1

	local presetLabel = Instance.new("TextLabel", presetFrame)
	presetLabel.Size = UDim2.new(1,0,0,20); presetLabel.BackgroundTransparency = 1; presetLabel.Text = "Presets"; presetLabel.Font = Enum.Font.GothamSemibold; presetLabel.TextScaled = true

	local presetInput = Instance.new("TextBox", presetFrame)
	presetInput.Size = UDim2.new(0.6, -6, 0, 28); presetInput.Position = UDim2.new(0, 6, 0, 30)
	presetInput.PlaceholderText = "Nome do preset"; presetInput.Text = ""; presetInput.Font = Enum.Font.Gotham; presetInput.TextScaled = true

	local savePresetBtn = Instance.new("TextButton", presetFrame)
	savePresetBtn.Size = UDim2.new(0.2, -6, 0, 28); savePresetBtn.Position = UDim2.new(0.62, 6, 0, 30)
	savePresetBtn.Text = "Salvar"; savePresetBtn.AutoButtonColor = false; savePresetBtn.Font = Enum.Font.GothamBold; savePresetBtn.TextScaled = true

	local presetList = Instance.new("Frame", presetFrame)
	presetList.Size = UDim2.new(1, -12, 0, 68); presetList.Position = UDim2.new(0, 6, 0, 66); presetList.BackgroundTransparency = 1
	local presetLayout = Instance.new("UIListLayout", presetList)
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	presetLayout.Padding = UDim.new(0,8)

	-- Tooltip (shared)
	local tooltip = Instance.new("TextLabel", screenGui)
	tooltip.Size = UDim2.new(0,200,0,36)
	tooltip.BackgroundColor3 = Color3.fromRGB(30,30,30)
	tooltip.TextColor3 = Color3.fromRGB(255,255,255)
	tooltip.TextScaled = true
	tooltip.Visible = false
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.ZIndex = 1000
	local tipCorner = Instance.new("UICorner", tooltip)
	tipCorner.CornerRadius = UDim.new(0,8)
	tooltip.BackgroundTransparency = 0.15

	-- Bubble (minimized)
	local bubble = Instance.new("TextButton", screenGui)
	bubble.Name = "MinimizedBubble"
	bubble.Size = UDim2.new(0, 64, 0, 64)
	bubble.BackgroundColor3 = Color3.fromRGB(100,100,240)
	bubble.Text = "⦿"
	bubble.Font = Enum.Font.GothamBold
	bubble.TextSize = 32
	bubble.TextColor3 = Color3.fromRGB(255,255,255)
	bubble.BorderSizePixel = 0
	bubble.Visible = false
	local bubbleCorner = Instance.new("UICorner", bubble)
	bubbleCorner.CornerRadius = UDim.new(1,0)

	-- return handles
	return {
		ScreenGui = screenGui,
		Panel = panel,
		TitleBar = titleBar,
		MinimizeBtn = minBtn,
		Content = content,
		ListLayout = listLayout,
		UpArrow = upArrow,
		DownArrow = downArrow,
		ToggleBtn = toggleBtn,
		StatusDot = statusDot,
		StatusLabel = statusLabel,
		FlySlider = flySlider,
		JumpSlider = jumpSlider,
		WalkSlider = walkSlider,
		KeyBtn = keyBtn,
		ModeToggle = modeToggle,
		PresetInput = presetInput,
		SavePresetBtn = savePresetBtn,
		PresetList = presetList,
		Tooltip = tooltip,
		Bubble = bubble
	}
end

-- =========================
-- Controller: orquestra tudo
-- =========================
local Controller = {}
function Controller:init()
	-- load config
	self.config = SettingsManager.loadConfig()
	InputManager.loadFromConfig(self.config)

	-- create UI
	self.ui = UIFactory.create()
	self.screenGui = self.ui.ScreenGui
	self.panel = self.ui.Panel
	self.content = self.ui.Content
	self.flySlider = self.ui.FlySlider
	self.jumpSlider = self.ui.JumpSlider
	self.walkSlider = self.ui.WalkSlider
	self.toggleBtn = self.ui.ToggleBtn
	self.statusDot = self.ui.StatusDot
	self.statusLabel = self.ui.StatusLabel
	self.minBtn = self.ui.MinimizeBtn
	self.upArrow = self.ui.UpArrow
	self.downArrow = self.ui.DownArrow
	self.keyBtn = self.ui.KeyBtn
	self.modeToggle = self.ui.ModeToggle
	self.presetInput = self.ui.PresetInput
	self.savePresetBtn = self.ui.SavePresetBtn
	self.presetList = self.ui.PresetList
	self.tooltip = self.ui.Tooltip
	self.bubble = self.ui.Bubble

	-- state
	self.flying = false
	self.connections = {}
	self.sliderDragging = nil

	-- apply loaded config to sliders & UI
	self:applyConfigToUI()

	-- connect events
	self:connectUI()
	-- update arrows first time (defer for layout)
	task.defer(function() self:updateScrollArrows() end)
	-- load presets into UI
	self:refreshPresetButtons()
end

function Controller:applyConfigToUI()
	-- set slider initial values from config (or defaults)
	local cfg = self.config
	-- fly slider percent
	local pFly = (cfg.FlySpeed or DEFAULTS.FlySpeed - LIMITS.Speed.min) / math.max(1, LIMITS.Speed.max - LIMITS.Speed.min)
	self.flySlider.SetValueFromPercent((cfg.FlySpeed or DEFAULTS.FlySpeed - LIMITS.Speed.min) / math.max(1, LIMITS.Speed.max - LIMITS.Speed.min))
	-- set number labels directly as fallback
	local function setLabelFromSlider(slider, val)
		local lbl = slider:GetNumberLabel()
		if lbl then lbl.Text = tostring(val) end
	end
	-- update sliders with saved values
	if cfg.FlySpeed then
		local p = (cfg.FlySpeed - LIMITS.Speed.min)/math.max(1, LIMITS.Speed.max - LIMITS.Speed.min)
		self.flySlider.SetValueFromPercent(p)
	end
	if cfg.JumpPower then
		local p = (cfg.JumpPower - LIMITS.Jump.min)/math.max(1, LIMITS.Jump.max - LIMITS.Jump.min)
		self.jumpSlider.SetValueFromPercent(p)
	end
	if cfg.WalkSpeed then
		local p = (cfg.WalkSpeed - LIMITS.Walk.min)/math.max(1, LIMITS.Walk.max - LIMITS.Walk.min)
		self.walkSlider.SetValueFromPercent(p)
	end

	-- key button
	self.keyBtn.Text = (self.config.ToggleKey and tostring(self.config.ToggleKey) or tostring(InputManager.currentKey.Name))
	-- mode toggle text
	self.modeToggle.Text = (self.config.InputMode == "Hold") and "H" or "T"
end

function Controller:connectUI()
	-- store conns for cleanup
	local function watch(conn) table.insert(self.connections, conn) end

	-- Hover tooltips helper
	local function attachTooltip(inst, text)
		if not inst then return end
		inst.MouseEnter:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			self.tooltip.Text = text
			self.tooltip.Position = UDim2.new(0, pos.X, 0, pos.Y - 8)
			self.tooltip.Visible = true
		end)
		inst.MouseLeave:Connect(function() self.tooltip.Visible = false end)
	end

	attachTooltip(self.toggleBtn, "Ativa/Desativa o fly\nAtalho: " .. tostring(InputManager.currentKey.Name))
	attachTooltip(self.minBtn, "Minimizar")
	attachTooltip(self.bubble, "Restaurar painel")
	attachTooltip(self.savePresetBtn, "Salvar preset atual")

	-- toggle fly button
	local function setUIFlying(state)
		local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
		if state then
			Utils.tween(self.toggleBtn, {BackgroundColor3 = Color3.fromRGB(100,100,240), TextColor3 = Color3.fromRGB(255,255,255)}, 0.18)
			Utils.tween(self.statusDot, {BackgroundColor3 = Color3.fromRGB(100,220,130)}, 0.18)
			self.toggleBtn.Text = "■  Desativar Fly  [" .. tostring(InputManager.currentKey.Name) .. "]"
			self.statusLabel.Text = "Flying"
			self.statusLabel.TextColor3 = Color3.fromRGB(80,180,110)
		else
			Utils.tween(self.toggleBtn, {BackgroundColor3 = Color3.fromRGB(245,245,250), TextColor3 = Color3.fromRGB(60,60,80)}, 0.18)
			Utils.tween(self.statusDot, {BackgroundColor3 = Color3.fromRGB(200,200,210)}, 0.18)
			self.toggleBtn.Text = "▶  Ativar Fly  [" .. tostring(InputManager.currentKey.Name) .. "]"
			self.statusLabel.Text = "Idle"
			self.statusLabel.TextColor3 = Color3.fromRGB(160,160,180)
		end
	end

	-- internal heartbeat to update movement when flying
	local hbConn = RunService.Heartbeat:Connect(function()
		if not FlyController.isFlying() or not FlyController.bodyVel then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		-- build input direction
		local dir = Vector3.new(0,0,0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then dir += Vector3.new(0,0,-1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then dir += Vector3.new(0,0,1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then dir += Vector3.new(-1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then dir += Vector3.new(1,0,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then dir += Vector3.new(0,-1,0) end

		local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local sp = (self.config.FlySpeed or DEFAULTS.FlySpeed)
		local speed = sprinting and sp * (self.config.SprintMult or DEFAULTS.SprintMult) or sp

		if dir.Magnitude > 0 then
			local world = cam.CFrame:VectorToWorldSpace(dir).Unit
			FlyController.bodyVel.Velocity = world * speed
			local lookDir = Vector3.new(world.X, 0, world.Z)
			if lookDir.Magnitude > 0.01 then
				FlyController.bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir)
			end
		else
			FlyController.bodyVel.Velocity = FlyController.bodyVel.Velocity * 0.85
		end
	end)
	watch(hbConn)

	-- toggle button action
	self.toggleBtn.Activated:Connect(function()
		if FlyController.isFlying() then
			FlyController.disable()
			setUIFlying(false)
		else
			FlyController.enable()
			setUIFlying(true)
		end
	end)

	-- key input handling (Toggle vs Hold)
	local kbConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == InputManager.currentKey then
				-- depending on mode
				if InputManager.inputMode == "Toggle" then
					if FlyController.isFlying() then FlyController.disable(); setUIFlying(false)
					else FlyController.enable(); setUIFlying(true) end
				else -- Hold
					if not FlyController.isFlying() then FlyController.enable(); setUIFlying(true) end
				end
			end
		end
	end)
	watch(kbConn)

	local kbUpConn = UserInputService.InputEnded:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == InputManager.currentKey and InputManager.inputMode == "Hold" then
				-- stop flying when key released
				if FlyController.isFlying() then FlyController.disable(); setUIFlying(false) end
			end
		end
	end)
	watch(kbUpConn)

	-- slider input handling (global InputChanged)
	local ic = UserInputService.InputChanged:Connect(function(input)
		if not sliderDragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local track = sliderDragging
			local trackWidth = track.AbsoluteSize.X
			if trackWidth <= 0 then return end
			local percent = (input.Position.X - track.AbsolutePosition.X) / trackWidth
			percent = Utils.clamp(percent, 0, 1)
			-- determine which slider
			local name = track.Name
			local val
			if name == "Fly SpeedSlider" then
				val = math.floor(LIMITS.Speed.min + percent * (LIMITS.Speed.max - LIMITS.Speed.min) + 0.5)
				-- update UI fill/thumb
				local thumb = track:FindFirstChildOfClass("TextButton")
				local fill = track:FindFirstChildOfClass("Frame")
				if thumb then thumb.Position = UDim2.new(0, percent * trackWidth, 0.5, 0) end
				if fill then fill.Size = UDim2.new(percent, 0, 1, 0) end
				self.config.FlySpeed = val
			elseif name == "JumpPowerSlider" then
				val = math.floor(LIMITS.Jump.min + percent * (LIMITS.Jump.max - LIMITS.Jump.min) + 0.5)
				local thumb = track:FindFirstChildOfClass("TextButton")
				local fill = track:FindFirstChildOfClass("Frame")
				if thumb then thumb.Position = UDim2.new(0, percent * trackWidth, 0.5, 0) end
				if fill then fill.Size = UDim2.new(percent, 0, 1, 0) end
				self.config.JumpPower = val
			elseif name == "WalkSpeedSlider" then
				val = math.floor(LIMITS.Walk.min + percent * (LIMITS.Walk.max - LIMITS.Walk.min) + 0.5)
				local thumb = track:FindFirstChildOfClass("TextButton")
				local fill = track:FindFirstChildOfClass("Frame")
				if thumb then thumb.Position = UDim2.new(0, percent * trackWidth, 0.5, 0) end
				if fill then fill.Size = UDim2.new(percent, 0, 1, 0) end
				self.config.WalkSpeed = val
			end
			-- apply to humanoid
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				if self.config.JumpPower then humanoid.UseJumpPower = true; humanoid.JumpPower = self.config.JumpPower end
				if self.config.WalkSpeed then humanoid.WalkSpeed = self.config.WalkSpeed end
			end
			-- save config
			SettingsManager.saveConfig(self.config)
		end
	end)
	watch(ic)

	-- InputEnded for slider drag stop
	local ie = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = nil
		end
	end)
	watch(ie)

	-- attach InputBegan listeners to sliders (we created them in UIFactory)
	-- We need to find the track frames and attach InputBegan to update sliderDragging variable
	local function attachSliderListeners(sliderFrame)
		if not sliderFrame then return end
		local track = sliderFrame:GetTrack()
		if track then
			track.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					sliderDragging = track
					-- simulate immediate update
					local pos = inp.Position
					local trackWidth = track.AbsoluteSize.X
					if trackWidth > 0 then
						local percent = (pos.X - track.AbsolutePosition.X) / trackWidth
						percent = Utils.clamp(percent, 0, 1)
						-- call InputChanged manually by setting sliderDragging and using InputChanged handler above (works on next movement)
					end
				end
			end)
			local thumb = track:FindFirstChildOfClass("TextButton")
			if thumb then
				thumb.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						sliderDragging = track
					end
				end)
			end
		end
	end
	attachSliderListeners(self.flySlider)
	attachSliderListeners(self.jumpSlider)
	attachSliderListeners(self.walkSlider)

	-- Minimize button
	self.minBtn.Activated:Connect(function()
		if self.panel.Visible and not self.panel:IsDescendantOf(game) then return end
		if self.panel.Visible then
			-- store position
			self.savedPanelPosition = self.panel.Position
			-- compute bubble pos near panel corner
			local abs = self.panel.AbsolutePosition
			local bw = self.bubble.AbsoluteSize.X
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local bx = math.clamp(abs.X + self.panel.AbsoluteSize.X - bw - 8, 8, vp.X - bw - 8)
			local by = math.clamp(abs.Y + 8, 8, vp.Y - self.bubble.AbsoluteSize.Y - 8)
			self.bubble.Position = UDim2.new(0, bx, 0, by)
			self.bubble.Visible = true
			Utils.tween(self.panel, {Size = UDim2.new(0.16,0,0.1,0)}, 0.18)
			task.delay(0.18, function()
				self.panel.Visible = false
				self.panel.Size = UDim2.new(0.24,0,0.55,0)
			end)
		else
			-- restore
			self.panel.Position = self.savedPanelPosition or UDim2.new(0.02,0,0.22,0)
			self.panel.Visible = true
			self.bubble.Visible = false
		end
	end)

	-- Bubble drag & snap
	local draggingBubble = false
	local bubbleStartPos, bubbleDragStart = nil, nil
	self.bubble.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			draggingBubble = true
			bubbleDragStart = inp.Position
			bubbleStartPos = self.bubble.Position
		end
	end)
	local bubbleChangedConn = UserInputService.InputChanged:Connect(function(inp)
		if draggingBubble and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - bubbleDragStart
			local newX = bubbleStartPos.X.Offset + delta.X
			local newY = bubbleStartPos.Y.Offset + delta.Y
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local ox = math.clamp(newX, 8, vp.X - self.bubble.AbsoluteSize.X - 8)
			local oy = math.clamp(newY, 8, vp.Y - self.bubble.AbsoluteSize.Y - 8)
			self.bubble.Position = UDim2.new(0, ox, 0, oy)
		end
	end)
	watch(bubbleChangedConn)
	UserInputService.InputEnded:Connect(function(inp)
		if draggingBubble and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
			-- snap to nearest edge
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local centerX = self.bubble.AbsolutePosition.X + self.bubble.AbsoluteSize.X/2
			local centerY = self.bubble.AbsolutePosition.Y + self.bubble.AbsoluteSize.Y/2
			local leftDist = centerX
			local rightDist = vp.X - centerX
			local topDist = centerY
			local bottomDist = vp.Y - centerY
			local minEdge = math.min(leftDist, rightDist, topDist, bottomDist)
			local targetX, targetY = self.bubble.AbsolutePosition.X, self.bubble.AbsolutePosition.Y
			if minEdge == leftDist then
				targetX = 8
			elseif minEdge == rightDist then
				targetX = vp.X - self.bubble.AbsoluteSize.X - 8
			elseif minEdge == topDist then
				targetY = 8
			else
				targetY = vp.Y - self.bubble.AbsoluteSize.Y - 8
			end
			Utils.tween(self.bubble, {Position = UDim2.new(0, targetX, 0, targetY)}, 0.18)
		end
		draggingBubble = false
	end)

	-- bubble click restores
	self.bubble.Activated:Connect(function() 
		self.panel.Visible = true
		self.bubble.Visible = false
	end)

	-- set keybind recording UI
	self.keyBtn.Activated:Connect(function()
		-- start recording next key
		self.keyBtn.Text = "Pressione uma tecla..."
		InputManager.startRecord(function(key)
			-- update current key and config, save
			self.config.ToggleKey = tostring(key.Name)
			InputManager.currentKey = key
			-- update text
			self.keyBtn.Text = tostring(key.Name)
			-- save config
			SettingsManager.saveConfig(self.config)
		end)
	end)

	-- mode toggle between Toggle/Hold
	self.modeToggle.Activated:Connect(function()
		if InputManager.inputMode == "Toggle" then
			InputManager.inputMode = "Hold"
			self.modeToggle.Text = "H"
		else
			InputManager.inputMode = "Toggle"
			self.modeToggle.Text = "T"
		end
		self.config.InputMode = InputManager.inputMode
		SettingsManager.saveConfig(self.config)
	end)

	-- Save preset
	self.savePresetBtn.Activated:Connect(function()
		local name = tostring(self.presetInput.Text or ""):gsub("^%s*(.-)%s*$","%1")
		if name == "" then
			-- quick feedback
			self.presetInput.Text = ""
			self.presetInput.PlaceholderText = "Informe um nome válido"
			task.delay(1.2, function() if self.presetInput then self.presetInput.PlaceholderText = "Nome do preset" end end)
			return
		end
		local preset = {
			FlySpeed = self.config.FlySpeed or DEFAULTS.FlySpeed,
			JumpPower = self.config.JumpPower or DEFAULTS.JumpPower,
			WalkSpeed = self.config.WalkSpeed or DEFAULTS.WalkSpeed,
			SprintMult = self.config.SprintMult or DEFAULTS.SprintMult,
			ToggleKey = tostring(InputManager.currentKey.Name),
			InputMode = InputManager.inputMode
		}
		SettingsManager.savePreset(name, preset)
		self:refreshPresetButtons()
		self.presetInput.Text = ""
	end)

	-- preset buttons refresh
	function self:refreshPresetButtons()
		-- clear children
		for _,c in ipairs(self.presetList:GetChildren()) do
			if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
		end
		local presets = SettingsManager.getPresets()
		for name, data in pairs(presets) do
			local btn = Instance.new("TextButton", self.presetList)
			btn.Size = UDim2.new(0, 120, 0, 36)
			btn.BackgroundColor3 = Color3.fromRGB(240,240,245)
			btn.Text = name
			btn.Font = Enum.Font.Gotham
			btn.TextScaled = true
			btn.AutoButtonColor = false
			local btnCorner = Instance.new("UICorner", btn)
			btn.Activated:Connect(function()
				-- load preset
				self.config.FlySpeed = data.FlySpeed or self.config.FlySpeed
				self.config.JumpPower = data.JumpPower or self.config.JumpPower
				self.config.WalkSpeed = data.WalkSpeed or self.config.WalkSpeed
				self.config.SprintMult = data.SprintMult or self.config.SprintMult
				-- key & mode
				local keyname = data.ToggleKey
				if keyname and type(keyname) == "string" then
					local ok, enum = pcall(function() return Enum.KeyCode[keyname] end)
					if ok and enum then InputManager.currentKey = enum end
				end
				InputManager.inputMode = data.InputMode or InputManager.inputMode
				-- apply to UI
				self.keyBtn.Text = tostring(InputManager.currentKey.Name)
				self.modeToggle.Text = (InputManager.inputMode == "Hold") and "H" or "T"
				-- update sliders visually
				if self.config.FlySpeed then
					local p = (self.config.FlySpeed - LIMITS.Speed.min)/math.max(1, (LIMITS.Speed.max - LIMITS.Speed.min))
					self.flySlider.SetValueFromPercent(p)
				end
				if self.config.JumpPower then
					local p = (self.config.JumpPower - LIMITS.Jump.min)/math.max(1, (LIMITS.Jump.max - LIMITS.Jump.min))
					self.jumpSlider.SetValueFromPercent(p)
				end
				if self.config.WalkSpeed then
					local p = (self.config.WalkSpeed - LIMITS.Walk.min)/math.max(1, (LIMITS.Walk.max - LIMITS.Walk.min))
					self.walkSlider.SetValueFromPercent(p)
				end
				-- apply to humanoid now
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if self.config.JumpPower then humanoid.UseJumpPower = true; humanoid.JumpPower = self.config.JumpPower end
					if self.config.WalkSpeed then humanoid.WalkSpeed = self.config.WalkSpeed end
				end
				-- save config
				SettingsManager.saveConfig(self.config)
			end)
			-- right-click for delete/rename (simple: double click to delete)
			local lastClick = 0
			btn.MouseButton1Click:Connect(function()
				local now = tick()
				if now - lastClick < 0.4 then
					-- double click -> delete
					SettingsManager.deletePreset(name)
					self:refreshPresetButtons()
				end
				lastClick = now
			end)
		end
	end

	-- scroll arrows behavior
	self.content:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:updateScrollArrows() end)
	self.content:GetPropertyChangedSignal("CanvasSize"):Connect(function() self:updateScrollArrows() end)
	self.upArrow.Activated:Connect(function()
		-- scroll up a page
		local ypos = math.max(0, self.content.CanvasPosition.Y - self.content.AbsoluteWindowSize.Y + 40)
		self.content.CanvasPosition = Vector2.new(0, ypos)
	end)
	self.downArrow.Activated:Connect(function()
		local ypos = math.min(math.max(0, self.content.CanvasSize.Y.Offset - self.content.AbsoluteWindowSize.Y), self.content.CanvasPosition.Y + self.content.AbsoluteWindowSize.Y - 40)
		self.content.CanvasPosition = Vector2.new(0, ypos)
	end)

	-- update arrows initial
	self:updateScrollArrows()

	-- cleanup on GUI destroy
	self.screenGui.Destroying:Connect(function()
		-- stop flying & restore collisions
		if FlyController.isFlying() then FlyController.disable() end
		-- cleanup any connections
		for _,c in ipairs(self.connections) do
			if c and typeof(c) == "RBXScriptConnection" and c.Connected then c:Disconnect() end
		end
	end)
end

-- update scroll arrows function
function Controller:updateScrollArrows()
	local content = self.content
	if not content or not content:IsA("ScrollingFrame") then return end
	-- short delay for layout stabilization
	task.defer(function()
		local canScroll = content.CanvasSize.Y.Offset > content.AbsoluteWindowSize.Y + 4
		if not canScroll then
			self.upArrow.Visible = false
			self.downArrow.Visible = false
			return
		end
		local y = content.CanvasPosition.Y
		local maxY = math.max(0, content.CanvasSize.Y.Offset - content.AbsoluteWindowSize.Y)
		self.upArrow.Visible = (y > 2)
		self.downArrow.Visible = (y < maxY - 2)
	end)
end

-- =========================
-- Inicialização
-- =========================
local controller = {}
setmetatable(controller, {__index = Controller})
controller:init()

-- Save current slider values periodically or on change (we saved on slider updates already)
-- Ensure config gets saved when changing sliders via UI by calling SettingsManager.saveConfig when values change.
-- For safety, ensure config has keys set from UI on start
local function syncConfigFromUI()
	controller.config.FlySpeed = controller.config.FlySpeed or DEFAULTS.FlySpeed
	controller.config.JumpPower = controller.config.JumpPower or DEFAULTS.JumpPower
	controller.config.WalkSpeed = controller.config.WalkSpeed or DEFAULTS.WalkSpeed
	controller.config.SprintMult = controller.config.SprintMult or DEFAULTS.SprintMult
	controller.config.ToggleKey = controller.config.ToggleKey or tostring(InputManager.currentKey.Name)
	controller.config.InputMode = controller.config.InputMode or InputManager.inputMode
	SettingsManager.saveConfig(controller.config)
end
syncConfigFromUI()

-- Expose global convenience for dev console
_G.FlyControl = {
	Enable = function() FlyController.enable() end,
	Disable = function() FlyController.disable() end,
	Toggle = function() if FlyController.isFlying() then FlyController.disable() else FlyController.enable() end end,
	IsFlying = function() return FlyController.isFlying() end,
	SaveSettings = function() SettingsManager.saveConfig(controller.config) end,
	LoadSettings = function() controller.config = SettingsManager.loadConfig(); controller:applyConfigToUI() end,
	SettingsManager = SettingsManager
}

print("[FlyControl] UI loaded. Use _G.FlyControl.Toggle() to test from console.")
