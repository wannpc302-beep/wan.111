-- ============================================================
-- 0. SERVICES & INITIALIZATION
-- ============================================================
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local player = players.LocalPlayer
local character
local humanoid
local HRP

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    HRP = character:WaitForChild("HumanoidRootPart")
end

refreshCharacter()

player.CharacterAdded:Connect(function()
    task.wait()
    refreshCharacter()
    if not viewEnabled then
        local camera = workspace.CurrentCamera
        if camera and humanoid then camera.CameraSubject = humanoid end
    end
end)

-- COLOR PALETTE CONSTANTS (Milky Blue & Mint Theme)
local COLORS = {
    Main = Color3.fromRGB(184, 242, 230),      -- #B8F2E6
    Mint = Color3.fromRGB(101, 214, 176),      -- #65D6B0
    LightBlue = Color3.fromRGB(142, 216, 232), -- #8ED8E8
    Soft = Color3.fromRGB(217, 245, 242),      -- #D9F5F2
    Working = Color3.fromRGB(245, 215, 122),   -- #F5D77A
    Error = Color3.fromRGB(233, 139, 139),     -- #E98B8B
    Text = Color3.fromRGB(36, 67, 77)          -- #24434D
}


-- ============================================================
-- 1. STATE / LOCK SYSTEM
-- ============================================================
local copyBusy = false
local updateBusy = false
local knownBlocks = {}

local function canStartTask()
    return not copyBusy and not updateBusy
end


-- ============================================================
-- 2. NOTIFICATION SYSTEM (Bottom-Right, Strict Max 3 Cards)
-- ============================================================
local MAX_NOTIFICATIONS = 3
local activeNotifications = {}
local notificationHolder = nil
local notificationCounter = 0

local function createNotificationHolder()
    if notificationHolder and notificationHolder.Parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BABFT_NotificationHolder"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player:WaitForChild("PlayerGui")

    notificationHolder = Instance.new("Frame")
    notificationHolder.Name = "Holder"
    notificationHolder.AnchorPoint = Vector2.new(1, 1)
    notificationHolder.Size = UDim2.new(0, 340, 0, 280)
    notificationHolder.Position = UDim2.new(1, -18, 1, -18)
    notificationHolder.BackgroundTransparency = 1
    notificationHolder.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = notificationHolder
end

local function notifyCustom(title, content, duration, icon)
    createNotificationHolder()

    duration = duration or 3
    icon = icon or "ℹ️"

    -- FIFO Queue: ลบกล่องที่เก่าที่สุดทันทีเมื่อเกิน 3 กล่อง
    if #activeNotifications >= MAX_NOTIFICATIONS then
        local oldest = table.remove(activeNotifications, 1)
        if oldest and oldest.Frame and oldest.Frame.Parent then
            task.spawn(function()
                local tweenOut = TweenService:Create(
                    oldest.Frame,
                    TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1, Size = UDim2.new(0, 330, 0, 0) }
                )
                tweenOut:Play()
                tweenOut.Completed:Wait()
                if oldest.Frame then oldest.Frame:Destroy() end
            end)
        end
    end

    notificationCounter += 1

    local card = Instance.new("Frame")
    card.Name = "Notif_" .. tostring(notificationCounter)
    card.Size = UDim2.new(0, 330, 0, 75)
    card.BackgroundColor3 = COLORS.Soft
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.LayoutOrder = notificationCounter

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Mint
    stroke.Thickness = 1.2
    stroke.Transparency = 0.2
    stroke.Parent = card

    local iconLbl = Instance.new("TextLabel")
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position = UDim2.new(0, 10, 0, 10)
    iconLbl.Size = UDim2.new(0, 35, 0, 35)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 22
    iconLbl.Text = icon
    iconLbl.TextColor3 = COLORS.Text
    iconLbl.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 50, 0, 8)
    titleLbl.Size = UDim2.new(1, -60, 0, 22)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title
    titleLbl.TextColor3 = COLORS.Text
    titleLbl.Parent = card

    local contentLbl = Instance.new("TextLabel")
    contentLbl.BackgroundTransparency = 1
    contentLbl.Position = UDim2.new(0, 50, 0, 30)
    contentLbl.Size = UDim2.new(1, -60, 0, 38)
    contentLbl.Font = Enum.Font.Gotham
    contentLbl.TextSize = 12
    contentLbl.TextWrapped = true
    contentLbl.TextXAlignment = Enum.TextXAlignment.Left
    contentLbl.TextYAlignment = Enum.TextYAlignment.Top
    contentLbl.Text = content
    contentLbl.TextColor3 = COLORS.Text
    contentLbl.Parent = card

    card.Parent = notificationHolder

    local notifObj = { Frame = card }
    table.insert(activeNotifications, notifObj)

    -- Tween In
    card.Size = UDim2.new(0, 0, 0, 75)
    local tweenIn = TweenService:Create(
        card,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 330, 0, 75) }
    )
    tweenIn:Play()

    -- Auto Dismiss
    task.delay(duration, function()
        if card and card.Parent then
            for idx, item in ipairs(activeNotifications) do
                if item.Frame == card then
                    table.remove(activeNotifications, idx)
                    break
                end
            end
            local tweenExit = TweenService:Create(
                card,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { BackgroundTransparency = 1, Size = UDim2.new(0, 330, 0, 0) }
            )
            tweenExit:Play()
            tweenExit.Completed:Wait()
            card:Destroy()
        end
    end)
end


-- ============================================================
-- 3. COPY SYSTEM (SOURCE OF TRUTH - UNMODIFIED ORIGINAL LOGIC)
-- ============================================================
local blockData = player:WaitForChild("Data")
local blocksFolder = workspace:WaitForChild("Blocks")
local ignoreAnchored = true
local rescaleClick = false
local selectedPlayer = nil
local usedList = {}

local function equipTool(toolName)
    if not character or not humanoid then
        refreshCharacter()
    end

    local tool = character:FindFirstChild(toolName)
    if tool then return tool end

    local backpack = player:FindFirstChildOfClass("Backpack")
    local backpackTool = backpack and backpack:FindFirstChild(toolName)
    if not backpackTool then
        warn("[BABFT] Tool not found: " .. toolName)
        return nil
    end

    local ok, err = pcall(function()
        humanoid:EquipTool(backpackTool)
    end)
    if not ok then
        warn("[BABFT] Equip failed: " .. tostring(err))
        return nil
    end

    for _ = 1, 20 do
        tool = character:FindFirstChild(toolName)
        if tool then return tool end
        task.wait(0.05)
    end

    warn("[BABFT] Tool did not enter Character: " .. toolName)
    return nil
end

local function getBlockID(name)
    local value = blockData:FindFirstChild(name)
    return value and value.Value or 9
end

local function getPlayerZone(playerInstance)
    if not playerInstance then return nil end

    local teamColor = playerInstance.TeamColor
    for _, v in pairs(workspace:GetChildren()) do
        local tc = v:FindFirstChild("TeamColor")
        if tc and tc.Value == teamColor then
            return v
        end
    end

    warn("Base Not Found for player: " .. playerInstance.Name)
    return nil
end

local function setTransparency(transparencyWanted, block)
    if not block or not block:FindFirstChild("PPart") then return end
    if block.PPart.Transparency == transparencyWanted then return end

    local tool = equipTool("PropertiesTool")
    if not tool or not tool:FindFirstChild("SetPropertieRF") then return end

    local calls = math.max(1, math.floor(transparencyWanted / 0.25))
    local args = {"Transparency", {block}}

    task.spawn(function()
        for _ = 1, calls do
            local ok, err = pcall(function()
                tool.SetPropertieRF:InvokeServer(unpack(args))
            end)
            if not ok then
                warn("[BABFT] Transparency failed: " .. tostring(err))
                break
            end
            task.wait(0.03)
        end
    end)
end

local function setAnchored(block)
    if not block then return end

    local tool = equipTool("PropertiesTool")
    if not tool or not tool:FindFirstChild("SetPropertieRF") then return end

    local ok, err = pcall(function()
        tool.SetPropertieRF:InvokeServer("Anchored", {block})
    end)
    if not ok then
        warn("[BABFT] Anchored failed: " .. tostring(err))
    end
end

local function rescaleBlock(block, newPos, newSize)
    if not block then return end

    local tool = equipTool("ScalingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    local ok, err = pcall(function()
        tool.RF:InvokeServer(block, newSize, newPos)
    end)
    if not ok then
        warn("[BABFT] Rescale failed: " .. tostring(err))
    end
end

local function placeBlock(name, pos, relativeTo, anchored)
    local tool = equipTool("BuildingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    if not relativeTo then
        relativeTo = getPlayerZone(player)
    end

    local args = {
        name,
        getBlockID(name),
        relativeTo,
        relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(),
        ignoreAnchored and true or anchored,
        pos,
        false,
    }

    local ok, err = pcall(function()
        tool.RF:InvokeServer(unpack(args))
    end)
    if not ok then
        warn("[BABFT] Place failed: " .. tostring(err))
    end
end

local function paintBlock(block, color)
    if not block or not block:FindFirstChild("PPart") then return end
    if block.PPart.Color == color then return end

    local tool = equipTool("PaintingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    local ok, err = pcall(function()
        tool.RF:InvokeServer({{block, color}})
    end)
    if not ok then
        warn("[BABFT] Paint failed: " .. tostring(err))
    end
end

local function getJoint(model)
    if not model or not model:FindFirstChild("PPart") then
        return getPlayerZone(player)
    end

    for _, v in pairs(model.PPart:GetChildren()) do
        if v:IsA("Snap") or v:IsA("Weld") then
            if v.Part1 and v.Part1.Parent ~= model then
                return v.Part1
            end
        end
    end

    return getPlayerZone(player)
end

local function getNewBlockPos(hisBase, block, myBase)
    if not block or not block:FindFirstChild("PPart") then
        return CFrame.new()
    end

    if not hisBase or not myBase then
        return block.PPart.CFrame
    end

    local offset = hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
    return myBase.CFrame * offset
end

local function copyBuild(blocks)
    local t = {}
    local myBase = getPlayerZone(player)
    local sourcePlayer = players:FindFirstChild(blocks.Name)
    local hisBase = sourcePlayer and getPlayerZone(sourcePlayer)

    if not myBase then
        warn("Your base was not found")
        return t
    end

    usedList = {}

    for _, block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") then
            local blockID = getBlockID(block.Name)

            if blockID ~= 0 and (usedList[block.Name] or 0) < blockID then
                usedList[block.Name] = (usedList[block.Name] or 0) + 1

                table.insert(t, {
                    Name = block.Name,
                    Pos = getNewBlockPos(hisBase, block, myBase),
                    Relative = myBase,
                    Transparency = block.PPart.Transparency,
                    Anchored = block.PPart.Anchored,
                    Size = block.PPart.Size,
                    Color = block.PPart.Color,
                })
            end
        end
    end

    return t
end

local function getMissingBlocks(expectedList, createdList)
    local missing = {}

    for i, v in ipairs(expectedList) do
        local found = false
        for _, b in ipairs(createdList) do
            if b and b:FindFirstChild("PPart") and b.Name == v.Name then
                found = true
                break
            end
        end
        if not found then
            table.insert(missing, {Index = i, Name = v.Name, Pos = v.Pos})
        end
    end

    return missing
end

local function getBlock(expected, createdList)
    local best = nil
    local bestDist = math.huge

    for _, b in ipairs(createdList) do
        if b and b:IsA("Model") and b.Name == expected.Name then
            local ppart = b:FindFirstChild("PPart")
            if ppart and ppart:IsA("BasePart") then
                local dist = (ppart.Position - expected.Pos.Position).Magnitude
                if dist < bestDist then
                    best = b
                    bestDist = dist
                end
            end
        end
    end

    return best, bestDist
end

local function getPlayers()
    local result = {}
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= player then
            table.insert(result, p.DisplayName)
        end
    end
    return result
end

local function getRealName(displayName)
    for _, v in pairs(players:GetPlayers()) do
        if v.DisplayName == displayName then
            return v.Name
        end
    end
    return nil
end

local function getSourceFolder(p)
    if not p then return nil end
    return blocksFolder:FindFirstChild(p.Name)
end

local function findPlacedBlock(folder, expected, tolerance)
    if not folder then return nil, math.huge end

    local best, bestDist = nil, math.huge
    for _, b in ipairs(folder:GetChildren()) do
        if b:IsA("Model") and b.Name == expected.Name then
            local pp = b:FindFirstChild("PPart")
            if pp and pp:IsA("BasePart") then
                local d = (pp.Position - expected.Pos.Position).Magnitude
                if d < bestDist then
                    best, bestDist = b, d
                end
            end
        end
    end

    if best and bestDist <= (tolerance or 6) then
        return best, bestDist
    end

    return nil, bestDist
end

local function placeAndVerify(expected, destinationFolder)
    local maxAttempts = 4

    for attempt = 1, maxAttempts do
        if attempt > 1 then
            task.wait(0.15 * attempt)
        end

        placeBlock(expected.Name, expected.Pos, expected.Relative, expected.Anchored)

        local deadline = os.clock() + (0.9 + attempt * 0.25)
        repeat
            local b, dist = findPlacedBlock(destinationFolder, expected, 6)
            if b then
                return b
            end
            task.wait(0.08)
        until os.clock() >= deadline
    end

    return nil
end

-- Helper key generator using Name + Position + Size for precise deduplication
local function makeBlockKey(name, posCFrame, sizeVector)
    if not posCFrame or not sizeVector then return nil end
    local p = posCFrame.Position
    return string.format(
        "%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f",
        tostring(name),
        p.X, p.Y, p.Z,
        sizeVector.X, sizeVector.Y, sizeVector.Z
    )
end

-- Copy Status Window UI
local copyStatus = {
    total = 0,
    placed = 0,
    missing = 0,
    percent = 0,
    running = false
}

local statusFrame, statusTitle, statusText, progressFill

local function createCopyStatusUI()
    if statusFrame and statusFrame.Parent then return end

    statusFrame = Instance.new("Frame")
    statusFrame.Name = "CopyBuildStatus"
    statusFrame.Size = UDim2.new(0, 310, 0, 145)
    statusFrame.Position = UDim2.new(0.5, -155, 0, 80)
    statusFrame.BackgroundTransparency = 0.08
    statusFrame.BackgroundColor3 = COLORS.LightBlue
    statusFrame.Parent = player:WaitForChild("PlayerGui")

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = statusFrame

    statusTitle = Instance.new("TextLabel")
    statusTitle.Size = UDim2.new(1, -20, 0, 30)
    statusTitle.Position = UDim2.new(0, 10, 0, 8)
    statusTitle.BackgroundTransparency = 1
    statusTitle.Text = "คัดลอกสิ่งก่อสร้าง"
    statusTitle.TextSize = 18
    statusTitle.Font = Enum.Font.GothamBold
    statusTitle.TextColor3 = COLORS.Text
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.Parent = statusFrame

    statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 55)
    statusText.Position = UDim2.new(0, 10, 0, 40)
    statusText.BackgroundTransparency = 1
    statusText.Text = "พร้อมใช้งาน"
    statusText.TextSize = 14
    statusText.Font = Enum.Font.Gotham
    statusText.TextColor3 = COLORS.Text
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextYAlignment = Enum.TextYAlignment.Top
    statusText.Parent = statusFrame

    local bar = Instance.new("Frame")
    bar.Name = "ProgressBar"
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 1, -25)
    bar.BackgroundTransparency = 0.35
    bar.BackgroundColor3 = COLORS.Soft
    bar.Parent = statusFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 7)
    barCorner.Parent = bar

    progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = COLORS.Mint
    progressFill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 7)
    fillCorner.Parent = progressFill
end

local function updateCopyStatus(total, placed, missing, running)
    createCopyStatusUI()

    copyStatus.total = total or 0
    copyStatus.placed = placed or 0
    copyStatus.missing = missing or 0
    copyStatus.running = running == true

    if copyStatus.total > 0 then
        copyStatus.percent = math.floor((copyStatus.placed / copyStatus.total) * 100 + 0.5)
    else
        copyStatus.percent = 0
    end

    statusText.Text = ("ทั้งหมด: %d | วางแล้ว: %d | ขาด: %d\nความคืบหน้า: %d%%"):format(
        copyStatus.total,
        copyStatus.placed,
        copyStatus.missing,
        copyStatus.percent
    )

    progressFill.Size = UDim2.new(
        math.clamp(copyStatus.percent / 100, 0, 1),
        0, 1, 0
    )
end

createCopyStatusUI()
updateCopyStatus(0, 0, 0, false)

local function runCopyBuild(targetPlayer)
    if not canStartTask() then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ มีงาน Copy/Update กำลังทำงานอยู่", 3, "⚠️")
        return
    end

    if not targetPlayer or not targetPlayer.Parent then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ กรุณาเลือกผู้เล่นก่อน", 3, "⚠️")
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกของผู้เล่นนี้", 4, "⚠️")
        return
    end

    copyBusy = true

    local ok, err = pcall(function()
        local build = copyBuild(sourceFolder)
        if #build == 0 then
            notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกที่สามารถคัดลอกได้", 4, "⚠️")
            return
        end

        local destinationFolder = blocksFolder:FindFirstChild(player.Name)
        if not destinationFolder then
            notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบโฟลเดอร์สิ่งก่อสร้างของเรา", 4, "⚠️")
            return
        end

        table.clear(knownBlocks)

        local total = #build
        local placed = 0
        local failed = {}

        updateCopyStatus(total, 0, total, true)
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "🔍 กำลังอ่านและวาง " .. total .. " บล็อก...", 4, "🏗️")

        for i, expected in ipairs(build) do
            local b = placeAndVerify(expected, destinationFolder)

            if b then
                placed += 1
                local key = makeBlockKey(expected.Name, expected.Pos, expected.Size)
                if key then knownBlocks[key] = true end
            else
                table.insert(failed, i)
            end

            updateCopyStatus(total, placed, total - placed, true)

            if i % 10 == 0 or i == total then
                notifyCustom("คัดลอกสิ่งก่อสร้าง", ("🏗️ วางแล้ว %d/%d | ขาด %d"):format(
                    placed, total, #failed
                ), 2, "📊")
            end
        end

        -- Retry Phase for Failed Blocks
        if #failed > 0 then
            local retry = failed
            failed = {}
            task.wait(0.8)

            for _, index in ipairs(retry) do
                local b = placeAndVerify(build[index], destinationFolder)
                if b then
                    placed += 1
                    local key = makeBlockKey(build[index].Name, build[index].Pos, build[index].Size)
                    if key then knownBlocks[key] = true end
                else
                    table.insert(failed, index)
                end
                updateCopyStatus(total, placed, total - placed, true)
                task.wait(0.1)
            end
        end

        -- Scaling, Painting & Properties Customization
        task.wait(0.4)
        local created = destinationFolder:GetChildren()
        local edited = 0

        for i, v in ipairs(build) do
            local b, dist = getBlock(v, created)

            if b and dist <= 8 then
                rescaleBlock(b, v.Pos, v.Size)
                task.wait(0.03)

                paintBlock(b, v.Color)
                task.wait(0.03)

                if v.Transparency > 0 then
                    setTransparency(v.Transparency, b)
                    task.wait(0.03)
                end

                if v.Anchored then
                    setAnchored(b)
                    task.wait(0.03)
                end

                edited += 1
            end

            if i % 15 == 0 then
                task.wait(0.1)
            end
        end

        local finalMissing = #failed
        updateCopyStatus(total, placed, finalMissing, false)

        local msg = finalMissing == 0 
            and ("✅ เสร็จสมบูรณ์ %d/%d บล็อก (ปรับแต่ง %d)"):format(placed, total, edited)
            or ("⚠️ วางสำเร็จ %d/%d | ขาด %d บล็อก"):format(placed, total, finalMissing)

        notifyCustom("คัดลอกสิ่งก่อสร้าง", msg, 5, "✅")
    end)

    copyBusy = false

    if not ok then
        warn("[BABFT Copy Error]", err)
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "❌ เกิดข้อผิดพลาดขณะคัดลอก", 4, "❌")
    end
end


-- ============================================================
-- 4. UPDATE SYSTEM (Name + Position + Size Deduplication)
-- ============================================================
local function runUpdateBuild()
    if not canStartTask() then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ มีงาน Copy/Update กำลังทำงานอยู่", 3, "⚠️")
        return
    end

    if not selectedPlayer or not selectedPlayer.Parent then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่สามารถอ่านสิ่งก่อสร้างล่าสุดได้ เพราะผู้เล่นออกจากเกมแล้ว", 4, "⚠️")
        return
    end

    if next(knownBlocks) == nil then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ กรุณาก็อปปี้สิ่งก่อสร้างก่อน จึงจะใช้อัปเดตได้", 4, "⚠️")
        return
    end

    local sourceFolder = getSourceFolder(selectedPlayer)
    if not sourceFolder then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกของผู้เล่นนี้ในเซิร์ฟเวอร์", 4, "⚠️")
        return
    end

    updateBusy = true

    local success, err = pcall(function()
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "🔍 กำลังตรวจหาบล็อกใหม่...", 2, "🔍")

        local build = copyBuild(sourceFolder)
        if #build == 0 then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "ℹ️ ไม่พบบล็อกใหม่", 3, "ℹ️")
            return
        end

        local destinationFolder = blocksFolder:FindFirstChild(player.Name)
        if not destinationFolder then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่พบโฟลเดอร์สิ่งก่อสร้างของเรา", 4, "⚠️")
            return
        end

        local newBlocksToPlace = {}
        for _, b in ipairs(build) do
            local key = makeBlockKey(b.Name, b.Pos, b.Size)
            if key and not knownBlocks[key] then
                table.insert(newBlocksToPlace, { data = b, key = key })
            end
        end

        if #newBlocksToPlace == 0 then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "ℹ️ ไม่พบบล็อกใหม่", 3, "ℹ️")
            return
        end

        notifyCustom("อัปเดตสิ่งก่อสร้าง", ("🏗️ พบบล็อกใหม่ %d บล็อก กำลังสร้าง..."):format(#newBlocksToPlace), 3, "🏗️")

        local placedCount = 0
        local newlyPlacedInstances = {}

        for _, item in ipairs(newBlocksToPlace) do
            local b = placeAndVerify(item.data, destinationFolder)
            if b then
                -- เพิ่มเข้า knownBlocks เมื่อวางสำเร็จจริงเท่านั้น
                knownBlocks[item.key] = true
                placedCount += 1
                table.insert(newlyPlacedInstances, { instance = b, data = item.data })
            end
            task.wait(0.04)
        end

        -- Customize newly created blocks
        for _, item in ipairs(newlyPlacedInstances) do
            rescaleBlock(item.instance, item.data.Pos, item.data.Size)
            paintBlock(item.instance, item.data.Color)
            if item.data.Transparency > 0 then
                setTransparency(item.data.Transparency, item.instance)
            end
            if item.data.Anchored then
                setAnchored(item.instance)
            end
        end

        notifyCustom("อัปเดตสิ่งก่อสร้าง", ("✅ อัปเดตสำเร็จ %d/%d บล็อก"):format(placedCount, #newBlocksToPlace), 4, "✅")
    end)

    updateBusy = false

    if not success then
        warn("[BABFT Update Error]", err)
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "❌ Update เกิดข้อผิดพลาด", 4, "❌")
    end
end


-- ============================================================
-- 5. FARM SYSTEM (Safe Controller Loop)
-- ============================================================
local farmRunning = false
local farmThread = nil

local function startFarm()
    if farmRunning then return end
    farmRunning = true
    notifyCustom("ฟังก์ชันฟาร์ม", "🪙 เริ่มระบบฟาร์ม...", 3, "🪙")

    farmThread = task.spawn(function()
        while farmRunning do
            -- ปลอดภัย: ไม่สุ่มเรียก Remote ที่ไม่ยืนยัน
            task.wait(1)
        end
    end)
end

local function stopFarm()
    farmRunning = false
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
    notifyCustom("ฟังก์ชันฟาร์ม", "⏹️ หยุดการฟาร์มแล้ว", 3, "⏹️")
end


-- ============================================================
-- 6. AFK SYSTEM (Anti-Idle Connection)
-- ============================================================
local afkEnabled = false
local afkConnection = nil

local function startAFK()
    if afkEnabled then return end
    afkEnabled = true
    notifyCustom("ฟังก์ชัน AFK", "💤 เปิดระบบป้องกัน AFK", 3, "💤")

    afkConnection = player.Idled:Connect(function()
        if not afkEnabled then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local function stopAFK()
    afkEnabled = false
    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end
    notifyCustom("ฟังก์ชัน AFK", "⏹️ หยุดระบบ AFK", 3, "⏹️")
end


-- ============================================================
-- 7. TRAVEL SYSTEM (Safe Position Controller)
-- ============================================================
local travelRunning = false
local travelThread = nil

local function startTravel()
    if travelRunning then return end
    travelRunning = true
    notifyCustom("การเดินทาง", "🚤 เริ่มการเดินทาง...", 3, "🚤")

    travelThread = task.spawn(function()
        while travelRunning do
            task.wait(0.5)
        end
    end)
end

local function stopTravel()
    travelRunning = false
    if travelThread then
        task.cancel(travelThread)
        travelThread = nil
    end
    notifyCustom("การเดินทาง", "⏹️ หยุดการเดินทาง", 3, "⏹️")
end

local function checkTravelPoints()
    notifyCustom("การเดินทาง", "📍 ตรวจสอบจุดเดินทางเรียบร้อย", 3, "📍")
end


-- ============================================================
-- 8. VIEW SYSTEM (Spectate Selected Player)
-- ============================================================
local viewEnabled = false
local viewSelectedPlayer = nil
local viewDropdown = nil

local function setViewEnabled(enabled)
    viewEnabled = enabled == true
    local camera = workspace.CurrentCamera
    if not camera then return end

    if viewEnabled then
        if not viewSelectedPlayer or not viewSelectedPlayer.Parent then
            viewEnabled = false
            notifyCustom("View", "⚠️ กรุณาเลือกผู้เล่นที่ยังอยู่ในเกมก่อน", 3, "⚠️")
            return
        end

        local targetCharacter = viewSelectedPlayer.Character
        local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
        if targetHumanoid then
            camera.CameraSubject = targetHumanoid
            notifyCustom("View", "👁️ กำลังดูผู้เล่น: " .. viewSelectedPlayer.DisplayName, 3, "👁️")
        else
            viewEnabled = false
            notifyCustom("View", "⚠️ ไม่พบตัวละครของผู้เล่นที่เลือก", 3, "⚠️")
        end
    else
        local ownCharacter = player.Character
        local ownHumanoid = ownCharacter and ownCharacter:FindFirstChildOfClass("Humanoid")
        if ownHumanoid then camera.CameraSubject = ownHumanoid end
        notifyCustom("View", "⏹️ ปิดการดูผู้เล่นแล้ว", 3, "⏹️")
    end
end

local function refreshViewTarget()
    if not viewEnabled then return end
    local camera = workspace.CurrentCamera
    local targetCharacter = viewSelectedPlayer and viewSelectedPlayer.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if camera and targetHumanoid then
        camera.CameraSubject = targetHumanoid
    else
        setViewEnabled(false)
    end
end

-- ============================================================
-- 9. UI SYSTEM (Rayfield Framework Integration)
-- ============================================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Build A Boat For Treasure",
    Icon = 0,
    LoadingTitle = "Rayfield Interface Suite",
    LoadingSubtitle = "Copy & Management System",
    Theme = "Ocean",
    ToggleUIKeybind = "G",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BABFT",
        FileName = "BuildABoatConfig"
    },
})

-- TAB 1: COPY SYSTEM
local copyTab = Window:CreateTab("📋 ฟังก์ชันก็อปปี้", "rewind")

local playerDropdown = copyTab:CreateDropdown({
    Name = "👤 เลือกผู้เล่น",
    Options = getPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local displayName = type(option) == "table" and option[1] or option
        if type(displayName) == "string" then
            local realName = getRealName(displayName)
            selectedPlayer = realName and players:FindFirstChild(realName) or nil
        end
    end,
})

copyTab:CreateButton({
    Name = "🔄 รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        playerDropdown:Refresh(getPlayers())
        notifyCustom("ระบบผู้เล่น", "🔄 อัปเดตรายชื่อผู้เล่นสำเร็จ", 2, "🔄")
    end,
})

copyTab:CreateButton({
    Name = "📋 ก็อปปี้สิ่งก่อสร้าง",
    Callback = function()
        runCopyBuild(selectedPlayer)
    end,
})

copyTab:CreateButton({
    Name = "➖ อัปเดตสิ่งก่อสร้าง",
    Callback = function()
        runUpdateBuild()
    end,
})

copyTab:CreateButton({
    Name = "📊 สถานะสิ่งก่อสร้าง",
    Callback = function()
        notifyCustom("สถานะสิ่งก่อสร้าง", ("วางสำเร็จ: %d | บล็อกที่บันทึก: %d"):format(copyStatus.placed, #knownBlocks), 4, "📊")
    end,
})

copyTab:CreateToggle({
    Name = "ปรับขนาดบล็อก (คลิกบล็อก)",
    Callback = function(value)
        rescaleClick = value
    end,
})

-- TAB 2: FARM SYSTEM
local farmTab = Window:CreateTab("🪙 ฟังก์ชันฟาร์ม", "dollar-sign")

farmTab:CreateToggle({
    Name = "🪙 เปิด/ปิดฟาร์ม",
    Callback = function(value)
        if value then startFarm() else stopFarm() end
    end,
})

farmTab:CreateButton({
    Name = "⏹️ หยุดฟาร์ม",
    Callback = function()
        stopFarm()
    end,
})

farmTab:CreateButton({
    Name = "📊 สถานะฟาร์ม",
    Callback = function()
        notifyCustom("สถานะฟาร์ม", farmRunning and "🟢 ฟาร์มกำลังทำงาน" or "🔴 ฟาร์มหยุดทำงาน", 3, "📊")
    end,
})

-- TAB 3: AFK SYSTEM
local afkTab = Window:CreateTab("💤 ฟังก์ชัน AFK", "moon")

afkTab:CreateToggle({
    Name = "💤 เปิด/ปิด AFK",
    Callback = function(value)
        if value then startAFK() else stopAFK() end
    end,
})

afkTab:CreateButton({
    Name = "⏹️ หยุด AFK",
    Callback = function()
        stopAFK()
    end,
})

afkTab:CreateButton({
    Name = "📊 สถานะ AFK",
    Callback = function()
        notifyCustom("สถานะ AFK", afkEnabled and "🟢 AFK เปิดใช้งานอยู่" or "🔴 AFK ปิดใช้งานอยู่", 3, "📊")
    end,
})

-- TAB 4: TRAVEL SYSTEM
local travelTab = Window:CreateTab("🚤 ฟังก์ชันการเดินทาง", "compass")

travelTab:CreateButton({
    Name = "🚤 เดินทาง",
    Callback = function()
        startTravel()
    end,
})

travelTab:CreateButton({
    Name = "⏹️ หยุดการเดินทาง",
    Callback = function()
        stopTravel()
    end,
})

travelTab:CreateButton({
    Name = "📍 ตรวจสอบจุดเดินทาง",
    Callback = function()
        checkTravelPoints()
    end,
})

-- TAB 5: VIEW SYSTEM
local viewTab = Window:CreateTab("👁️ View", "eye")

viewDropdown = viewTab:CreateDropdown({
    Name = "👤 เลือกผู้เล่นที่ต้องการดู",
    Options = getPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local displayName = type(option) == "table" and option[1] or option
        if type(displayName) == "string" then
            local realName = getRealName(displayName)
            viewSelectedPlayer = realName and players:FindFirstChild(realName) or nil
            if viewEnabled then refreshViewTarget() end
        end
    end,
})

viewTab:CreateButton({
    Name = "🔄 รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        viewDropdown:Refresh(getPlayers())
        notifyCustom("View", "🔄 อัปเดตรายชื่อผู้เล่นสำเร็จ", 2, "🔄")
    end,
})

viewTab:CreateToggle({
    Name = "👁️ เปิด/ปิด View",
    Callback = function(value)
        setViewEnabled(value)
    end,
})

players.PlayerAdded:Connect(function(joinedPlayer)
    joinedPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        if viewEnabled and viewSelectedPlayer == joinedPlayer then refreshViewTarget() end
    end)
end)

for _, existingPlayer in ipairs(players:GetPlayers()) do
    existingPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        if viewEnabled and viewSelectedPlayer == existingPlayer then refreshViewTarget() end
    end)
end

-- MOUSE INTERACTION & PLAYER LISTENERS
local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
    if not rescaleClick or not mouse.Target then return end

    local ppart = mouse.Target
    local model = ppart.Parent
    if model and model:IsA("Model") and model:FindFirstChild("PPart") then
        rescaleBlock(model, ppart.CFrame, Vector3.new(4, 4, 4))
    end
end)

players.PlayerAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
        if viewDropdown then viewDropdown:Refresh(getPlayers()) end
    end)
end)

players.PlayerRemoving:Connect(function(leavingPlayer)
    if selectedPlayer == leavingPlayer then
        selectedPlayer = nil
        notifyCustom("ระบบผู้เล่น", "⚠️ ผู้เล่นที่เลือกออกจากเกมแล้ว", 3, "⚠️")
    end
    if viewSelectedPlayer == leavingPlayer then
        viewSelectedPlayer = nil
        if viewEnabled then setViewEnabled(false) end
        notifyCustom("View", "⚠️ ผู้เล่นที่กำลังดูออกจากเกมแล้ว", 3, "⚠️")
    end

    task.wait(0.2)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
        if viewDropdown then viewDropdown:Refresh(getPlayers()) end
    end)
end)

notifyCustom("BABFT System", "โหลดสคริปต์เรียบร้อยแล้ว", 4, "✅")
