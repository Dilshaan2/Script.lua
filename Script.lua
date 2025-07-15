-- Ultimate Autonomous Detection & Interaction Script
-- For your own Roblox game testing only

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- === Utility Functions ===

local function deepToString(value, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    if typeof(value) == "table" then
        local s = "{"
        for k,v in pairs(value) do
            s = s .. tostring(k) .. "=" .. deepToString(v, depth+1) .. ","
        end
        return s .. "}"
    else
        return tostring(value)
    end
end

local function safePcall(func, ...)
    local ok, res = pcall(func, ...)
    if not ok then
        warn("Error in pcall:", res)
    end
    return ok, res
end

-- === Remote Hooking & Logging ===

local callLog = {}
local MAX_LOG_SIZE = 500

local function addToLog(typeName, remoteName, args)
    table.insert(callLog, {
        Type = typeName,
        Name = remoteName,
        Args = args,
        Time = os.clock(),
    })
    if #callLog > MAX_LOG_SIZE then
        table.remove(callLog, 1)
    end
    print(string.format("[%s] %s called with args:", typeName, remoteName))
    for i,v in ipairs(args) do
        print("  Arg", i, "=", deepToString(v))
    end
end

local function hookRemoteEvent(remoteEvent)
    if remoteEvent.__hooked then return end
    remoteEvent.__hooked = true

    local oldFireServer = remoteEvent.FireServer
    remoteEvent.FireServer = function(self, ...)
        local args = {...}
        addToLog("RemoteEvent:FireServer", self.Name, args)
        return oldFireServer(self, ...)
    end

    local oldOnClientEventConnect = remoteEvent.OnClientEvent.Connect
    remoteEvent.OnClientEvent.Connect = function(self, func)
        local wrappedFunc = function(...)
            local args = {...}
            addToLog("RemoteEvent:OnClientEvent", self.Name, args)
            func(...)
        end
        return oldOnClientEventConnect(self, wrappedFunc)
    end
end

local function hookRemoteFunction(remoteFunction)
    if remoteFunction.__hooked then return end
    remoteFunction.__hooked = true

    local oldInvokeServer = remoteFunction.InvokeServer
    remoteFunction.InvokeServer = function(self, ...)
        local args = {...}
        addToLog("RemoteFunction:InvokeServer", self.Name, args)
        return oldInvokeServer(self, ...)
    end

    local oldOnClientInvoke = remoteFunction.OnClientInvoke
    remoteFunction.OnClientInvoke = function(self, func)
        local wrappedFunc = function(...)
            local args = {...}
            addToLog("RemoteFunction:OnClientInvoke", self.Name, args)
            return func(...)
        end
        return oldOnClientInvoke(self, wrappedFunc)
    end
end

local function hookAllRemotes(container)
    for _, obj in pairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            hookRemoteEvent(obj)
        elseif obj:IsA("RemoteFunction") then
            hookRemoteFunction(obj)
        end
    end
end

hookAllRemotes(ReplicatedStorage)
hookAllRemotes(player:WaitForChild("PlayerGui"))

-- === Intelligent Fuzzing & Detection ===

local commonPayloads = {
    "auth", "token", "buy", "purchase", "item", "test", "1234", 0, 1, true,
    {id=1}, {action="buy"}, {}, {token="secret"}, {"buy", 1}, {"auth", "token"},
}

local detectedAuthRemotes = {}
local detectedBuyRemotes = {}

local function tryPayload(remote, payload)
    local success, err = safePcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(payload)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(payload)
        end
    end)
    return success
end

local function detectAuthAndBuyRemotes()
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            for _, payload in ipairs(commonPayloads) do
                local ok = tryPayload(remote, payload)
                if ok then
                    local nameLower = remote.Name:lower()
                    local payloadStr = tostring(payload):lower()
                    if nameLower:find("auth") or payloadStr:find("token") then
                        detectedAuthRemotes[remote] = true
                    end
                    if nameLower:find("buy") or nameLower:find("purchase") or payloadStr:find("buy") then
                        detectedBuyRemotes[remote] = true
                    end
                end
            end
        end
    end
end

coroutine.wrap(function()
    detectAuthAndBuyRemotes()
    print("Detection complete.")
end)()

-- === GUI Setup ===

local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "UltimateAutoGui"

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 350, 0, 580)
frame.Position = UDim2.new(1, -360, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Ultimate Auto Detection"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 22

local tabButtons = Instance.new("Frame", frame)
tabButtons.Size = UDim2.new(1, 0, 0, 30)
tabButtons.Position = UDim2.new(0, 0, 0, 30)
tabButtons.BackgroundTransparency = 1

local function createTabButton(name, posX)
    local btn = Instance.new("TextButton", tabButtons)
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.Position = UDim2.new(0, posX, 0, 0)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 18
    return btn
end

local logTabBtn = createTabButton("Logs", 0)
local authTabBtn = createTabButton("Auth Remotes", 115)
local buyTabBtn = createTabButton("Buy Remotes", 230)

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, -10, 0, 370)
contentFrame.Position = UDim2.new(0, 5, 0, 65)
contentFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
contentFrame.BorderSizePixel = 0

local UIListLayout = Instance.new("UIListLayout", contentFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)

local function clearContent()
    for _, child in pairs(contentFrame:GetChildren()) do
        if not (child:IsA("UIListLayout")) then
            child:Destroy()
        end
    end
end

local function populateLogs()
    clearContent()
    for i = #callLog, 1, -1 do
        local entry = callLog[i]
        local label = Instance.new("TextLabel", contentFrame)
        label.Size = UDim2.new(1, 0, 0, 25)
        label.BackgroundTransparency = 0.5
        label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = string.format("[%0.2f] %s - %s Args: %d", entry.Time, entry.Type, entry.Name, #entry.Args)
    end
end

local function populateAuthRemotes()
    clearContent()
    for remote, _ in pairs(detectedAuthRemotes) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 16
        btn.Text = "Auth Remote: " .. remote.Name

        btn.MouseButton1Click:Connect(function()
            print("Attempting authentication via", remote.Name)
            for _, payload in ipairs(commonPayloads) do
                safePcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(payload)
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(payload)
                    end
                end)
            end
        end)
    end
end

local function populateBuyRemotes()
    clearContent()
    for remote, _ in pairs(detectedBuyRemotes) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 16
        btn.Text = "Buy Remote: " .. remote.Name

        btn.MouseButton1Click:Connect(function()
            print("Attempting purchase via", remote.Name)
            for _, payload in ipairs(commonPayloads) do
                safePcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(payload)
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(payload)
                    end
                end)
            end
        end)
    end
end

logTabBtn.MouseButton1Click:Connect(populateLogs)
authTabBtn.MouseButton1Click:Connect(populateAuthRemotes)
buyTabBtn.MouseButton1Click:Connect(populateBuyRemotes)

populateLogs()

-- === Flying Controls GUI ===

local flyControlFrame = Instance.new("Frame", frame)
flyControlFrame.Size = UDim2.new(1, -20, 0, 80)
flyControlFrame.Position = UDim2.new(0, 10, 1, -90)
flyControlFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
flyControlFrame.BorderSizePixel = 0
flyControlFrame.Name = "FlyControlFrame"

local flyTitle = Instance.new("TextLabel", flyControlFrame)
flyTitle.Size = UDim2.new(1, 0, 0, 25)
flyTitle.BackgroundTransparency = 1
flyTitle.Text = "Flying Controls"
flyTitle.TextColor3 = Color3.new(1, 1, 1)
flyTitle.Font = Enum.Font.SourceSansBold
flyTitle.TextSize = 18

local flyToggleBtn = Instance.new("TextButton", flyControlFrame)
flyToggleBtn.Size = UDim2.new(0.5, -10, 0, 30)
flyToggleBtn.Position = UDim2.new(0, 5, 0, 30)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
flyToggleBtn.TextColor3 = Color3.new(1, 1, 1)
flyToggleBtn.Font = Enum.Font.SourceSans
flyToggleBtn.TextSize = 16
flyToggleBtn.Text = "Start Flying"

local speedLabel = Instance.new("TextLabel", flyControlFrame)
speedLabel.Size = UDim2.new(0.5, -10, 0, 20)
speedLabel.Position = UDim2.new(0.5, 5, 0, 30)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 14
speedLabel.Text = "Speed: 50"

local sliderFrame = Instance.new("Frame", flyControlFrame)
sliderFrame.Size = UDim2.new(0.5, -10, 0, 20)
sliderFrame.Position = UDim2.new(0.5, 5, 0, 55)
sliderFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
sliderFrame.BorderSizePixel = 0

local sliderKnob = Instance.new("Frame", sliderFrame)
sliderKnob.Size = UDim2.new(0, 20, 1, 0)
sliderKnob.Position = UDim2.new(0.5, -10, 0, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sliderKnob.BorderSizePixel = 0
sliderKnob.Active = true
sliderKnob.Draggable = true

local flying = false
local speed = 50
local bodyVelocity

local function startFlying()
    if flying then return end
    flying = true
    flyToggleBtn.Text = "Stop Flying"
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp

    spawn(function()
        while flying do
            local direction = Vector3.new(0, 0, 0)
            local camera = workspace.CurrentCamera

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction = direction + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction = direction - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction = direction - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction = direction + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                direction = direction + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                direction = direction - Vector3.new(0, 1, 0)
            end

            if direction.Magnitude > 0 then
                local targetVelocity = direction.Unit * speed
                bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVelocity, 0.2)
            else
                bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(Vector3.new(0, 0, 0), 0.2)
            end

            RunService.Heartbeat:Wait()
        end
    end)
end

local function stopFlying()
    flying = false
    flyToggleBtn.Text = "Start Flying"
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
end

flyToggleBtn.MouseButton1Click:Connect(function()
    if flying then
        stopFlying()
    else
        startFlying()
    end
end)

local dragging = false

sliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
    end
end)

sliderKnob.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local relativeX = math.clamp(input.Position.X - sliderFrame.AbsolutePosition.X, 0, sliderFrame.AbsoluteSize.X)
        local percent = relativeX / sliderFrame.AbsoluteSize.X
        sliderKnob.Position = UDim2.new(percent, -sliderKnob.AbsoluteSize.X/2, 0, 0)
        speed = math.floor(10 + percent * 190) -- speed range 10 to 200
        speedLabel.Text = "Speed: " .. speed
    end
end)

print("Ultimate Autonomous Detection Script loaded. Use the GUI to explore remotes and toggle flying.")
-- Ultimate Autonomous Detection & Interaction Script
-- For your own Roblox game testing only

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- === Utility Functions ===

local function deepToString(value, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    if typeof(value) == "table" then
        local s = "{"
        for k,v in pairs(value) do
            s = s .. tostring(k) .. "=" .. deepToString(v, depth+1) .. ","
        end
        return s .. "}"
    else
        return tostring(value)
    end
end

local function safePcall(func, ...)
    local ok, res = pcall(func, ...)
    if not ok then
        warn("Error in pcall:", res)
    end
    return ok, res
end

-- === Remote Hooking & Logging ===

local callLog = {}
local MAX_LOG_SIZE = 500

local function addToLog(typeName, remoteName, args)
    table.insert(callLog, {
        Type = typeName,
        Name = remoteName,
        Args = args,
        Time = os.clock(),
    })
    if #callLog > MAX_LOG_SIZE then
        table.remove(callLog, 1)
    end
    print(string.format("[%s] %s called with args:", typeName, remoteName))
    for i,v in ipairs(args) do
        print("  Arg", i, "=", deepToString(v))
    end
end

local function hookRemoteEvent(remoteEvent)
    if remoteEvent.__hooked then return end
    remoteEvent.__hooked = true

    local oldFireServer = remoteEvent.FireServer
    remoteEvent.FireServer = function(self, ...)
        local args = {...}
        addToLog("RemoteEvent:FireServer", self.Name, args)
        return oldFireServer(self, ...)
    end

    local oldOnClientEventConnect = remoteEvent.OnClientEvent.Connect
    remoteEvent.OnClientEvent.Connect = function(self, func)
        local wrappedFunc = function(...)
            local args = {...}
            addToLog("RemoteEvent:OnClientEvent", self.Name, args)
            func(...)
        end
        return oldOnClientEventConnect(self, wrappedFunc)
    end
end

local function hookRemoteFunction(remoteFunction)
    if remoteFunction.__hooked then return end
    remoteFunction.__hooked = true

    local oldInvokeServer = remoteFunction.InvokeServer
    remoteFunction.InvokeServer = function(self, ...)
        local args = {...}
        addToLog("RemoteFunction:InvokeServer", self.Name, args)
        return oldInvokeServer(self, ...)
    end

    local oldOnClientInvoke = remoteFunction.OnClientInvoke
    remoteFunction.OnClientInvoke = function(self, func)
        local wrappedFunc = function(...)
            local args = {...}
            addToLog("RemoteFunction:OnClientInvoke", self.Name, args)
            return func(...)
        end
        return oldOnClientInvoke(self, wrappedFunc)
    end
end

local function hookAllRemotes(container)
    for _, obj in pairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            hookRemoteEvent(obj)
        elseif obj:IsA("RemoteFunction") then
            hookRemoteFunction(obj)
        end
    end
end

hookAllRemotes(ReplicatedStorage)
hookAllRemotes(player:WaitForChild("PlayerGui"))

-- === Intelligent Fuzzing & Detection ===

local commonPayloads = {
    "auth", "token", "buy", "purchase", "item", "test", "1234", 0, 1, true,
    {id=1}, {action="buy"}, {}, {token="secret"}, {"buy", 1}, {"auth", "token"},
}

local detectedAuthRemotes = {}
local detectedBuyRemotes = {}

local function tryPayload(remote, payload)
    local success, err = safePcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(payload)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(payload)
        end
    end)
    return success
end

local function detectAuthAndBuyRemotes()
    for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            for _, payload in ipairs(commonPayloads) do
                local ok = tryPayload(remote, payload)
                if ok then
                    local nameLower = remote.Name:lower()
                    local payloadStr = tostring(payload):lower()
                    if nameLower:find("auth") or payloadStr:find("token") then
                        detectedAuthRemotes[remote] = true
                    end
                    if nameLower:find("buy") or nameLower:find("purchase") or payloadStr:find("buy") then
                        detectedBuyRemotes[remote] = true
                    end
                end
            end
        end
    end
end

coroutine.wrap(function()
    detectAuthAndBuyRemotes()
    print("Detection complete.")
end)()

-- === GUI Setup ===

local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "UltimateAutoGui"

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 350, 0, 580)
frame.Position = UDim2.new(1, -360, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Ultimate Auto Detection"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 22

local tabButtons = Instance.new("Frame", frame)
tabButtons.Size = UDim2.new(1, 0, 0, 30)
tabButtons.Position = UDim2.new(0, 0, 0, 30)
tabButtons.BackgroundTransparency = 1

local function createTabButton(name, posX)
    local btn = Instance.new("TextButton", tabButtons)
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.Position = UDim2.new(0, posX, 0, 0)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 18
    return btn
end

local logTabBtn = createTabButton("Logs", 0)
local authTabBtn = createTabButton("Auth Remotes", 115)
local buyTabBtn = createTabButton("Buy Remotes", 230)

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, -10, 0, 370)
contentFrame.Position = UDim2.new(0, 5, 0, 65)
contentFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
contentFrame.BorderSizePixel = 0

local UIListLayout = Instance.new("UIListLayout", contentFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)

local function clearContent()
    for _, child in pairs(contentFrame:GetChildren()) do
        if not (child:IsA("UIListLayout")) then
            child:Destroy()
        end
    end
end

local function populateLogs()
    clearContent()
    for i = #callLog, 1, -1 do
        local entry = callLog[i]
        local label = Instance.new("TextLabel", contentFrame)
        label.Size = UDim2.new(1, 0, 0, 25)
        label.BackgroundTransparency = 0.5
        label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = string.format("[%0.2f] %s - %s Args: %d", entry.Time, entry.Type, entry.Name, #entry.Args)
    end
end

local function populateAuthRemotes()
    clearContent()
    for remote, _ in pairs(detectedAuthRemotes) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 16
        btn.Text = "Auth Remote: " .. remote.Name

        btn.MouseButton1Click:Connect(function()
            print("Attempting authentication via", remote.Name)
            for _, payload in ipairs(commonPayloads) do
                safePcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(payload)
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(payload)
                    end
                end)
            end
        end)
    end
end

local function populateBuyRemotes()
    clearContent()
    for remote, _ in pairs(detectedBuyRemotes) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 16
        btn.Text = "Buy Remote: " .. remote.Name

        btn.MouseButton1Click:Connect(function()
            print("Attempting purchase via", remote.Name)
            for _, payload in ipairs(commonPayloads) do
                safePcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(payload)
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(payload)
                    end
                end)
            end
        end)
    end
end

logTabBtn.MouseButton1Click:Connect(populateLogs)
authTabBtn.MouseButton1Click:Connect(populateAuthRemotes)
buyTabBtn.MouseButton1Click:Connect(populateBuyRemotes)

populateLogs()

-- === Flying Controls GUI ===

local flyControlFrame = Instance.new("Frame", frame)
flyControlFrame.Size = UDim2.new(1, -20, 0, 80)
flyControlFrame.Position = UDim2.new(0, 10, 1, -90)
flyControlFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
flyControlFrame.BorderSizePixel = 0
flyControlFrame.Name = "FlyControlFrame"

local flyTitle = Instance.new("TextLabel", flyControlFrame)
flyTitle.Size = UDim2.new(1, 0, 0, 25)
flyTitle.BackgroundTransparency = 1
flyTitle.Text = "Flying Controls"
flyTitle.TextColor3 = Color3.new(1, 1, 1)
flyTitle.Font = Enum.Font.SourceSansBold
flyTitle.TextSize = 18

local flyToggleBtn = Instance.new("TextButton", flyControlFrame)
flyToggleBtn.Size = UDim2.new(0.5, -10, 0, 30)
flyToggleBtn.Position = UDim2.new(0, 5, 0, 30)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
flyToggleBtn.TextColor3 = Color3.new(1, 1, 1)
flyToggleBtn.Font = Enum.Font.SourceSans
flyToggleBtn.TextSize = 16
flyToggleBtn.Text = "Start Flying"

local speedLabel = Instance.new("TextLabel", flyControlFrame)
speedLabel.Size = UDim2.new(0.5, -10, 0, 20)
speedLabel.Position = UDim2.new(0.5, 5, 0, 30)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 14
speedLabel.Text = "Speed: 50"

local sliderFrame = Instance.new("Frame", flyControlFrame)
sliderFrame.Size = UDim2.new(0.5, -10, 0, 20)
sliderFrame.Position = UDim2.new(0.5, 5, 0, 55)
sliderFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
sliderFrame.BorderSizePixel = 0

local sliderKnob = Instance.new("Frame", sliderFrame)
sliderKnob.Size = UDim2.new(0, 20, 1, 0)
sliderKnob.Position = UDim2.new(0.5, -10, 0, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sliderKnob.BorderSizePixel = 0
sliderKnob.Active = true
sliderKnob.Draggable = true

local flying = false
local speed = 50
local bodyVelocity

local function startFlying()
    if flying then return end
    flying = true
    flyToggleBtn.Text = "Stop Flying"
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp

    spawn(function()
        while flying do
            local direction = Vector3.new(0, 0, 0)
            local camera = workspace.CurrentCamera

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction = direction + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction = direction - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction = direction - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction = direction + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                direction = direction + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                direction = direction - Vector3.new(0, 1, 0)
            end

            if direction.Magnitude > 0 then
                local targetVelocity = direction.Unit * speed
                bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVelocity, 0.2)
            else
                bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(Vector3.new(0, 0, 0), 0.2)
            end

            RunService.Heartbeat:Wait()
        end
    end)
end

local function stopFlying()
    flying = false
    flyToggleBtn.Text = "Start Flying"
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
end

flyToggleBtn.MouseButton1Click:Connect(function()
    if flying then
        stopFlying()
    else
        startFlying()
    end
end)

local dragging = false

sliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
    end
end)

sliderKnob.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local relativeX = math.clamp(input.Position.X - sliderFrame.AbsolutePosition.X, 0, sliderFrame.AbsoluteSize.X)
        local percent = relativeX / sliderFrame.AbsoluteSize.X
        sliderKnob.Position = UDim2.new(percent, -sliderKnob.AbsoluteSize.X/2, 0, 0)
        speed = math.floor(10 + percent * 190) -- speed range 10 to 200
        speedLabel.Text = "Speed: " .. speed
    end
end)

print("Ultimate Autonomous Detection Script loaded. Use the GUI to explore remotes and toggle flying.")

