--// ByChinnito Private Server Finder
--// Up to 10 pages / ~500 servers
--// Random public server + Auto Hop + Diagnostics

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlaceId = game.PlaceId

local running = true
local autoHop = false
local busy = false
local teleportPending = false

--// GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "ByChinnitoFinder"
Gui.ResetOnSpawn = false

local Main = Instance.new("Frame")
Main.Parent = Gui
Main.Size = UDim2.fromOffset(310, 270)
Main.Position = UDim2.new(0.5, -155, 0.5, -135)
Main.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Border = Instance.new("UIStroke", Main)
Border.Color = Color3.fromRGB(0, 200, 255)
Border.Thickness = 1.2

local function makeLabel(text, position, size, color, textSize)
    local label = Instance.new("TextLabel")
    label.Parent = Main
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color
    label.TextSize = textSize
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    return label
end

makeLabel(
    "PRIVATE SERVER FINDER",
    UDim2.fromOffset(14, 10),
    UDim2.fromOffset(250, 22),
    Color3.fromRGB(0, 225, 255),
    14
)

makeLabel(
    "by ByChinnito",
    UDim2.fromOffset(14, 32),
    UDim2.fromOffset(200, 16),
    Color3.fromRGB(150, 145, 175),
    10
)

local Close = Instance.new("TextButton")
Close.Parent = Main
Close.Position = UDim2.new(1, -34, 0, 10)
Close.Size = UDim2.fromOffset(22, 22)
Close.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
Close.Text = "X"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 12

Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 5)

local StatusBox = Instance.new("Frame")
StatusBox.Parent = Main
StatusBox.Position = UDim2.fromOffset(12, 58)
StatusBox.Size = UDim2.new(1, -24, 0, 70)
StatusBox.BackgroundColor3 = Color3.fromRGB(25, 21, 40)
StatusBox.BorderSizePixel = 0

Instance.new("UICorner", StatusBox).CornerRadius = UDim.new(0, 8)

local Status = Instance.new("TextLabel")
Status.Parent = StatusBox
Status.Position = UDim2.fromOffset(10, 5)
Status.Size = UDim2.new(1, -20, 1, -10)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.GothamMedium
Status.Text = "Ready to search"
Status.TextColor3 = Color3.fromRGB(180, 180, 200)
Status.TextSize = 11
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(message, color)
    if Status and Status.Parent then
        Status.Text = tostring(message)
        Status.TextColor3 = color or Color3.fromRGB(180, 180, 200)
    end

    print("[ByChinnito] " .. tostring(message))
end

local function makeButton(text, y, color)
    local button = Instance.new("TextButton")
    button.Parent = Main
    button.Position = UDim2.fromOffset(12, y)
    button.Size = UDim2.new(1, -24, 0, 34)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 11

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    return button
end

local HopButton = makeButton(
    "HOP SERVER NOW",
    140,
    Color3.fromRGB(0, 125, 235)
)

local AutoButton = makeButton(
    "AUTO HOP: OFF",
    181,
    Color3.fromRGB(45, 35, 60)
)

--// Auto Hop control
local function stopAutoHop()
    autoHop = false
    AutoButton.Text = "AUTO HOP: OFF"
    AutoButton.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
end

--// Search up to 10 pages
local function findServer()
    local baseUrl =
        "https://games.roblox.com/v1/games/"
        .. tostring(PlaceId)
        .. "/servers/Public?sortOrder=Asc&limit=50"

    local cursor = nil
    local candidates = {}
    local seen = {}
    local maxPages = 10

    for page = 1, maxPages do
        if not running then
            return nil, "Script stopped"
        end

        local url = baseUrl

        if cursor then
            url = baseUrl .. "&cursor="
                .. HttpService:UrlEncode(cursor)
        end

        setStatus(
            "Searching page " .. page .. "/" .. maxPages
            .. " | Found: " .. #candidates
        )

        local requestOK, response = pcall(function()
            return game:HttpGet(url)
        end)

        if not requestOK then
            warn("[ByChinnito] HTTP error: " .. tostring(response))
            break
        end

        local decodeOK, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)

        if not decodeOK or type(data) ~= "table" then
            warn("[ByChinnito] Invalid JSON response")
            break
        end

        if type(data.errors) == "table" and #data.errors > 0 then
            warn("[ByChinnito] API ERROR DETAILS: " .. tostring(response))
            break
        end

        if type(data.data) ~= "table" then
            warn("[ByChinnito] Unexpected API response: " .. tostring(response))
            break
        end

        for _, server in ipairs(data.data) do
            local id = server.id
            local playing = tonumber(server.playing) or 0
            local maximum = tonumber(server.maxPlayers) or 0

            if id
                and tostring(id) ~= tostring(game.JobId)
                and not seen[tostring(id)]
                and maximum > playing then

                seen[tostring(id)] = true

                table.insert(candidates, {
                    id = tostring(id),
                    playing = playing,
                    maximum = maximum
                })
            end
        end

        print(
            "[ByChinnito] Page " .. page
            .. ": " .. #data.data
            .. " servers; available: " .. #candidates
        )

        cursor = data.nextPageCursor

        if not cursor or cursor == "" then
            break
        end

        task.wait(0.3)
    end

    print(
        "[ByChinnito] Total available candidates: "
        .. #candidates
    )

    if #candidates == 0 then
        return nil, "No available servers found; check the console"
    end

    local selected = candidates[math.random(1, #candidates)]

    setStatus(
        "Selected server: "
        .. selected.playing .. "/" .. selected.maximum
        .. " players",
        Color3.fromRGB(0, 225, 180)
    )

    return selected.id
end

--// Teleport failure diagnostics
TeleportService.TeleportInitFailed:Connect(
    function(who, result, message)
        if who == Player then
            teleportPending = false
            busy = false

            setStatus(
                "Teleport failed: " .. tostring(result)
                .. " - " .. tostring(message),
                Color3.fromRGB(255, 80, 80)
            )

            stopAutoHop()
        end
    end
)

--// Hop action
local function hopServer()
    if busy or not running then
        return
    end

    busy = true
    teleportPending = false

    setStatus("Searching public servers...")

    local searchOK, serverId, searchError = pcall(findServer)

    if not searchOK then
        setStatus(
            "Search exception: " .. tostring(serverId),
            Color3.fromRGB(255, 80, 80)
        )

        stopAutoHop()
        busy = false
        return
    end

    if not serverId then
        setStatus(
            "Search failed: " .. tostring(searchError or "Unknown error"),
            Color3.fromRGB(255, 170, 50)
        )

        warn("[ByChinnito] Search failed: " .. tostring(searchError))

        stopAutoHop()
        busy = false
        return
    end

    setStatus("Server found. Requesting teleport...")

    local teleportOK, teleportError = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PlaceId,
            serverId,
            Player
        )
    end)

    if not teleportOK then
        setStatus(
            "Teleport call error: " .. tostring(teleportError),
            Color3.fromRGB(255, 80, 80)
        )

        stopAutoHop()
        busy = false
        return
    end

    teleportPending = true
    setStatus("Teleport requested; waiting for Roblox...")

    task.delay(15, function()
        if running and teleportPending then
            teleportPending = false
            busy = false

            setStatus(
                "No confirmation from Roblox. Retry manually.",
                Color3.fromRGB(255, 180, 50)
            )

            stopAutoHop()
        end
    end)
end

--// Buttons
HopButton.Activated:Connect(function()
    task.spawn(hopServer)
end)

AutoButton.Activated:Connect(function()
    if autoHop then
        stopAutoHop()
        setStatus("Automatic hopping stopped")
        return
    end

    autoHop = true
    AutoButton.Text = "AUTO HOP: ON"
    AutoButton.BackgroundColor3 = Color3.fromRGB(0, 145, 100)

    setStatus("Automatic hopping enabled")

    task.spawn(function()
        while running and autoHop do
            if not busy then
                hopServer()
            end

            task.wait(15)
        end
    end)
end)

Close.Activated:Connect(function()
    running = false
    stopAutoHop()
    teleportPending = false
    Gui:Destroy()
end)

Gui.Parent = Player:WaitForChild("PlayerGui")

print("[ByChinnito] Private Server Finder loaded successfully")
