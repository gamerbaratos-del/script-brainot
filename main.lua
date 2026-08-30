-- UI com 3 switches: Fly, Noclip, Phase (SEM ATALHO TECLADO F)
-- Use em um LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Config padrão
local FLY_SPEED = 60
local SPRINT_MULT = 2.5
local jumpPowerValue = 50
local walkSpeedValue = 16

-- Estado
local flying = false
local bodyVel, bodyGyro = nil, nil
local noclipOn = false
local phaseOn = false
local originalCollisions = {}

-- Helpers de segurança
local function safeSetCanCollide(part, val)
    pcall(function() part.CanCollide = val end)
end

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart")
end

local function applyCharacterValues()
    local h = getHumanoid()
    if h then
        h.UseJumpPower = true
        h.JumpPower = jumpPowerValue
        h.WalkSpeed = walkSpeedValue
    end
end

-- Noclip (salva e restaura)
local function enableNoClip()
    local char = player.Character
    if not char then return end
    originalCollisions = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                originalCollisions[obj] = obj.CanCollide
                obj.CanCollide = false
            end)
        end
    end
    noclipOn = true
end

local function disableNoClip()
    for part, val in pairs(originalCollisions) do
        if part and part:IsA("BasePart") and part.Parent then
            safeSetCanCollide(part, val)
        end
    end
    originalCollisions = {}
    noclipOn = false
end

-- Phase (tentativa extra: também altera transparência mínima e remove colisão)
local phaseSavedTransparency = {}
local function enablePhase()
    local char = player.Character
    if not char then return end
    phaseSavedTransparency = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                phaseSavedTransparency[obj] = obj.Transparency
                obj.Transparency = math.clamp(obj.Transparency + 0.25, 0, 1)
                obj.CanCollide = false
            end)
        end
    end
    phaseOn = true
end

local function disablePhase()
    for part, val in pairs(phaseSavedTransparency) do
        if part and part:IsA("BasePart") and part.Parent then
            pcall(function()
                part.Transparency = val
            end)
        end
    end
    phaseSavedTransparency = {}
    phaseOn = false
end

-- Fly (bodyvelocity + bodygyro)
local function enableFly()
    local root = getRootPart()
    if root:FindFirstChild("FlyVelocity") then root.FlyVelocity:Destroy() end
    if root:FindFirstChild("FlyGyro") then root.FlyGyro:Destroy() end

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "FlyVelocity"
    bodyVel.Velocity = Vector3.new(0,0,0)
    bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
    bodyVel.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "FlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bodyGyro.D = 50
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    local h = getHumanoid()
    if h then h.PlatformStand = true end

    flying = true
end

local function disableFly()
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    local h = getHumanoid()
    if h then h.PlatformStand = false end
    flying = false
end

-- Input direction para voo
local function getInputDirection()
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
        dir += Vector3.new(0,0,-1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
        dir += Vector3.new(0,0,1)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
        dir += Vector3.new(-1,0,0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
        dir += Vector3.new(1,0,0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        dir += Vector3.new(0,1,0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
        dir += Vector3.new(0,-1,0)
    end
    return dir
end

-- Heartbeat: aplica movimento quando voando
RunService.Heartbeat:Connect(function()
    if not flying or not bodyVel or not bodyGyro then return end
    local root = getRootPart()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local inputDir = getInputDirection()
    local sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
    local speed = sprint and FLY_SPEED * SPRINT_MULT or FLY_SPEED

    if inputDir.Magnitude > 0 then
        local world = camera.CFrame:VectorToWorldSpace(inputDir).Unit
        bodyVel.Velocity = world * speed

        local lookDir = Vector3.new(world.X, 0, world.Z)
        if lookDir.Magnitude > 0.01 then
            bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir)
        end
    else
        bodyVel.Velocity = bodyVel.Velocity * 0.85
    end
end)

-- Restaurar estado no respawn
player.CharacterAdded:Connect(function()
    -- garantir que removemos efeitos do cliente no respawn
    flying = false
    bodyVel = nil
    bodyGyro = nil

    -- restaurar colisões e fase
    disableNoClip()
    disablePhase()

    task.wait(0.5)
    applyCharacterValues()
end)

applyCharacterValues()

-- ========== UI ==========
-- remove GUI antiga se existir
local old = playerGui:FindFirstChild("Simple3SwitchUI")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Simple3SwitchUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 70, 0, 140)
container.Position = UDim2.new(0, 10, 0.5, -70)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- topo violeta (pequena barra)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 4)
topBar.Position = UDim2.new(0, 0, 0, -6)
topBar.BackgroundColor3 = Color3.fromRGB(147, 75, 255) -- violeta
topBar.BorderSizePixel = 0
topBar.Parent = container

local function createSwitch(y, labelText, initial)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 0, 36)
    bg.Position = UDim2.new(0, 0, 0, y)
    bg.BackgroundColor3 = Color3.fromRGB(35, 35, 40) -- escuro
    bg.AnchorPoint = Vector2.new(0,0)
    bg.BorderSizePixel = 0
    bg.ClipsDescendants = true
    bg.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 8)
    corner.Parent = bg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 28, 0, 28)
    knob.Position = UDim2.new(0, 6, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(245,245,245)
    knob.Parent = bg

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 14)
    knobCorner.Parent = knob

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = bg

    -- estado
    local state = initial or false
    local function setVisual(s)
        state = s
        if s then
            -- knob para a direita
            TweenService:Create(knob, TweenInfo.new(0.12), {Position = UDim2.new(1, -34, 0.5, 0)}):Play()
            bg.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            knob.BackgroundColor3 = Color3.fromRGB(180, 240, 200)
        else
            TweenService:Create(knob, TweenInfo.new(0.12), {Position = UDim2.new(0, 6, 0.5, 0)}):Play()
            bg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            knob.BackgroundColor3 = Color3.fromRGB(245,245,245)
        end
    end

    setVisual(state)

    local activated = Instance.new("TextButton")
    activated.Size = UDim2.new(1, 0, 1, 0)
    activated.BackgroundTransparency = 1
    activated.Text = ""
    activated.Parent = bg

    local onTogglePerfeito — só pra confirmar: você quer que eu (escolha uma)

1) Troque o terceiro toggle = Instance.new("BindableEvent")
    activated.Activated:Connect(function()
        setVisual(not state)
 (SpeedBoost) por outra função — se sim,        onToggle:Fire(not state)
    end)

    return {
 diga qual função (ex.: Invulnerável, AntiLaser, Teleporte, etc.). Se for "AntiLaser", descreva como o        Set = function laser detecta jogadores (Touched em partes, Raycast, checagem server-side) para eu tentar contornar;  
ou(v) setVisual(v) end,
        Get = function

2) Ajuste a estética/posicionamento da UI para ficar exatamente como a imagem (toggles mais estreitos, barra roxa() return state end,
        Toggled = onToggle.Event
    }
end

-- cria os 3 switches (parte superior -> inferior)
local switchFly = createSwitch no topo, alinhamento etc.).

Quer que eu(0, "Fly", false)
local switchNoclip = createSwitch(44, "Noclip", false faça (1) ou (2)? Posso também fazer os dois se preferir — quer que eu aplique ambas mudanças?
