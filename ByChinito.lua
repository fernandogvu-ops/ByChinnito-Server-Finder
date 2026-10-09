--// BYCHINNITO PRIVATE SERVER FINDER v3
--// GUI moderna + buscador de servidores + Auto Hop
--// Roblox puede limitar las solicitudes o rechazar teletransportes.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlaceId = 107778070777162

-- CONFIGURACION
local MAX_PAGES = 20
local TARGET_CANDIDATES = 80
local MAX_RETRIES = 3
local PAGE_DELAY = 2
local AUTO_HOP_DELAY = 8
local RATE_LIMIT_COOLDOWN = 30
local TELEPORT_TIMEOUT = 20

-- ESTADO
local searching = false
local teleporting = false
local autoHop = false
local closed = false
local rateLimitedUntil = 0

local failedServers = {}
local candidates = {}
local candidateSet = {}
local lastTeleportServer = nil
local teleportToken = 0
local pagesRead = 0

-- COLORES
local C = {
    Background = Color3.fromRGB(14, 15, 23),
    Panel = Color3.fromRGB(23, 25, 37),
    PanelLight = Color3.fromRGB(32, 34, 49),
    Purple = Color3.fromRGB(133, 91, 255),
    PurpleDark = Color3.fromRGB(94, 63, 202),
    Blue = Color3.fromRGB(75, 133, 255),
    Green = Color3.fromRGB(69, 220, 157),
    Red = Color3.fromRGB(255, 91, 115),
    Yellow = Color3.fromRGB(255, 193, 77),
    White = Color3.fromRGB(244, 245, 255),
    Muted = Color3.fromRGB(151, 155, 178),
    Border = Color3.fromRGB(51, 53, 73)
}

local function now()
    return os.clock()
end

-- LIMPIAR GUI ANTERIOR
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

-- COMPONENTES GUI
local function corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = object
    return c
end

local function stroke(object, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = object
    return s
end

local function label(parent, text, pos, size, textSize, color, font)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = pos
    t.Size = size
    t.Text = text
    t.TextColor3 = color or C.White
    t.TextSize = textSize or 13
    t.Font = font or Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.Parent = parent
    return t
end

local function button(parent, text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Position = pos
    b.Size = size
    b.BackgroundColor3 = color or C.PanelLight
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = C.White
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 9)
    return b
end

-- VENTANA PRINCIPAL
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 390)
main.Position = UDim2.new(0.5, -195, 0.5, -195)
main.BackgroundColor3 = C.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
corner(main, 15)
stroke(main, C.Border, 1)

-- BARRA SUPERIOR
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 67)
top.BackgroundColor3 = C.Panel
top.BorderSizePixel = 0
top.Parent = main

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, 0, 0, 3)
accent.BackgroundColor3 = C.Purple
accent.BorderSizePixel = 0
accent.Parent = top

local logo = Instance.new("Frame")
logo.Position = UDim2.fromOffset(15, 15)
logo.Size = UDim2.fromOffset(37, 37)
logo.BackgroundColor3 = C.PurpleDark
logo.BorderSizePixel = 0
logo.Parent = top
corner(logo, 10)

local logoText = label(
    logo, "B", UDim2.new(0, 0, 0, 0),
    UDim2.new(1, 0, 1, 0), 22, C.White,
    Enum.Font.GothamBold
)
logoText.TextXAlignment = Enum.TextXAlignment.Center

label(
    top, "BYCHINNITO",
    UDim2.fromOffset(62, 12),
    UDim2.fromOffset(220, 23),
    16, C.White, Enum.Font.GothamBold
)

label(
    top, "PRIVATE SERVER FINDER",
    UDim2.fromOffset(63, 35),
    UDim2.fromOffset(230, 17),
    10, C.Muted, Enum.Font.GothamSemibold
)

local closeButton = button(
    top, "×", UDim2.new(1, -43, 0, 15),
    UDim2.fromOffset(29, 29), C.PanelLight
)
closeButton.TextSize = 20

-- ESTADO DE CONEXION
local statusCard = Instance.new("Frame")
statusCard.Position = UDim2.fromOffset(14, 80)
statusCard.Size = UDim2.new(1, -28, 0, 67)
statusCard.BackgroundColor3 = C.Panel
statusCard.BorderSizePixel = 0
statusCard.Parent = main
corner(statusCard, 11)
stroke(statusCard, C.Border, 1)

local statusDot = Instance.new("Frame")
statusDot.Position = UDim2.fromOffset(13, 17)
statusDot.Size = UDim2.fromOffset(9, 9)
statusDot.BackgroundColor3 = C.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
corner(statusDot, 8)

local statusTitle = label(
    statusCard, "LISTO PARA BUSCAR",
    UDim2.fromOffset(30, 9),
    UDim2.new(1, -42, 0, 20),
    12, C.Green, Enum.Font.GothamBold
)

local statusDetail = label(
    statusCard, "Los servidores encontrados se guardan.",
    UDim2.fromOffset(13, 34),
    UDim2.new(1, -25, 0, 23),
    11, C.Muted, Enum.Font.Gotham
)

-- TARJETAS DE ESTADISTICAS
local function statCard(x, titleText, initialValue, valueColor)
    local card = Instance.new("Frame")
    card.Position = UDim2.fromOffset(x, 157)
    card.Size = UDim2.fromOffset(112, 58)
    card.BackgroundColor3 = C.Panel
    card.BorderSizePixel = 0
    card.Parent = main
    corner(card, 10)
    stroke(card, C.Border, 1)

    label(
        card, titleText,
        UDim2.fromOffset(10, 6),
        UDim2.new(1, -18, 0, 17),
        10, C.Muted, Enum.Font.Gotham
    )

    local value = label(
        card, initialValue,
        UDim2.fromOffset(10, 24),
        UDim2.new(1, -18, 0, 25),
        19, valueColor or C.White, Enum.Font.GothamBold
    )

    return value
end

local candidateValue = statCard(14, "SERVIDORES", "0", C.Purple)
local pageValue = statCard(139, "PAGINAS", "0/" .. MAX_PAGES, C.Blue)
local modeValue = statCard(264, "AUTO HOP", "OFF", C.Yellow)

-- PROGRESO
label(
    main, "PROGRESO DE BUSQUEDA",
    UDim2.fromOffset(16, 225),
    UDim2.fromOffset(250, 18),
    10, C.Muted, Enum.Font.GothamBold
)

local progressText = label(
    main, "Esperando...",
    UDim2.new(1, -112, 0, 225),
    UDim2.fromOffset(95, 18),
    10, C.Muted, Enum.Font.Gotham
)
progressText.TextXAlignment = Enum.TextXAlignment.Right

local progressBG = Instance.new("Frame")
progressBG.Position = UDim2.fromOffset(15, 247)
progressBG.Size = UDim2.new(1, -30, 0, 7)
progressBG.BackgroundColor3 = C.PanelLight
progressBG.BorderSizePixel = 0
progressBG.Parent = main
corner(progressBG, 5)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = C.Purple
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBG
corner(progressFill, 5)

-- BOTONES PRINCIPALES
local searchButton = button(
    main, "BUSCAR Y ENTRAR",
    UDim2.fromOffset(15, 267),
    UDim2.new(1, -30, 0, 40), C.PurpleDark
)

local refreshButton = button(
    main, "ACTUALIZAR LISTA",
    UDim2.fromOffset(15, 315),
    UDim2.new(0.49, -9, 0, 36), C.PanelLight
)

local autoButton = button(
    main, "AUTO HOP: OFF",
    UDim2.new(0.51, 0, 0, 315),
    UDim2.new(0.49, -6, 0, 36), C.PanelLight
)

label(
    main, "ByChinnito  •  v3.0",
    UDim2.fromOffset(15, 357),
    UDim2.new(1, -30, 0, 20),
    10, C.Muted, Enum.Font.Gotham
)

-- ACTUALIZAR GUI
local function updateStats()
    if closed then return end

    candidateValue.Text = tostring(#candidates)
    pageValue.Text = tostring(pagesRead) .. "/" .. MAX_PAGES
    modeValue.Text = autoHop and "ON" or "OFF"
    modeValue.TextColor3 = autoHop and C.Green or C.Yellow
end

local function setStatus(titleText, detailText, color)
    if closed then return end

    statusTitle.Text = titleText
    statusTitle.TextColor3 = color or C.Green
    statusDot.BackgroundColor3 = color or C.Green
    statusDetail.Text = detailText
    updateStats()
end

local function setProgress(amount, text)
    if closed then return end

    amount = math.clamp(amount, 0, 1)
    progressFill:TweenSize(
        UDim2.new(amount, 0, 1, 0),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quad,
        0.15,
        true
    )

    progressText.Text = text or (math.floor(amount * 100) .. "%")
end

-- ARRASTRAR VENTANA
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

-- HTTP
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

local function getJSON(url)
    local requestFunction = getRequestFunction()

    if not requestFunction then
        return nil, "No hay funcion HTTP compatible"
    end

    if now() < rateLimitedUntil then
        return nil, "En pausa por HTTP 429"
    end

    for attempt = 1, MAX_RETRIES do
        if closed then
            return nil, "Cerrado"
        end

        local ok, response = pcall(function()
            return requestFunction({
                Url = url,
                Method = "GET",
                Headers = {
                    ["Accept"] = "application/json"
                }
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

                return nil, "JSON inesperado"
            elseif code == 429 then
                local waitSeconds = math.min(
                    10 * (2 ^ (attempt - 1)), 60
                )

                rateLimitedUntil = now() + math.max(
                    waitSeconds, RATE_LIMIT_COOLDOWN
                )

                setStatus(
                    "PAUSA POR LIMITE HTTP",
                    "Esperando antes de volver a consultar.",
                    C.Yellow
                )

                setProgress(0, "EN PAUSA")
                task.wait(math.max(0, rateLimitedUntil - now()))
            elseif code and code >= 500 then
                task.wait(3 * attempt)
            else
                return nil, "HTTP " .. tostring(code)
            end
        else
            task.wait(2 * attempt)
        end
    end

    return nil, "Reintentos agotados"
end

-- CANDIDATOS
local function addCandidate(server)
    if type(server) ~= "table" or type(server.id) ~= "string" then
        return
    end

    local id = server.id
    local playing = tonumber(server.playing)
    local maxPlayers = tonumber(server.maxPlayers)

    if id == game.JobId
        or candidateSet[id]
        or failedServers[id] then
        return
    end

    if not playing or not maxPlayers or playing >= maxPlayers then
        return
    end

    candidateSet[id] = true

    table.insert(candidates, {
        id = id,
        playing = playing,
        maxPlayers = maxPlayers
    })
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
end

local function searchMore()
    if searching or closed then
        return false
    end

    if now() < rateLimitedUntil then
        setStatus(
            "BUSQUEDA EN PAUSA",
            "Roblox limitó las consultas. Espera un poco.",
            C.Yellow
        )
        return false
    end

    searching = true
    pagesRead = 0

    local cursor = nil
    local ok, err = pcall(function()
        for page = 1, MAX_PAGES do
            if closed or #candidates >= TARGET_CANDIDATES then
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
                "Pagina " .. page .. " de " .. MAX_PAGES,
                C.Blue
            )

            setProgress((page - 1) / MAX_PAGES, "PAGINA " .. page)

            local data, requestError = getJSON(url)

            if not data then
                setStatus(
                    "BUSQUEDA INTERRUMPIDA",
                    tostring(requestError) .. " | Guardados: " .. #candidates,
                    C.Yellow
                )
                break
            end

            pagesRead = pagesRead + 1

            for _, server in ipairs(data.data) do
                addCandidate(server)
            end

            updateStats()
            setProgress(page / MAX_PAGES, "PAGINA " .. page)

            cursor = data.nextPageCursor

            if not cursor or cursor == "" then
                break
            end

            task.wait(PAGE_DELAY)
        end
    end)

    searching = false
    shuffle(candidates)
    updateStats()

    if not ok then
        setStatus("ERROR DE BUSQUEDA", tostring(err), C.Red)
        return false
    end

    setProgress(1, "COMPLETADO")

    if #candidates > 0 then
        setStatus(
            "SERVIDORES ENCONTRADOS",
            #candidates .. " candidatos guardados para probar.",
            C.Green
        )
        return true
    end

    setStatus(
        "SIN RESULTADOS",
        "Espera un poco y vuelve a intentarlo.",
        C.Yellow
    )

    return false
end

local function removeCandidate(id)
    candidateSet[id] = nil

    for i = #candidates, 1, -1 do
        if candidates[i].id == id then
            table.remove(candidates, i)
        end
    end

    updateStats()
end

-- TELETRANSPORTE
local function nextTeleport()
    if closed or teleporting then
        return
    end

    while #candidates > 0 do
        local server = table.remove(candidates, 1)
        candidateSet[server.id] = nil
        updateStats()

        if not failedServers[server.id] and server.id ~= game.JobId then
            teleporting = true
            lastTeleportServer = server.id
            teleportToken = teleportToken + 1

            local myToken = teleportToken

            setStatus(
                "CONECTANDO",
                "Probando servidor... quedan " .. #candidates,
                C.Blue
            )

            setProgress(0.9, "TELEPORT")

            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    PlaceId,
                    server.id,
                    Player
                )
            end)

            if not ok then
                failedServers[server.id] = true
                teleporting = false

                setStatus(
                    "TELEPORT FALLIDO",
                    tostring(err) .. " | Probando otro.",
                    C.Red
                )
            else
                task.delay(TELEPORT_TIMEOUT, function()
                    if closed or not teleporting
                        or teleportToken ~= myToken then
                        return
                    end

                    setStatus(
                        "TELEPORT PENDIENTE",
                        "Roblox aún no confirma el resultado.",
                        C.Yellow
                    )
                end)

                return
            end
        end
    end

    teleporting = false

    setStatus(
        "LISTA AGOTADA",
        "Pulsa actualizar para buscar más servidores.",
        C.Yellow
    )

    setProgress(0, "ESPERANDO")
end

TeleportService.TeleportInitFailed:Connect(function(
    player, result, message, placeId
)
    if player ~= Player or placeId ~= PlaceId or closed then
        return
    end

    if lastTeleportServer then
        failedServers[lastTeleportServer] = true
        removeCandidate(lastTeleportServer)
    end

    teleporting = false

    setStatus(
        "TELEPORT RECHAZADO",
        tostring(result) .. " | Probando otro candidato.",
        C.Red
    )

    task.delay(1, function()
        if not closed and not searching and not teleporting then
            nextTeleport()
        end
    end)
end)

-- ACCIONES
local function runFinder(forceSearch)
    if closed or searching or teleporting then
        return
    end

    if #candidates > 0 and not forceSearch then
        nextTeleport()
        return
    end

    task.spawn(function()
        local found = searchMore()

        if not closed and not teleporting then
            if found then
                nextTeleport()
            end
        end
    end)
end

searchButton.MouseButton1Click:Connect(function()
    runFinder(false)
end)

refreshButton.MouseButton1Click:Connect(function()
    runFinder(true)
end)

autoButton.MouseButton1Click:Connect(function()
    autoHop = not autoHop

    autoButton.Text = autoHop and "AUTO HOP: ON" or "AUTO HOP: OFF"
    autoButton.BackgroundColor3 = autoHop and C.PurpleDark or C.PanelLight

    updateStats()

    if autoHop then
        task.spawn(function()
            while autoHop and not closed do
                if not searching and not teleporting then
                    if #candidates > 0 then
                        nextTeleport()
                    elseif now() >= rateLimitedUntil then
                        runFinder(false)
                    else
                        setStatus(
                            "AUTO HOP EN PAUSA",
                            "Esperando a que termine el límite HTTP.",
                            C.Yellow
                        )
                    end
                end

                task.wait(AUTO_HOP_DELAY)
            end
        end)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    closed = true
    autoHop = false
    gui:Destroy()
end)

updateStats()
setProgress(0, "ESPERANDO")

print("[ByChinnito] GUI v3 iniciada")
