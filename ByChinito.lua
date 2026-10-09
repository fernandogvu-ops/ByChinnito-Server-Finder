
-- PRIVATE SERVER FINDER
-- by ByChinnito

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local running = true
local autoEnabled = false
local busy = false

-- Interfaz
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ByChinnitoServerFinder"
ScreenGui.ResetOnSpawn = false

local success, guiError = pcall(function()
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

if not success then
    warn("ByChinnito GUI: " .. tostring(guiError))
    return
end

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -120)
MainFrame.Size = UDim2.new(0, 260, 0, 240)
MainFrame.Active = true
MainFrame.Draggable = true

Instance.new("UICorner", MainFrame).CornerRadius =
    UDim.new(0, 12)

local stroke = Instance.new("UIStroke", MainFrame)
stroke.Color = Color3.fromRGB(60, 50, 90)
stroke.Thickness = 1.5

local function makeLabel(text, position, size, color, textSize)
    local label = Instance.new("TextLabel")
    label.Parent = MainFrame
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color
    label.TextSize = textSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    return label
end

makeLabel(
    "PRIVATE SERVER FINDER",
    UDim2.fromOffset(15, 12),
    UDim2.fromOffset(205, 18),
    Color3.fromRGB(0, 230, 255),
    13
)

makeLabel(
    "by ByChinnito",
    UDim2.fromOffset(15, 30),
    UDim2.fromOffset(180, 14),
    Color3.fromRGB(120, 120, 150),
    10
)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = MainFrame
CloseBtn.Position = UDim2.new(1, -32, 0, 12)
CloseBtn.Size = UDim2.fromOffset(20, 20)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.TextSize = 11
Instance.new("UICorner", CloseBtn).CornerRadius =
    UDim.new(0, 6)

local StatusCard = Instance.new("Frame")
StatusCard.Parent = MainFrame
StatusCard.Position = UDim2.fromOffset(15, 52)
StatusCard.Size = UDim2.new(1, -30, 0, 50)
StatusCard.BackgroundColor3 = Color3.fromRGB(24, 20, 40)
StatusCard.BorderSizePixel = 0
Instance.new("UICorner", StatusCard).CornerRadius =
    UDim.new(0, 8)

local NowLabel = Instance.new("TextLabel")
NowLabel.Parent = StatusCard
NowLabel.Position = UDim2.fromOffset(10, 6)
NowLabel.Size = UDim2.new(1, -20, 0, 18)
NowLabel.BackgroundTransparency = 1
NowLabel.Font = Enum.Font.GothamBold
NowLabel.Text = "Current Server"
NowLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
NowLabel.TextSize = 12
NowLabel.TextXAlignment = Enum.TextXAlignment.Left

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Parent = StatusCard
StatusLabel.Position = UDim2.fromOffset(10, 24)
StatusLabel.Size = UDim2.new(1, -20, 0, 22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "Ready to search"
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextWrapped = true

local function makeButton(text, y, color)
    local button = Instance.new("TextButton")
    button.Parent = MainFrame
    button.Position = UDim2.fromOffset(15, y)
    button.Size = UDim2.new(1, -30, 0, 34)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 11
    Instance.new("UICorner", button).CornerRadius =
        UDim.new(0, 8)
    return button
end

local JoinBtn = makeButton(
    "HOP SERVER NOW",
    110,
    Color3.fromRGB(0, 140, 255)
)

local AutoBtn = makeButton(
    "AUTO HOP: DISABLED",
    150,
    Color3.fromRGB(35, 30, 50)
)

local function setStatus(message, color)
    if not ScreenGui.Parent then return end
    StatusLabel.Text = message
    StatusLabel.TextColor3 = color or
        Color3.fromRGB(160, 160, 180)
end

local function getRandomServer()
    local baseUrl =
        "https://games.roblox.com/v1/games/"
        .. PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"

    local cursor = nil
    local candidates = {}
    local seen = {}
    local currentId = tostring(game.JobId)

    -- Revisa hasta 5 páginas por búsqueda.
    for page = 1, 5 do
        if not running then return nil end

        local url = baseUrl
        if cursor then
            url = url .. "&cursor=" ..
                HttpService:UrlEncode(cursor)
        end

        local ok, raw = pcall(function()
            return game:HttpGet(url)
        end)

        if not ok or not raw then
            warn("ByChinnito: fallo al consultar la API")
            break
        end

        local decoded, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)

        if not decoded or type(data) ~= "table"
            or type(data.data) ~= "table" then
            warn("ByChinnito: respuesta API inválida")
            break
        end

        for _, server in ipairs(data.data) do
            if server.id
                and tostring(server.id) ~= currentId
                and (not server.maxPlayers
                    or not server.playing
                    or server.playing < server.maxPlayers)
                and not seen[tostring(server.id)] then

                seen[tostring(server.id)] = true
                table.insert(candidates, tostring(server.id))
            end
        end

        cursor = data.nextPageCursor
        if not cursor then break end
        task.wait(0.25)
    end

    if #candidates == 0 then
        return nil
    end

    return candidates[math.random(1, #candidates)]
end

local function hopServer()
    if busy then return end
    busy = true

    setStatus("Searching public servers...",
        Color3.fromRGB(255, 180, 50))

    local ok, serverId = pcall(getRandomServer)

    if not ok or not serverId then
        setStatus("No server found. Try again.",
            Color3.fromRGB(255, 80, 80))
        busy = false
        return
    end

    setStatus("Joining another server...",
        Color3.fromRGB(0, 230, 255))

    local teleported, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PlaceId,
            serverId,
            LocalPlayer
        )
    end)

    if not teleported then
        warn("ByChinnito teleport error: " .. tostring(err))
        setStatus("Teleport failed. Try again.",
            Color3.fromRGB(255, 80, 80))
        busy = false
        return
    end

    -- Evita solicitudes repetidas mientras cambia de servidor.
    task.delay(8, function()
        busy = false
    end)
end

JoinBtn.Activated:Connect(function()
    task.spawn(hopServer)
end)

AutoBtn.Activated:Connect(function()
    autoEnabled = not autoEnabled

    if autoEnabled then
        AutoBtn.Text = "AUTO HOP: ENABLED"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
        setStatus("Auto hop enabled",
            Color3.fromRGB(0, 230, 150))

        task.spawn(function()
            while running and autoEnabled do
                if not busy then
                    hopServer()
                end
                task.wait(12)
            end
        end)
    else
        AutoBtn.Text = "AUTO HOP: DISABLED"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
        setStatus("Auto hop stopped")
    end
end)

CloseBtn.Activated:Connect(function()
    running = false
    autoEnabled = false
    ScreenGui:Destroy()
end)

task.spawn(function()
    while running and ScreenGui.Parent do
        NowLabel.Text = "Current Server: "
            .. #Players:GetPlayers() .. " player(s)"
        task.wait(1)
    end
end)

print("ByChinnito Server Finder loaded")