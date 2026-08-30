-- DevMenu_AllInOne.lua
-- COLE ESTE SCRIPT EM ServerScriptService (Script)
-- Ele cria remotes, handlers server-side e injeta um LocalScript no PlayerGui de cada jogador (UI completa).
-- USE APENAS EM SEU PRÓPRIO JOGO / AMBIENTE DE TESTE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ====== CONFIGURE AQUI: lista de admins (substitua pelos seus UserIds) ======
local ADMINS = {
	[12345678] = true, -- <<--- coloque seu UserId aqui
	--[87654321] = true,
}
-- ==========================================================================

-- Ensure remotes exist
local function ensureRemote(name, class)
	local obj = ReplicatedStorage:FindFirstChild(name)
	if obj and obj:IsA(class) then return obj end
	local newObj = Instance.new(class)
	newObj.Name = name
	newObj.Parent = ReplicatedStorage
	return newObj
end

local DevEvent = ensureRemote("DevMenuEvent", "RemoteEvent")
local PresetEvent = ensureRemote("PresetEvent", "RemoteEvent")
local PingFunction = ensureRemote("PingFunction", "RemoteFunction")
local WeaponEvent = ensureRemote("WeaponFireEvent", "RemoteEvent")

-- Server: handle dev actions (only admins)
DevEvent.OnServerEvent:Connect(function(player, action, value)
	if not player or not action then return end
	if not ADMINS[player.UserId] then
		warn(("[DevMenu] %s tentou usar %s sem permissão"):format(player.Name, tostring(action)))
		return
	end
	local attrName = "Dev_" .. tostring(action)
	local ok, err = pcall(function() player:SetAttribute(attrName, value) end)
	if not ok then warn("Falha ao setar attribute:", err) end
	print(("[DevMenu] %s aplicou %s = %s"):format(player.Name, attrName, tostring(value)))
end)

-- Ping function: server responds with server tick
if PingFunction and typeof(PingFunction) == "RemoteFunction" then
	PingFunction.OnServerInvoke = function(player, clientTick)
		return tick()
	end
end

-- Example server-side Weapon handling (authoritative): read Dev_* attributes safely
do
	local WEAPONS = {
		["Pistol"] = {FireRate = 8, Damage = 20, Recoil = 1.0, Spread = 1.0},
		["Rifle"]  = {FireRate = 6, Damage = 18, Recoil = 1.6, Spread = 2.2},
	}
	local lastFire = {}
	local function canFireKey(player, weaponKey, rate)
		local key = tostring(player.UserId) .. ":" .. tostring(weaponKey)
		local now = tick()
		local last = lastFire[key] or 0
		if now - last < (1 / rate) then return false end
		lastFire[key] = now
		return true
	end

	WeaponEvent.OnServerEvent:Connect(function(player, weaponKey, clientAim)
		if not player or not weaponKey then return end
		local def = WEAPONS[weaponKey]
		if not def then return end

		-- Read attributes set by admins via DevEvent
		local noRecoil = player:GetAttribute("Dev_NoRecoil") or false
		local rapidFire = player:GetAttribute("Dev_RapidFire") or false
		local noSpread = player:GetAttribute("Dev_NoSpread") or false
		local fireRateOverride = player:GetAttribute("Dev_FireRate") or def.FireRate

		local effFireRate = fireRateOverride * (rapidFire and 2 or 1)
		local effRecoil = (noRecoil and 0) or def.Recoil
		local effSpread = (noSpread and 0) or def.Spread

		if not canFireKey(player, weaponKey, effFireRate) then return end

		-- Example: server-side authoritative log (replace with your raycast & damage)
		print(("[Weapon] %s disparou %s | rate=%.2f recoil=%.2f spread=%.2f"):format(
			player.Name, weaponKey, effFireRate, effRecoil, effSpread
		))

		-- TODO: sua lógica de raycast/causar dano server-side vai aqui (validate clientAim!)
	end)
end

-- Client code (will be injected into each player's PlayerGui as a LocalScript)
local clientSource = [[
-- DevMenu injected LocalScript (client-side UI)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local DevEvent = ReplicatedStorage:WaitForChild("DevMenuEvent")
local PingFunction = ReplicatedStorage:WaitForChild("PingFunction")
local WeaponEvent = ReplicatedStorage:WaitForChild("WeaponFireEvent")

local function safeFire(action, value)
	pcall(function() DevEvent:FireServer(action, value) end)
end

local function measurePing()
	if not PingFunction or typeof(PingFunction) ~= "RemoteFunction" then return nil end
	local t = tick()
	local ok, serverTick = pcall(function() return PingFunction:InvokeServer(t) end)
	if not ok or type(serverTick) ~= "number" then return nil end
	return math.floor((tick() - t) * 1000)
end

-- create UI
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("DevMenuUI")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevMenuUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

local panel = Instance.new("Frame", screenGui)
panel.Name = "Panel"
panel.Size = UDim2.new(0, 420, 0, 520)
panel.Position = UDim2.new(0.5, -210, 0.5, -260)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(18,18,22)
panel.BorderSizePixel = 0
local panelCorner = Instance.new("UICorner", panel); panelCorner.CornerRadius = UDim.new(0,14)

-- Titlebar: text + FPS + Ping + minimize
local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1,0,0,56)
titleBar.BackgroundColor3 = Color3.fromRGB(24,24,28)
local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1,-160,1,0); title.Position = UDim2.new(0,16,0,0)
title.BackgroundTransparency = 1; title.Text = "Aether Dev Hub"; title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.TextColor3 = Color3.fromRGB(235,235,240); title.TextScaled = true; title.TextXAlignment = Enum.TextXAlignment.Left

local fpsBadge = Instance.new("TextLabel", titleBar)
fpsBadge.Size = UDim2.new(0,96,0,28); fpsBadge.Position = UDim2.new(1,-112,0.5,-14)
fpsBadge.BackgroundColor3 = Color3.fromRGB(34,139,34); fpsBadge.Text = "FPS: --"; fpsBadge.Font = Enum.Font.GothamBold; fpsBadge.TextScaled = true; fpsBadge.TextColor3 = Color3.new(1,1,1)
local pingBadge = Instance.new("TextLabel", titleBar)
pingBadge.Size = UDim2.new(0,72,0,28); pingBadge.Position = UDim2.new(1,-210,0.5,-14)
pingBadge.BackgroundColor3 = Color3.fromRGB(200,120,10); pingBadge.Text = "Ping: --"; pingBadge.Font = Enum.Font.GothamBold; pingBadge.TextScaled = true; pingBadge.TextColor3 = Color3.new(1,1,1)
local ver = Instance.new("TextLabel", titleBar)
ver.Size = UDim2.new(0,40,0,28); ver.Position = UDim2.new(1,-60,0.5,-14)
ver.BackgroundColor3 = Color3.fromRGB(80,120,200); ver.Text = "v1.0"; ver.Font = Enum.Font.GothamBold; ver.TextScaled = true; ver.TextColor3 = Color3.new(1,1,1)

-- Minimize button
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0,36,0,36); minBtn.Position = UDim2.new(1,-48,0.5,-18); minBtn.Text = "—"; minBtn.AutoButtonColor = false
local minCorner = Instance.new("UICorner", minBtn); minCorner.CornerRadius = UDim.new(0,8)

-- left tabs
local tabs = Instance.new("Frame", panel); tabs.Size = UDim2.new(0,120,1,-56); tabs.Position = UDim2.new(0,0,0,56); tabs.BackgroundTransparency = 1
local tabsLayout = Instance.new("UIListLayout", tabs); tabsLayout.Padding = UDim.new(0,8)
local tabsPad = Instance.new("UIPadding", tabs); tabsPad.PaddingTop = UDim.new(0,12); tabsPad.PaddingLeft = UDim.new(0,8)

local function makeTab(name) local b = Instance.new("TextButton", tabs); b.Size = UDim2.new(1,-12,0,40); b.Text = name; b.Font = Enum.Font.GothamSemibold; b.TextSize = 14; b.TextColor3 = Color3.fromRGB(220,220,220); b.AutoButtonColor=false; local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0,8); return b end
local tabUtilities = makeTab("Utilities"); local tabVisuals = makeTab("Visuals"); local tabGunMods = makeTab("Gun Mods"); local tabSettings = makeTab("Settings")

-- content scroll area
local content = Instance.new("Frame", panel); content.Size = UDim2.new(1,-120,1,-56); content.Position = UDim2.new(0,120,0,56); content.BackgroundTransparency = 1
local scroll = Instance.new("ScrollingFrame", content); scroll.Size = UDim2.new(1,-24,1,-24); scroll.Position = UDim2.new(0,12,0,12); scroll.BackgroundTransparency = 1; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.ScrollBarThickness = 8
local layout = Instance.new("UIListLayout", scroll); layout.Padding = UDim.new(0,10)
local pad = Instance.new("UIPadding", scroll); pad.PaddingTop = UDim.new(0,4); pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,6)

-- helper widgets
local function addLabel(text)
	local lbl = Instance.new("TextLabel", scroll); lbl.Size = UDim2.new(1,0,0,22); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.Font = Enum.Font.GothamSemibold; lbl.TextColor3 = Color3.fromRGB(200,200,210); lbl.TextScaled = true; lbl.TextXAlignment = Enum.TextXAlignment.Left; return lbl
end

local function addToggle(text, initial, onChanged)
	local frame = Instance.new("Frame", scroll); frame.Size = UDim2.new(1,0,0,40); frame.BackgroundTransparency = 1
	local lbl = Instance.new("TextLabel", frame); lbl.Size = UDim2.new(0.65,0,1,0); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.Font = Enum.Font.GothamSemibold; lbl.TextScaled = true; lbl.TextColor3 = Color3.fromRGB(220,220,220); lbl.TextXAlignment = Enum.TextXAlignment.Left
	local btn = Instance.new("TextButton", frame); btn.Size = UDim2.new(0,64,0,28); btn.Position = UDim2.new(1,-72,0.5,-14); btn.AutoButtonColor = false; btn.Font = Enum.Font.GothamBold; btn.TextScaled = true
	local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,8)
	local state = initial and true or false
	local function update()
		btn.Text = state and "ON" or "OFF"
		btn.BackgroundColor3 = state and Color3.fromRGB(100,200,130) or Color3.fromRGB(72,72,88)
		if onChanged then pcall(onChanged, state) end
	end
	btn.Activated:Connect(function() state = not state; update() end)
	update()
	return {frame = frame, set = function(v) state = v; update() end}
end

local function addSlider(labelText, min, max, initial, onChanged)
	local frame = Instance.new("Frame", scroll); frame.Size = UDim2.new(1,0,0,64); frame.BackgroundTransparency = 1
	local lbl = Instance.new("TextLabel", frame); lbl.Size = UDim2.new(0.6,0,0,20); lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.Font = Enum.Font.GothamSemibold; lbl.TextColor3 = Color3.fromRGB(210,210,210); lbl.TextScaled = true
	local valLbl = Instance.new("TextLabel", frame); valLbl.Size = UDim2.new(0.4,-6,0,20); valLbl.Position = UDim2.new(0.6,6,0,0); valLbl.Text = tostring(initial); valLbl.Font = Enum.Font.GothamBold; valLbl.TextScaled = true; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.TextColor3 = Color3.fromRGB(150,170,255)
	local track = Instance.new("Frame", frame); track.Name = "track"; track.Size = UDim2.new(1,0,0,12); track.Position = UDim2.new(0,0,0,32); track.BackgroundColor3 = Color3.fromRGB(50,50,60)
	local tc = Instance.new("UICorner", track); tc.CornerRadius = UDim.new(1,0)
	local fill = Instance.new("Frame", track); fill.Size = UDim2.new((initial-min)/(max-min),0,1,0); fill.BackgroundColor3 = Color3.fromRGB(100,120,255)
	local fc = Instance.new("UICorner", fill); fc.CornerRadius = UDim.new(1,0)
	local thumb = Instance.new("TextButton", track); thumb.Size = UDim2.new(0,20,0,20); thumb.AnchorPoint = Vector2.new(0.5,0.5); thumb.Position = UDim2.new((initial-min)/(max-min),0,0.5,0); thumb.Text = ""; thumb.AutoButtonColor = false
	local thc = Instance.new("UICorner", thumb); thc.CornerRadius = UDim.new(1,0)
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			local conn
			conn = UserInputService.InputChanged:Connect(function(move)
				if move.UserInputType == Enum.UserInputType.MouseMovement then
					local x = math.clamp((move.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
					fill.Size = UDim2.new(x,0,1,0)
					thumb.Position = UDim2.new(x,0,0.5,0)
					local val = math.floor(min + x*(max-min) + 0.5)
					valLbl.Text = tostring(val)
					if onChanged then pcall(onChanged, val) end
				end
			end)
			local upConn
			upConn = UserInputService.InputEnded:Connect(function(e)
				if e.UserInputType == Enum.UserInputType.MouseButton1 then
					upConn:Disconnect(); conn:Disconnect()
				end
			end)
		end
	end)
	return {frame = frame, setValue = function(v) local x=(v-min)/(max-min); fill.Size=UDim2.new(x,0,1,0); thumb.Position=UDim2.new(x,0,0.5,0); valLbl.Text=tostring(v) end}
end

-- Build UI content (similar to image)
addLabel("Warning: Use these tools only in development/testing environments.")
local noRecoil = addToggle("No Recoil", false, function(s) safeFire("NoRecoil", s) end)
local rapidFire = addToggle("Rapid Fire", false, function(s) safeFire("RapidFire", s) end)
local noSpread = addToggle("No Spread", false, function(s) safeFire("NoSpread", s) end)
local alwaysAuto = addToggle("Always Auto", false, function(s) safeFire("AlwaysAuto", s) end)
addLabel("Gun Mods")
local fireRate = addSlider("Fire Rate", 1, 30, 10, function(v) safeFire("FireRate", v) end)
local recoilMult = addSlider("Recoil Mult (%)", 0, 200, 100, function(v) safeFire("RecoilMultiplier", v/100) end)

-- Keybind recording
addLabel("Hotkey (press to record)")
local hotFrame = Instance.new("Frame", scroll); hotFrame.Size = UDim2.new(1,0,0,40); hotFrame.BackgroundTransparency = 1
local hotLbl = Instance.new("TextLabel", hotFrame); hotLbl.Size = UDim2.new(0.5,0,1,0); hotLbl.BackgroundTransparency = 1; hotLbl.Text = "Toggle Key:"; hotLbl.Font = Enum.Font.GothamSemibold; hotLbl.TextScaled = true
local hotBtn = Instance.new("TextButton", hotFrame); hotBtn.Size = UDim2.new(0,140,0,28); hotBtn.Position = UDim2.new(1,-148,0.5,-14); hotBtn.Text = "F (Toggle)"; hotBtn.AutoButtonColor = false
hotBtn.Activated:Connect(function()
	hotBtn.Text = "Press a key..."
	local conn
	conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			hotBtn.Text = tostring(key.Name) .. " (Toggle)"
			safeFire("ToggleKey", tostring(key.Name))
			if conn then conn:Disconnect() end
		end
	end)
end)

-- Presets (client-side minimal demo)
addLabel("Presets (client demo)")
local presetBox = Instance.new("TextBox", scroll); presetBox.Size = UDim2.new(0.6,0,0,28); presetBox.PlaceholderText = "Preset name"
local savePresetBtn = Instance.new("TextButton", scroll); savePresetBtn.Size = UDim2.new(0,96,0,28); savePresetBtn.Text = "Save Preset"; savePresetBtn.AutoButtonColor = false
local presetList = Instance.new("Frame", scroll); presetList.Size = UDim2.new(1,-12,0,80); local presetLayout = Instance.new("UIListLayout", presetList); presetLayout.FillDirection = Enum.FillDirection.Horizontal; presetLayout.Padding = UDim.new(0,8)
savePresetBtn.Activated:Connect(function()
	local name = tostring(presetBox.Text or ""):gsub("^%s*(.-)%s*$","%1")
	if name == "" then presetBox.PlaceholderText = "Enter valid name"; task.delay(1.2,function() if presetBox then presetBox.PlaceholderText="Preset name" end end); return end
	if ReplicatedStorage:FindFirstChild("PresetEvent") then
		pcall(function() ReplicatedStorage:FindFirstChild("PresetEvent"):FireServer("Save", name, {}) end)
	else
		local btn = Instance.new("TextButton", presetList); btn.Size = UDim2.new(0,120,0,36); btn.Text = name; btn.AutoButtonColor = false
		btn.MouseButton1Click:Connect(function() print("Loaded preset (client):", name) end)
		local last = 0
		btn.MouseButton1Click:Connect(function() local now=tick(); if now-last<0.4 then btn:Destroy() end; last=now end)
	end
end)

-- Minimize bubble and panel drag/snap
local bubble = Instance.new("TextButton", screenGui); bubble.Size = UDim2.new(0,64,0,64); bubble.BackgroundColor3 = Color3.fromRGB(100,100,240); bubble.Text="⦿"; bubble.Visible=false; bubble.AutoButtonColor=false; local bcorner = Instance.new("UICorner", bubble); bcorner.CornerRadius = UDim.new(1,0)
minBtn.Activated:Connect(function()
	if panel.Visible then
		local abs = panel.AbsolutePosition; local bw = bubble.AbsoluteSize.X; local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
		local bx = math.clamp(abs.X + panel.AbsoluteSize.X - bw - 8, 8, vp.X - bw - 8)
		local by = math.clamp(abs.Y + 8, 8, vp.Y - bubble.AbsoluteSize.Y - 8)
		bubble.Position = UDim2.new(0, bx, 0, by); bubble.Visible = true
		TweenService:Create(panel, TweenInfo.new(0.18), {Size = UDim2.new(0, 220, 0, 80)}):Play()
		task.delay(0.18, function() panel.Visible=false; panel.Size=UDim2.new(0,420,0,520) end)
	else
		panel.Visible = true; bubble.Visible = false
	end
end)
bubble.Activated:Connect(function() panel.Visible = true; bubble.Visible = false end)

-- bubble drag + snap
do
	local dragging=false; local sPos, sBubble
	bubble.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; sPos=inp.Position; sBubble=bubble.Position end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local d = inp.Position - sPos
			local newX = sBubble.X.Offset + d.X; local newY = sBubble.Y.Offset + d.Y
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local ox = math.clamp(newX, 8, vp.X - bubble.AbsoluteSize.X - 8)
			local oy = math.clamp(newY, 8, vp.Y - bubble.AbsoluteSize.Y - 8)
			bubble.Position = UDim2.new(0, ox, 0, oy)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if dragging and inp.UserInputType==Enum.UserInputType.MouseButton1 then
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
			local cx = bubble.AbsolutePosition.X + bubble.AbsoluteSize.X/2; local cy = bubble.AbsolutePosition.Y + bubble.AbsoluteSize.Y/2
			local left, right, top, bottom = cx, vp.X - cx, cy, vp.Y - cy
			local minEdge = math.min(left, right, top, bottom)
			local tx, ty = bubble.AbsolutePosition.X, bubble.AbsolutePosition.Y
			if minEdge==left then tx=8 elseif minEdge==right then tx=vp.X - bubble.AbsoluteSize.X - 8 elseif minEdge==top then ty=8 else ty=vp.Y - bubble.AbsoluteSize.Y - 8 end
			TweenService:Create(bubble, TweenInfo.new(0.18), {Position = UDim2.new(0, tx, 0, ty)}):Play()
		end
		dragging=false
	end)
end

-- panel dragging (titlebar)
do
	local dragging=false; local sPos, pPos
	titleBar.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; sPos=inp.Position; pPos=panel.Position end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local d = inp.Position - sPos
			panel.Position = UDim2.new(pPos.X.Scale, pPos.X.Offset + d.X, pPos.Y.Scale, pPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
end

-- FPS & ping updates
do
	local last = tick(); local frames=0
	RunService.RenderStepped:Connect(function()
		frames = frames + 1
		if tick() - last >= 1 then
			local fps = math.floor(frames / (tick() - last))
			frames = 0; last = tick()
			pcall(function() fpsBadge.Text = "FPS: " .. tostring(fps) end)
		end
	end)
	spawn(function()
		while screenGui and screenGui.Parent do
			local p = measurePing()
			if p then pcall(function() pingBadge.Text = "Ping: " .. tostring(p) .. "ms" end) end
			wait(2)
		end
	end)
end

print("[DevMenuClient] UI injected and running (client).")
]]

-- On player added: inject the LocalScript into their PlayerGui (so it runs client-side)
local function onPlayerAdded(player)
	-- wait for PlayerGui
	local gui = player:WaitForChild("PlayerGui")
	-- create LocalScript
	local ls = Instance.new("LocalScript")
	ls.Name = "DevMenu_injected"
	ls.Source = clientSource
	ls.Parent = gui
end

-- For players already in game (Studio Play), inject
for _,p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
Players.PlayerAdded:Connect(onPlayerAdded)

print("[DevMenu_AllInOne] installed. Remotes ready and LocalScript will be injected into each PlayerGui.")
