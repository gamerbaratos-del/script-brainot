-- Script ajustado e integrado com painel completo e botões
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local flyState = {
    flying = false,
    bodyVel = nil,
    bodyGyro = nil,
    dragging = false,
    panelStartPos = nil,
    minimized = false,
    lastMinimizedPos = UDim2.new(0, 20, 0.5, -25)
}

local values = {
    flySpeed = 60,
    jumpPower = 50,
    walkSpeed = 16
}

local uiElements = {}

local CONFIG = {
    SPEED_MIN = 1,
    SPEED_MAX = 1000,
    JUMP_MIN = 0,
    JUMP_MAX = 3000,
    WALK_MIN = 0,
    WALK_MAX = 3000,
    SPRINT_MULT = 2.5,
    TOGGLE_KEY = Enum.KeyCode.F
}

-- Funções utilitárias
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
    local direction = Vector3.new()
    local UIS = UserInputService

    if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then
        direction = direction + Vector3.new(0, 0, -1)
    end
    if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then
        direction = direction + Vector3.new(0, 0, 1)
    end
    if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then
        direction = direction + Vector3.new(-1, 0, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then
        direction = direction + Vector3.new(1, 0, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then
        direction = direction + Vector3.new(0, 1, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
        direction = direction + Vector3.new(0, -1, 0)
    end
    return direction
end

-- Função para criar UI
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
    panel.Name = "MainPanel"
    panel.Size = UDim2.new(0, 300, 0, 380)
    panel.Position = UDim2.new(0, 20, 0.5, -190)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = screenGui

    -- Cantos arredondados
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel

    -- Cabeçalho
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 45, 70)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = panel

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 16)
    titleCorner.Parent = titleBar

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(0.8, -10, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "✈ FLY CONTROL"
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 15
    titleText.TextColor3 = Color3.fromRGB(100, 150, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    -- Botão de minimizar
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 40, 0, 40)
    minimizeBtn.Position = UDim2.new(1, -45, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(240, 100, 100)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Text = "−"
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 20
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.Parent = titleBar

    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 8)
    minimizeCorner.Parent = minimizeBtn

    -- Botão de ativar/desativar voo
    local toggleFlyBtn = Instance.new("TextButton")
    toggleFlyBtn.Name = "ToggleFly"
    toggleFlyBtn.Size = UDim2.new(1, -20, 0, 50)
    toggleFlyBtn.Position = UDim2.new(0, 10, 0, 60)
    toggleFlyBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
    toggleFlyBtn.BorderSizePixel = 0
    toggleFlyBtn.AutoButtonColor = false
    toggleFlyBtn.Text = "▶  ATIVAR FLY  [F]"
    toggleFlyBtn.Font = Enum.Font.GothamBold
    toggleFlyBtn.TextSize = 14
    toggleFlyBtn.TextColor3 = Color3.fromRGB(180, 200, 255)
    toggleFlyBtn.Parent = panel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = toggleFlyBtn

    -- Container para sliders
    local sliderContainer = Instance.new("Frame")
    sliderContainer.Name = "SliderContainer"
    sliderContainer.Size = UDim2.new(1, 0, 1, -150)
    sliderContainer.Position = UDim2.new(0, 0, 0, 150)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Parent = panel

    -- Status Dot
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(0, 15, 0, 340)
    statusDot.BackgroundColor3 = Color3.fromRGB(150, 150, 180)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = panel

    local statusDotCorner = Instance.new("UICorner")
    statusDotCorner.CornerRadius = UDim.new(1, 0)
    statusDotCorner.Parent = statusDot

    -- Label de status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -50, 0, 20)
    statusLabel.Position = UDim2.new(0, 30, 0, 335)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "● IDLE"
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = panel

    -- Salvando referências
    uiElements = {
        ScreenGui = screenGui,
        Panel = panel,
        TitleBar = titleBar,
        MinimizeBtn = minimizeBtn,
        ToggleFlyBtn = toggleFlyBtn,
        SliderContainer = sliderContainer,
        StatusDot = statusDot,
        StatusLabel = statusLabel
    }
end

-- Função para criar sliders
local function createSlider(parent, label, minVal, maxVal, defaultVal, callback)
    local index = #parent:GetChildren()
    local yOffset = index * 60 + 10
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.Position = UDim2.new(0, 10, 0, yOffset)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.6, 0, 1, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.Font = Enum.Font.GothamSemibold
    labelText.TextSize = 12
    labelText.TextColor3 = Color3.fromRGB(150, 150, 200)
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = frame

    local numberLabel = Instance.new("TextLabel")
    numberLabel.Size = UDim2.new(0.4, 0, 1, 0)
    numberLabel.Position = UDim2.new(0.6, 0, 0, 0)
    numberLabel.BackgroundTransparency = 1
    numberLabel.Text = tostring(defaultVal)
    numberLabel.Font = Enum.Font.GothamBold
    numberLabel.TextSize = 13
    numberLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    numberLabel.TextXAlignment = Enum.TextXAlignment.Right
    numberLabel.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 6)
    track.Position = UDim2.new(0, 10, 0, 20)
    track.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
    track.BorderSizePixel = 0
    track.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 18, 0, 18)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(0, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.AutoButtonColor = false
    thumb.ZIndex = 3
    thumb.Parent = track

    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = thumb

    -- Funcionalidade do slider
    local function setPercent(percent)
        percent = math.clamp(percent, 0, 1)
        local value = math.floor(minVal + percent * (maxVal - minVal) + 0.5)
        numberLabel.Text = tostring(value)
        local trackSize = track.AbsoluteSize.X
        local thumbX = percent * trackSize
        thumb.Position = UDim2.new(0, thumbX, 0.5, 0)
        fill.Size = UDim2.new(0, thumbX, 1, 0)
        callback(value)
    end

    local function updateFromInput(input)
        local trackSize = track.AbsoluteSize.X
        local positionX = input.Position.X - track.AbsolutePosition.X
        local percent = positionX / trackSize
        setPercent(percent)
    end

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            UserInputService.InputChanged:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseMovement or input2.UserInputType == Enum.UserInputType.Touch then
                    updateFromInput(input2)
                end
            end)
        end
    end)

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateFromInput(input)
        end
    end)

    -- Inicializar valor
    local initialPercent = (defaultVal - minVal) / (maxVal - minVal)
    setPercent(initialPercent)
end

-- Funções de voo
local function setUIFlying(state)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad)

    if state then
        TweenService:Create(uiElements.ToggleFlyBtn, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(100, 200, 100)
        }):Play()
        TweenService:Create(uiElements.StatusDot, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(100, 255, 120)
        }):Play()

        uiElements.ToggleFlyBtn.Text = "■  DESATIVAR FLY  [F]"
        uiElements.StatusLabel.Text = "● FLYING"
        uiElements.StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
    else
        TweenService:Create(uiElements.ToggleFlyBtn, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(70, 80, 120)
        }):Play()
        TweenService:Create(uiElements.StatusDot, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(150, 150, 180)
        }):Play()

        uiElements.ToggleFlyBtn.Text = "▶  ATIVAR FLY  [F]"
        uiElements.StatusLabel.Text = "● IDLE"
        uiElements.StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
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
    flyState.bodyVel.Velocity = Vector3.new()
    flyState.bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyState.bodyVel.Parent = root

    flyState.bodyGyro = Instance.new("BodyGyro")
    flyState.bodyGyro.Name = "FlyGyro"
    flyState.bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
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

-- Movimento do painel
local function setupPanelDrag()
    uiElements.Panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            flyState.dragging = true
            flyState.dragStart = input.Position
            flyState.panelStartPos = uiElements.Panel.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if flyState.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - flyState.dragStart
            uiElements.Panel.Position = UDim2.new(
                flyState.panelStartPos.X.Scale,
                flyState.panelStartPos.X.Offset + delta.X,
                flyState.panelStartPos.Y.Scale,
                flyState.panelStartPos.Y.Offset + delta.Y
            )
            if flyState.minimized then
                flyState.lastMinimizedPos = uiElements.Panel.Position
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            flyState.dragging = false
        end
    end)
end

-- Inicialização
local function setup()
    createUI()

    -- Criar sliders
    createSlider(uiElements.SliderContainer, "Fly Speed", CONFIG.SPEED_MIN, CONFIG.SPEED_MAX, values.flySpeed, function(v)
        values.flySpeed = v
    end)
    createSlider(uiElements.SliderContainer, "Jump Power", CONFIG.JUMP_MIN, CONFIG.JUMP_MAX, values.jumpPower, function(v)
        values.jumpPower = v
        applyCharacterValues()
    end)
    createSlider(uiElements.SliderContainer, "Walk Speed", CONFIG.WALK_MIN, CONFIG.WALK_MAX, values.walkSpeed, function(v)
        values.walkSpeed = v
        applyCharacterValues()
    end)

    setupPanelDrag()

    -- Conexões dos botões
    uiElements.ToggleFlyBtn.Activated:Connect(toggleFly)
    uiElements.MinimizeBtn.Activated:Connect(function()
        flyState.minimized = not flyState.minimized
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        if flyState.minimized then
            -- Minimizar
            flyState.lastMinimizedSize = uiElements.Panel.Size
            TweenService:Create(uiElements.Panel, tweenInfo, {
                Size = UDim2.new(0, 55, 0, 55),
                Position = uiElements.Panel.Position
            }):Play()
            -- Esconder elementos
            for _, v in pairs({uiElements.TitleBar, uiElements.SliderContainer, uiElements.StatusDot, uiElements.StatusLabel}) do
                v.Visible = false
            end
            uiElements.MinimizeBtn.Text = "+"
        else
            -- Restaurar
            TweenService:Create(uiElements.Panel, tweenInfo, {
                Size = flyState.lastMinimizedSize or UDim2.new(0, 300, 0, 380),
                Position = flyState.lastMinimizedPos or UDim2.new(0, 20, 0.5, -190)
            }):Play()
            -- Mostrar elementos
            for _, v in pairs({uiElements.TitleBar, uiElements.SliderContainer, uiElements.StatusDot, uiElements.StatusLabel}) do
                v.Visible = true
            end
            uiElements.MinimizeBtn.Text = "−"
        end
    end)

    -- Tecla de atalho
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
            toggleFly()
        end
    end)

    -- Loop de voo
    RunService.Heartbeat:Connect(function()
        if not flyState.flying or not flyState.bodyVel or not flyState.bodyGyro then return end
        local root = getRootPart()
        local camera = workspace.CurrentCamera
        local inputDir = getInputDirection()
        local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

        local speed = sprinting and values.flySpeed * CONFIG.SPRINT_MULT or values.flySpeed
        if inputDir.Magnitude > 0 then
            local worldDir = camera.CFrame:VectorToWorldSpace(inputDir).Unit
            flyState.bodyVel.Velocity = worldDir * speed
            local lookDir = Vector3.new(worldDir.X, 0, worldDir.Z)
            if lookDir.Magnitude > 0.01 then
                flyState.bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir)
            end
        else
            flyState.bodyVel.Velocity = flyState.bodyVel.Velocity * 0.85
        end
    end)
end

-- Execução
setup()
applyCharacterValues()
