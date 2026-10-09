
--// BYCHINNITO PRIVATE SERVER FINDER v5
--// Interfaz profesional, busqueda incremental, filtros,
--// historial, pausa HTTP inteligente y recuperacion de errores.
--// IMPORTANTE: request/http_request depende del entorno de ejecucion.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlaceId = 107778070777162

--==================================================
-- CONFIGURACION
--==================================================

local CONFIG = {
    MaxPages = 20,
    TargetCandidates = 80,
    MaxRetries = 3,
    PageDelay = 2,
    AutoHopDelay = 8,
    DefaultCooldown = 30,
    TeleportTimeout = 25,
    HistoryLimit = 40,

    -- Filtros
    MinPlayers = 0,
    MaxPlayers = math.huge,
    PreferAvailableSlots = true,
}

--==================================================
-- ESTADO
--==================================================

local State = {
    searching = false,
    teleporting = false,
    autoHop = false,
    autoLoopRunning = false,
    closed = false,

    rateLimitedUntil = 0,
    pagesRead = 0,
    lastTeleportServer = nil,
    teleportToken = 0,
    searchToken = 0,

    candidates = {},
    candidateSet = {},
    failedServers = {},
    attemptedServers = {},
    history = {},
}

local function now()
    return os.clock()
end

local function remainingCooldown()
    return math.max(0, math.ceil(State.rateLimitedUntil - now()))
end

--==================================================
-- COLORES
--==================================================

local C = {
    Background = Color3.fromRGB(12, 13, 21),
    Panel = Color3.fromRGB(22, 24, 36),
    Panel2 = Color3.fromRGB(29, 31, 46),
    Panel3 = Color3.fromRGB(38, 40, 57),

    Purple = Color3.fromRGB(148, 102, 255),
    PurpleDark = Color3.fromRGB(103, 69, 210),
    Blue = Color3.fromRGB(83, 145, 255),
    Green = Color3.fromRGB(65, 218, 155),
    Red = Color3.fromRGB(255, 90, 115),
    Yellow = Color3.fromRGB(255, 194, 82),

    White = Color3.fromRGB(244, 245, 255),
    Muted = Color3.fromRGB(150, 155, 180),
    Border = Color3.fromRGB(53, 55, 76),
}

--==================================================
-- LIMPIAR GUI ANTERIOR
--==================================================

pcall(function()
    local old = CoreGui:FindFirstChild("ByChinnitoFinder")
    if old then
        old:Destroy()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ByChinnitoFinder"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local parentOK = pcall(function()
    gui.Parent = CoreGui
end)

if not parentOK or not gui.Parent then
    gui.Parent = Player:WaitForChild("PlayerGui")
end

--==================================================
-- COMPONENTES VISUALES
--==================================================

local function makeCorner(object, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 10)
    item.Parent = object
    return item
end

local function makeStroke(object, color, thickness)
    local item = Instance.new("UIStroke")
    item.Color = color or C.Border
    item.Thickness = thickness or 1
    item.Parent = object
    return item
end

local function makeLabel(parent, text, position, size, textSize, color, font)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Position = position
    item.Size = size
    item.Text = text
    item.TextSize = textSize or 13
    item.TextColor3 = color or C.White
    item.Font = font or Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Center
    item.TextWrapped = true
    item.Parent = parent
    return item
end

local function makeButton(parent, text, position, size, color)
    local item = Instance.new("TextButton")
    item.Position = position
    item.Size = size
    item.BackgroundColor3 = color or C.Panel2
    item.BorderSizePixel = 0
    item.Text = text
    item.TextSize = 12
    item.TextColor3 = C.White
    item.Font = Enum.Font.GothamSemibold
    item.AutoButtonColor = true
    item.Parent = parent
    makeCorner(item, 9)
    return item
end

local function makeTextBox(parent, placeholder, position, size, initialText)
    local item = Instance.new("TextBox")
    item.Position = position
    item.Size = size
    item.BackgroundColor3 = C.Panel2
    item.BorderSizePixel = 0
    item.Text = initialText or ""
    item.PlaceholderText = placeholder
    item.PlaceholderColor3 = C.Muted
    item.TextColor3 = C.White
    item.TextSize = 12
    item.Font = Enum.Font.Gotham
    item.ClearTextOnFocus = false
    item.Parent = parent
    makeCorner(item, 8)
    return item
end

--==================================================
-- VENTANA PRINCIPAL
--==================================================

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(440, 540)
main.Position = UDim2.new(0.5, -220, 0.5, -270)
main.BackgroundColor3 = C.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
makeCorner(main, 16)
makeStroke(main, C.Border, 1)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 66)
top.BackgroundColor3 = C.Panel
top.BorderSizePixel = 0
top.Parent = main

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, 0, 0, 3)
accent.BackgroundColor3 = C.Purple
accent.BorderSizePixel = 0
accent.Parent = top

local logo = Instance.new("Frame")
logo.Position = UDim2.fromOffset(15, 14)
logo.Size = UDim2.fromOffset(38, 38)
logo.BackgroundColor3 = C.PurpleDark
logo.BorderSizePixel = 0
logo.Parent = top
makeCorner(logo, 11)

local logoText = makeLabel(
    logo, "B", UDim2.new(), UDim2.new(1, 0, 1, 0),
    22, C.White, Enum.Font.GothamBold
)
logoText.TextXAlignment = Enum.TextXAlignment.Center

makeLabel(
    top, "BYCHINNITO",
    UDim2.fromOffset(64, 11),
    UDim2.fromOffset(235, 24),
    16, C.White, Enum.Font.GothamBold
)

makeLabel(
    top, "PRIVATE SERVER FINDER  /  V5",
    UDim2.fromOffset(65, 35),
    UDim2.fromOffset(255, 17),
    10, C.Muted, Enum.Font.GothamSemibold
)

local minimizeButton = makeButton(
    top, "—", UDim2.new(1, -77, 0, 17),
    UDim2.fromOffset(27, 27), C.Panel2
)

local closeButton = makeButton(
    top, "×", UDim2.new(1, -42, 0, 17),
    UDim2.fromOffset(27, 27), C.Panel2
)
closeButton.TextSize = 19

--==================================================
-- ESTADO Y PROGRESO
--==================================================

local statusCard = Instance.new("Frame")
statusCard.Position = UDim2.fromOffset(14, 78)
statusCard.Size = UDim2.new(1, -28, 0, 67)
statusCard.BackgroundColor3 = C.Panel
statusCard.BorderSizePixel = 0
statusCard.Parent = main
makeCorner(statusCard, 11)
makeStroke(statusCard, C.Border, 1)

local statusDot = Instance.new("Frame")
statusDot.Position = UDim2.fromOffset(13, 17)
statusDot.Size = UDim2.fromOffset(9, 9)
statusDot.BackgroundColor3 = C.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
makeCorner(statusDot, 8)

local statusTitle = makeLabel(
    statusCard, "LISTO PARA BUSCAR",
    UDim2.fromOffset(30, 8),
    UDim2.new(1, -42, 0, 22),
    12, C.Green, Enum.Font.GothamBold
)

local statusDetail = makeLabel(
    statusCard, "Preparado para buscar servidores.",
    UDim2.fromOffset(13, 34),
    UDim2.new(1, -25, 0, 23),
    11, C.Muted
)

local function makeStat(x, titleText, initialValue, color)
    local card = Instance.new("Frame")
    card.Position = UDim2.fromOffset(x, 153)
    card.Size = UDim2.fromOffset(128, 54)
    card.BackgroundColor3 = C.Panel
    card.BorderSizePixel = 0
    card.Parent = main
    makeCorner(card, 10)
    makeStroke(card, C.Border, 1)

    makeLabel(
        card, titleText,
        UDim2.fromOffset(10, 5),
        UDim2.new(1, -15, 0, 16),
        9, C.Muted, Enum.Font.GothamBold
    )

    return makeLabel(
        card, initialValue,
        UDim2.fromOffset(10, 21),
        UDim2.new(1, -15, 0, 25),
        18, color, Enum.Font.GothamBold
    )
end

local candidateStat = makeStat(14, "CANDIDATOS", "0", C.Purple)
local pagesStat = makeStat(156, "PAGINAS", "0/20", C.Blue)
local autoStat = makeStat(298, "AUTO HOP", "OFF", C.Yellow)

makeLabel(
    main, "PROGRESO",
    UDim2.fromOffset(16, 214),
    UDim2.fromOffset(100, 18),
    10, C.Muted, Enum.Font.GothamBold
)

local progressText = makeLabel(
    main, "ESPERANDO",
    UDim2.new(1, -150, 0, 214),
    UDim2.fromOffset(133, 18),
    10, C.Muted
)
progressText.TextXAlignment = Enum.TextXAlignment.Right

local progressBG = Instance.new("Frame")
progressBG.Position = UDim2.fromOffset(15, 235)
progressBG.Size = UDim2.new(1, -30, 0, 7)
progressBG.BackgroundColor3 = C.Panel3
progressBG.BorderSizePixel = 0
progressBG.Parent = main
makeCorner(progressBG, 5)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = C.Purple
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBG
makeCorner(progressFill, 5)

--==================================================
-- FILTROS
--==================================================

makeLabel(
    main, "FILTROS DE SERVIDOR",
    UDim2.fromOffset(16, 250),
    UDim2.fromOffset(180, 18),
    10, C.Muted, Enum.Font.GothamBold
)

makeLabel(
    main, "Jugadores mín.",
    UDim2.fromOffset(16, 273),
    UDim2.fromOffset(100, 18),
    10, C.Muted
)

local minBox = makeTextBox(
    main, "0",
    UDim2.fromOffset(112, 271),
    UDim2.fromOffset(55, 25), "0"
)

makeLabel(
    main, "Jugadores máx.",
    UDim2.fromOffset(184, 273),
    UDim2.fromOffset(100, 18),
    10, C.Muted
)

local maxBox = makeTextBox(
    main, "100",
    UDim2.fromOffset(286, 271),
    UDim2.fromOffset(55, 25), "100"
)

local availableOnly = true

local filterButton = makeButton(
    main, "✓ PRIORIZAR ESPACIOS LIBRES",
    UDim2.fromOffset(15, 304),
    UDim2.new(1, -30, 0, 29), C.Panel2
)

--==================================================
-- ACCIONES
--==================================================

local searchButton = makeButton(
    main, "BUSCAR Y ENTRAR",
    UDim2.fromOffset(15, 343),
    UDim2.new(1, -30, 0, 37), C.PurpleDark
)

local refreshButton = makeButton(
    main, "ACTUALIZAR LISTA",
    UDim2.fromOffset(15, 388),
    UDim2.new(0.5, -20, 0, 34), C.Panel2
)

local autoButton = makeButton(
    main, "AUTO HOP: OFF",
    UDim2.new(0.5, 5, 0, 388),
    UDim2.new(0.5, -20, 0, 34), C.Panel2
)

local historyButton = makeButton(
    main, "VER HISTORIAL",
    UDim2.fromOffset(15, 430),
    UDim2.new(0.5, -20, 0, 32), C.Panel2
)

local cancelButton = makeButton(
    main, "CANCELAR BUSQUEDA",
    UDim2.new(0.5, 5, 0, 430),
    UDim2.new(0.5, -20, 0, 32), C.Panel2
)

local footer = makeLabel(
    main, "ByChinnito  •  v5.0",
    UDim2.fromOffset(15, 496),
    UDim2.new(1, -30, 0, 20),
    10, C.Muted
)

--==================================================
-- PANEL DE HISTORIAL
--==================================================

local historyPanel = Instance.new("Frame")
historyPanel.Position = UDim2.fromOffset(14, 78)
historyPanel.Size = UDim2.new(1, -28, 1, -92)
historyPanel.BackgroundColor3 = C.Panel
historyPanel.BorderSizePixel = 0
historyPanel.Visible = false
historyPanel.Parent = main
makeCorner(historyPanel, 12)
makeStroke(historyPanel, C.Border, 1)

makeLabel(
    historyPanel, "HISTORIAL DE INTENTOS",
    UDim2.fromOffset(12, 9),
    UDim2.new(1, -24, 0, 23),
    12, C.White, Enum.Font.GothamBold
)

local clearHistoryButton = makeButton(
    historyPanel, "LIMPIAR",
    UDim2.new(1, -83, 0, 8),
    UDim2.fromOffset(70, 25), C.Panel3
)

local historyScroll = Instance.new("ScrollingFrame")
historyScroll.Position = UDim2.fromOffset(10, 42)
historyScroll.Size = UDim2.new(1, -20, 1, -52)
historyScroll.BackgroundColor3 = C.Background
historyScroll.BorderSizePixel = 0
historyScroll.ScrollBarThickness = 4
historyScroll.CanvasSize = UDim2.new()
historyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
historyScroll.Parent = historyPanel
makeCorner(historyScroll, 8)

local historyLayout = Instance.new("UIListLayout")
historyLayout.Padding = UDim.new(0, 5)
historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
historyLayout.Parent = historyScroll

local historyPadding = Instance.new("UIPadding")
historyPadding.PaddingTop = UDim.new(0, 7)
historyPadding.PaddingBottom = UDim.new(0, 7)
historyPadding.PaddingLeft = UDim.new(0, 7)
historyPadding.PaddingRight = UDim.new(0, 7)
historyPadding.Parent = historyScroll

--==================================================
-- ACTUALIZAR INTERFAZ
--==================================================

local function updateStats()
    if State.closed then return end

    candidateStat.Text = tostring(#State.candidates)
    pagesStat.Text = tostring(State.pagesRead) .. "/" .. CONFIG.MaxPages
    autoStat.Text = State.autoHop and "ON" or "OFF"
    autoStat.TextColor3 = State.autoHop and C.Green or C.Yellow
end

local function setStatus(title, detail, color)
    if State.closed then return end

    statusTitle.Text = title
    statusDetail.Text = detail
    statusTitle.TextColor3 = color or C.Green
    statusDot.BackgroundColor3 = color or C.Green

    updateStats()
end

local function setProgress(amount, text)
    if State.closed then return end

    progressFill:TweenSize(
        UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quad,
        0.12,
        true
    )

    progressText.Text = text or tostring(math.floor(amount * 100)) .. "%"
end

local function addHistory(message, color)
    if State.closed then return end

    local entry = {
        time = os.date("%H:%M:%S"),
        message = tostring(message),
        color = color or C.Muted,
    }

    table.insert(State.history, 1, entry)

    while #State.history > CONFIG.HistoryLimit do
        table.remove(State.history)
    end

    if not historyPanel.Visible then
        return
    end

    for _, child in ipairs(historyScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for i, record in ipairs(State.history) do
        local row = Instance.new("TextLabel")
        row.LayoutOrder = i
        row.Size = UDim2.new(1, -4, 0, 38)
        row.BackgroundColor3 = C.Panel2
        row.BorderSizePixel = 0
        row.Text = "[" .. record.time .. "] " .. record.message
        row.TextColor3 = record.color
        row.TextSize = 10
        row.Font = Enum.Font.Gotham
        row.TextWrapped = true
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = historyScroll
        makeCorner(row, 6)

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 7)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = row
    end
end

--==================================================
-- ARRASTRAR VENTANA
--==================================================

local dragging = false
local dragStart
local startPosition

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

--==================================================
-- MINIMIZAR Y CERRAR
--==================================================

local minimized = false
local normalSize = main.Size

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        main.Size = UDim2.fromOffset(440, 66)
        minimizeButton.Text = "+"
    else
        main.Size = normalSize
        minimizeButton.Text = "—"
    end
end)

closeButton.MouseButton1Click:Connect(function()
    State.closed = true
    State.autoHop = false
    State.searchToken = State.searchToken + 1
    State.teleportToken = State.teleportToken + 1
    gui:Destroy()
end)

--==================================================
-- FILTROS
--==================================================

local function readFilters()
    local minPlayers = tonumber(minBox.Text)
    local maxPlayers = tonumber(maxBox.Text)

    if not minPlayers or not maxPlayers then
        return nil, "Introduce números válidos en los filtros."
    end

    minPlayers = math.floor(minPlayers)
    maxPlayers = math.floor(maxPlayers)

    if minPlayers < 0 or maxPlayers < minPlayers then
        return nil, "El máximo debe ser mayor o igual al mínimo."
    end

    return {
        minPlayers = minPlayers,
        maxPlayers = maxPlayers,
    }
end

filterButton.MouseButton1Click:Connect(function()
    availableOnly = not availableOnly

    filterButton.Text = availableOnly
        and "✓ PRIORIZAR ESPACIOS LIBRES"
        or "○ SIN PRIORIDAD DE ESPACIOS"

    filterButton.BackgroundColor3 = availableOnly
        and C.PurpleDark or C.Panel2
end)

--==================================================
-- SOLICITUD HTTP
--==================================================

local function getRequestFunction()
    if type(request) == "function" then
        return request
    elseif type(http_request) == "function" then
        return http_request
    elseif type(http) == "table"
        and type(http.request) == "function" then
        return http.request
    end

    return nil
end

local function getJSON(url, token)
    local requestFunction = getRequestFunction()

    if not requestFunction then
        return nil, "No hay función HTTP compatible."
    end

    if now() < State.rateLimitedUntil then
        return nil, "HTTP en pausa: quedan "
            .. remainingCooldown() .. " segundos."
    end

    for attempt = 1, CONFIG.MaxRetries do
        if State.closed or token ~= State.searchToken then
            return nil, "Búsqueda cancelada."
        end

        if now() < State.rateLimitedUntil then
            return nil, "HTTP en pausa: quedan "
                .. remainingCooldown() .. " segundos."
        end

        local ok, response = pcall(function()
            return requestFunction({
                Url = url,
                Method = "GET",
                Headers = {
                    ["Accept"] = "application/json",
                },
            })
        end)

        if ok and type(response) == "table" then
            local code = tonumber(response.StatusCode)
            local body = response.Body

            if code == 200 and type(body) == "string" then
                local decoded, data = pcall(function()
                    return HttpService:JSONDecode(body)
                end)

                if decoded and type(data) == "table"
                    and type(data.data) == "table" then
                    return data
                end

                return nil, "Respuesta JSON inesperada."
            end

            if code == 429 then
                local retryAfter = 0
                local headers = response.Headers

                if type(headers) == "table" then
                    retryAfter = tonumber(
                        headers["Retry-After"]
                        or headers["retry-after"]
                    ) or 0
                end

                State.rateLimitedUntil = now() + math.max(
                    CONFIG.DefaultCooldown,
                    retryAfter
                )

                setStatus(
                    "PAUSA HTTP 429",
                    "Reintento disponible en "
                        .. remainingCooldown() .. " segundos.",
                    C.Yellow
                )

                setProgress(0, "PAUSA HTTP")
                addHistory("HTTP 429: consultas pausadas.", C.Yellow)

                return nil, "HTTP 429."
            end

            if code and code >= 500 and attempt < CONFIG.MaxRetries then
                addHistory(
                    "HTTP " .. tostring(code) .. ": reintentando.",
                    C.Yellow
                )
                task.wait(attempt * 2)
            else
                return nil, "HTTP " .. tostring(code)
            end
        else
            if attempt < CONFIG.MaxRetries then
                addHistory("Fallo de red; reintentando.", C.Yellow)
                task.wait(attempt * 2)
            else
                return nil, "Error de solicitud HTTP."
            end
        end
    end

    return nil, "Se agotaron los reintentos."
end

--==================================================
-- GESTION DE CANDIDATOS
--==================================================

local function clearCandidates()
    table.clear(State.candidates)
    table.clear(State.candidateSet)
    updateStats()
end

local function addCandidate(server, filters)
    if type(server) ~= "table" or type(server.id) ~= "string" then
        return
    end

    local id = server.id
    local playing = tonumber(server.playing)
    local maxPlayers = tonumber(server.maxPlayers)

    if not playing or not maxPlayers then
        return
    end

    if id == game.JobId
        or State.candidateSet[id]
        or State.failedServers[id]
        or State.attemptedServers[id] then
        return
    end

    if playing >= maxPlayers then
        return
    end

    if playing < filters.minPlayers or playing > filters.maxPlayers then
        return
    end

    State.candidateSet[id] = true

    table.insert(State.candidates, {
        id = id,
        playing = playing,
        maxPlayers = maxPlayers,
        freeSlots = maxPlayers - playing,
    })
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
end

local function prioritizeCandidates()
    if availableOnly then
        table.sort(State.candidates, function(a, b)
            return a.freeSlots > b.freeSlots
        end)
    else
        shuffle(State.candidates)
    end
end

local function removeCandidate(id)
    State.candidateSet[id] = nil

    for i = #State.candidates, 1, -1 do
        if State.candidates[i].id == id then
            table.remove(State.candidates, i)
        end
    end

    updateStats()
end

--==================================================
-- BUSQUEDA INCREMENTAL
--==================================================

local function searchMore(replaceExisting)
    if State.searching or State.closed or State.teleporting then
        return false
    end

    if now() < State.rateLimitedUntil then
        setStatus(
            "BUSQUEDA EN PAUSA",
            "Espera " .. remainingCooldown() .. " segundos.",
            C.Yellow
        )
        return false
    end

    local filters, filterError = readFilters()

    if not filters then
        setStatus("FILTROS INVALIDOS", filterError, C.Red)
        addHistory(filterError, C.Red)
        return false
    end

    State.searching = true
    State.searchToken = State.searchToken + 1

    local token = State.searchToken

    -- Construir una lista temporal para no perder candidatos
    -- anteriores si la actualización falla.
    local oldCandidates = State.candidates
    local oldCandidateSet = State.candidateSet

    if replaceExisting then
        State.candidates = {}
        State.candidateSet = {}
    end

    State.pagesRead = 0
    local cursor = nil
    local interrupted = false
    local requestError = nil

    local ok, err = pcall(function()
        for page = 1, CONFIG.MaxPages do
            if State.closed or token ~= State.searchToken then
                interrupted = true
                break
            end

            if #State.candidates >= CONFIG.TargetCandidates then
                break
            end

            if now() < State.rateLimitedUntil then
                interrupted = true
                requestError = "Pausa HTTP activa."
                break
            end

            local url = "https://games.roblox.com/v1/games/"
                .. PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=100"

            if cursor and cursor ~= "" then
                url = url .. "&cursor="
                    .. HttpService:UrlEncode(cursor)
            end

            setStatus(
                "BUSCANDO SERVIDORES",
                "Página " .. page .. " de " .. CONFIG.MaxPages,
                C.Blue
            )

            setProgress(
                (page - 1) / CONFIG.MaxPages,
                "PAGINA " .. page
            )

            local data, errRequest = getJSON(url, token)

            if not data then
                interrupted = true
                requestError = errRequest
                break
            end

            State.pagesRead = State.pagesRead + 1

            for _, server in ipairs(data.data) do
                addCandidate(server, filters)
            end

            updateStats()
            setProgress(
                page / CONFIG.MaxPages,
                "PAGINA " .. page
            )

            cursor = data.nextPageCursor

            if not cursor or cursor == "" then
                break
            end

            if page < CONFIG.MaxPages then
                task.wait(CONFIG.PageDelay)
            end
        end
    end)

    State.searching = false

    -- Si la actualización no obtuvo datos nuevos, restaurar la lista.
    if replaceExisting and #State.candidates == 0
        and #oldCandidates > 0 then
        State.candidates = oldCandidates
        State.candidateSet = oldCandidateSet
    end

    prioritizeCandidates()
    updateStats()

    if not ok then
        setStatus("ERROR DE BUSQUEDA", tostring(err), C.Red)
        addHistory("Error de búsqueda: " .. tostring(err), C.Red)
        return false
    end

    if State.closed then
        return false
    end

    if interrupted then
        local message = tostring(requestError or "Búsqueda interrumpida")

        setStatus(
            "BUSQUEDA INTERRUMPIDA",
            message .. " | Candidatos: " .. #State.candidates,
            C.Yellow
        )

        addHistory(message, C.Yellow)
        return #State.candidates > 0
    end

    setProgress(1, "COMPLETADO")

    if #State.candidates > 0 then
        setStatus(
            "SERVIDORES ENCONTRADOS",
            #State.candidates .. " candidatos disponibles.",
            C.Green
        )
        addHistory(
            "Búsqueda finalizada: " .. #State.candidates
                .. " candidatos.",
            C.Green
        )
        return true
    end

    setStatus(
        "SIN RESULTADOS",
        "Prueba otros filtros o vuelve a buscar.",
        C.Yellow
    )
    addHistory("La búsqueda no encontró candidatos.", C.Yellow)

    return false
end

--==================================================
-- TELETRANSPORTE Y RECUPERACION
--==================================================

local function nextTeleport()
    if State.closed or State.teleporting or State.searching then
        return
    end

    while #State.candidates > 0 do
        local server = table.remove(State.candidates, 1)
        State.candidateSet[server.id] = nil
        updateStats()

        if server.id ~= game.JobId
            and not State.failedServers[server.id]
            and not State.attemptedServers[server.id] then

            State.teleporting = true
            State.lastTeleportServer = server.id
            State.attemptedServers[server.id] = true
            State.teleportToken = State.teleportToken + 1

            local token = State.teleportToken

            setStatus(
                "CONECTANDO",
                "Probando servidor con " .. server.playing
                    .. "/" .. server.maxPlayers .. " jugadores.",
                C.Blue
            )

            setProgress(0.9, "TELEPORT")
            addHistory("Intentando servidor " .. server.id, C.Blue)

            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    PlaceId,
                    server.id,
                    Player
                )
            end)

            if not ok then
                State.failedServers[server.id] = true
                State.teleporting = false
                State.lastTeleportServer = nil

                setStatus(
                    "TELEPORT FALLIDO",
                    tostring(err),
                    C.Red
                )
                addHistory(
                    "Llamada de teletransporte fallida: " .. tostring(err),
                    C.Red
                )
            else
                task.delay(CONFIG.TeleportTimeout, function()
                    if State.closed
                        or not State.teleporting
                        or State.teleportToken ~= token then
                        return
                    end

                    -- Resultado incierto: no declarar fallo automáticamente.
                    -- Se desbloquea el estado para permitir recuperación.
                    State.teleporting = false
                    State.lastTeleportServer = nil

                    setStatus(
                        "TELEPORT SIN CONFIRMAR",
                        "No llegó confirmación. Puedes reintentar.",
                        C.Yellow
                    )
                    addHistory(
                        "Teletransporte sin confirmación; resultado incierto.",
                        C.Yellow
                    )
                end)

                return
            end
        end
    end

    State.teleporting = false
    State.lastTeleportServer = nil

    setStatus(
        "LISTA AGOTADA",
        "Actualiza la lista para encontrar más servidores.",
        C.Yellow
    )
    setProgress(0, "ESPERANDO")
end

TeleportService.TeleportInitFailed:Connect(function(
    player, result, message, placeId
)
    if player ~= Player or placeId ~= PlaceId or State.closed then
        return
    end

    local id = State.lastTeleportServer

    if id then
        State.failedServers[id] = true
        addHistory(
            "Teletransporte rechazado: " .. tostring(result)
                .. " / " .. tostring(message),
            C.Red
        )
        removeCandidate(id)
    end

    State.teleportToken = State.teleportToken + 1
    State.teleporting = false
    State.lastTeleportServer = nil

    setStatus(
        "TELEPORT RECHAZADO",
        tostring(result) .. " | " .. tostring(message),
        C.Red
    )

    if State.autoHop then
        task.delay(1, function()
            if not State.closed
                and State.autoHop
                and not State.searching
                and not State.teleporting then
                nextTeleport()
            end
        end)
    end
end)

--==================================================
-- BOTONES DE ACCION
--==================================================

local function runFinder()
    if State.closed or State.searching or State.teleporting then
        return
    end

    if #State.candidates > 0 then
        nextTeleport()
        return
    end

    task.spawn(function()
        local found = searchMore(false)

        if not State.closed and found
            and not State.teleporting then
            nextTeleport()
        end
    end)
end

searchButton.MouseButton1Click:Connect(function()
    runFinder()
end)

-- Actualizar lista: búsqueda incremental sin entrar automáticamente.
refreshButton.MouseButton1Click:Connect(function()
    if State.closed or State.searching or State.teleporting then
        return
    end

    task.spawn(function()
        searchMore(false)
    end)
end)

-- Auto Hop: un solo ciclo.
autoButton.MouseButton1Click:Connect(function()
    State.autoHop = not State.autoHop

    autoButton.Text = State.autoHop and "AUTO HOP: ON" or "AUTO HOP: OFF"
    autoButton.BackgroundColor3 =
        State.autoHop and C.PurpleDark or C.Panel2

    updateStats()

    if not State.autoHop or State.autoLoopRunning then
        return
    end

    State.autoLoopRunning = true

    task.spawn(function()
        while State.autoHop and not State.closed do
            if not State.searching and not State.teleporting then
                if now() < State.rateLimitedUntil then
                    setStatus(
                        "AUTO HOP EN PAUSA",
                        "Reintento en " .. remainingCooldown() .. " segundos.",
                        C.Yellow
                    )
                elseif #State.candidates > 0 then
                    nextTeleport()
                else
                    runFinder()
                end
            end

            task.wait(CONFIG.AutoHopDelay)
        end

        State.autoLoopRunning = false
    end)
end)

-- Cancelar búsqueda invalidando su token.
cancelButton.MouseButton1Click:Connect(function()
    if State.searching then
        State.searchToken = State.searchToken + 1
        setStatus(
            "CANCELANDO BUSQUEDA",
            "Se detendrá después de la solicitud actual.",
            C.Yellow
        )
        addHistory("Cancelación de búsqueda solicitada.", C.Yellow)
    else
        State.autoHop = false
        autoButton.Text = "AUTO HOP: OFF"
        autoButton.BackgroundColor3 = C.Panel2
        updateStats()
        setStatus(
            "AUTO HOP DETENIDO",
            "La búsqueda automática está desactivada.",
            C.Yellow
        )
    end
end)

historyButton.MouseButton1Click:Connect(function()
    historyPanel.Visible = not historyPanel.Visible

    if historyPanel.Visible then
        historyButton.Text = "VOLVER"
        statusCard.Visible = false
        candidateStat.Parent.Visible = false
        pagesStat.Parent.Visible = false
        autoStat.Parent.Visible = false
        progressBG.Visible = false
        progressText.Visible = false
        searchButton.Visible = false
        refreshButton.Visible = false
        autoButton.Visible = false
        filterButton.Visible = false
        minBox.Visible = false
        maxBox.Visible = false
        cancelButton.Visible = false
        footer.Visible = false
    else
        historyButton.Text = "VER HISTORIAL"
        statusCard.Visible = true
        candidateStat.Parent.Visible = true
        pagesStat.Parent.Visible = true
        autoStat.Parent.Visible = true
        progressBG.Visible = true
        progressText.Visible = true
        searchButton.Visible = true
        refreshButton.Visible = true
        autoButton.Visible = true
        filterButton.Visible = true
        minBox.Visible = true
        maxBox.Visible = true
        cancelButton.Visible = true
        footer.Visible = true
    end

    addHistory("Panel de historial abierto.", C.Muted)
end)

clearHistoryButton.MouseButton1Click:Connect(function()
    table.clear(State.history)

    for _, child in ipairs(historyScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)

--==================================================
-- INICIO
--==================================================

updateStats()
setProgress(0, "ESPERANDO")
addHistory("ByChinnito Private Server Finder v5 iniciado.", C.Green)

print("[ByChinnito] Private Server Finder v5 iniciado")
