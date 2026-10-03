-- Build A Boat For Treasure (BABFT)
-- Copy Build script reconstructed from the supplied source + video.
-- The video ends while the original dropdown definition is truncated,
-- so the dropdown/copy controls below are completed from the surrounding code.

local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

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
end)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Build A Boat For Treasure",
    Icon = 0,
    LoadingTitle = "Rayfield Interface Suite",
    LoadingSubtitle = "Copy Build",
    Theme = "Light",
    ToggleUIKeybind = "G",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BABFT",
        FileName = "Build A Boat Config"
    },
})

local blockData = player:WaitForChild("Data")
local blocksFolder = workspace:WaitForChild("Blocks")
local ignoreAnchored = true
local selectedPlayer = nil
local usedList = {}

-- Update Copy remembers only blocks that were successfully copied.
local knownBlocks = {}

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

local function getWorldCFrame(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.CFrame end
    if instance:IsA("Model") then
        if instance.PrimaryPart then return instance.PrimaryPart.CFrame end
        return instance:GetPivot()
    end
    return nil
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

    local ok, err = pcall(function()
        tool.SetPropertieRF:InvokeServer("Transparency", {block}, transparencyWanted)
    end)
    if not ok then
        warn("[BABFT] Transparency failed: " .. tostring(err))
    end
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
        (getWorldCFrame(relativeTo) and getWorldCFrame(relativeTo):ToObjectSpace(pos)) or CFrame.new(),
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

    local hisBaseCFrame = getWorldCFrame(hisBase)
    local myBaseCFrame = getWorldCFrame(myBase)
    if not hisBaseCFrame or not myBaseCFrame then
        return block.PPart.CFrame
    end

    local offset = hisBaseCFrame:ToObjectSpace(block.PPart.CFrame)
    return myBaseCFrame * offset
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

    -- IMPORTANT:
    -- Do not use blockID as a quantity limit. blockID identifies a block type;
    -- using it as a count caused the old version to silently skip valid blocks.
    for _, block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") and block.PPart:IsA("BasePart") then
            table.insert(t, {
                Name = block.Name,
                Pos = getNewBlockPos(hisBase, block, myBase),
                Relative = myBase,
                Transparency = block.PPart.Transparency,
                Anchored = block.PPart.Anchored,
                Size = block.PPart.Size,
                Color = block.PPart.Color,
                SourceIndex = #t + 1,
            })
        end
    end

    return t
end

local function getBlockSignature(entry)
    if not entry or not entry.Pos then return nil end
    local p = entry.Pos.Position
    return table.concat({
        tostring(entry.Name),
        string.format("%.2f", p.X),
        string.format("%.2f", p.Y),
        string.format("%.2f", p.Z),
    }, "|")
end

local function filterNewBlocks(build)
    local newBlocks = {}
    local seen = {}

    for _, entry in ipairs(build) do
        local sig = getBlockSignature(entry)
        if sig and not knownBlocks[sig] and not seen[sig] then
            table.insert(newBlocks, entry)
            seen[sig] = true
        end
    end

    return newBlocks
end

local function markBlocksCopied(build)
    for _, entry in ipairs(build) do
        local sig = getBlockSignature(entry)
        if sig then
            knownBlocks[sig] = true
        end
    end
end

local function getMissingBlocks(expectedList, createdList)
    local missing = {}
    local used = {}

    for i, expected in ipairs(expectedList) do
        local best, bestDist = nil, math.huge

        for _, b in ipairs(createdList) do
            if b and b:IsA("Model") and b.Name == expected.Name and not used[b] then
                local pp = b:FindFirstChild("PPart")
                if pp and pp:IsA("BasePart") then
                    local dist = (pp.Position - expected.Pos.Position).Magnitude
                    if dist < bestDist then
                        best, bestDist = b, dist
                    end
                end
            end
        end

        if best and bestDist <= 8 then
            used[best] = true
        else
            table.insert(missing, {Index = i, Name = expected.Name, Pos = expected.Pos})
        end
    end

    return missing
end

local function getBlock(expected, createdList, alreadyUsed)
    local best = nil
    local bestDist = math.huge

    for _, b in ipairs(createdList) do
        if b and b:IsA("Model") and b.Name == expected.Name and not alreadyUsed[b] then
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

local function blockRadius(expected)
    if not expected or not expected.Size then return 3 end
    local s = expected.Size
    return math.max(s.X, s.Y, s.Z) * 0.75 + 1.5
end

local function isSupported(expected, placedEntries, myBase)
    -- A block that was originally anchored can be placed directly.
    if expected.Anchored then
        return true
    end

    local p = expected.Pos.Position
    if myBase and myBase:IsA("BasePart") then
        if (p - myBase.Position).Magnitude <= blockRadius(expected) + 4 then
            return true
        end
    elseif myBase and myBase:IsA("Model") and myBase.PrimaryPart then
        if (p - myBase.PrimaryPart.Position).Magnitude <= blockRadius(expected) + 6 then
            return true
        end
    end

    -- For unanchored blocks, require the target position to be close to a
    -- block already placed. This is the key anti-fall/dependency gate.
    for _, entry in ipairs(placedEntries) do
        local pp = entry.block and entry.block:FindFirstChild("PPart")
        if pp and pp:IsA("BasePart") then
            local limit = math.max(blockRadius(expected), entry.radius or 3) + 1.5
            if (p - pp.Position).Magnitude <= limit then
                return true
            end
        end
    end

    return false
end

local function sortBuildBySupport(build)
    local anchored = {}
    local unanchored = {}

    for _, v in ipairs(build) do
        if v.Anchored then
            table.insert(anchored, v)
        else
            table.insert(unanchored, v)
        end
    end

    -- Stable-ish ordering: anchored/grounding pieces first, then dependent pieces.
    table.sort(anchored, function(a, b)
        return a.SourceIndex < b.SourceIndex
    end)
    table.sort(unanchored, function(a, b)
        return a.Pos.Position.Y < b.Pos.Position.Y
    end)

    local result = {}
    for _, v in ipairs(anchored) do table.insert(result, v) end
    for _, v in ipairs(unanchored) do table.insert(result, v) end
    return result
end

-- Optional helper: some BABFT setups expose a screwdriver tool. We only
-- equip it when it exists; we do not guess at a private RemoteEvent name.
-- The actual dependency protection is handled by isSupported(), so a missing
-- screwdriver does not cause the copy loop to hang forever.
local function prepareScrewdriver()
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tool = character and character:FindFirstChild("Screwdriver")
    if not tool and backpack then
        tool = backpack:FindFirstChild("Screwdriver")
    end
    if tool then
        return equipTool("Screwdriver")
    end
    return nil
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
            task.wait(0.12 * attempt)
        end

        -- Keep the block anchored while it is being created. It is released
        -- only after the whole build is complete, which prevents falling.
        placeBlock(expected.Name, expected.Pos, expected.Relative, true)

        local deadline = os.clock() + (0.75 + attempt * 0.25)
        repeat
            local b, dist = findPlacedBlock(destinationFolder, expected, 6)
            if b then
                return b
            end
            task.wait(0.07)
        until os.clock() >= deadline
    end

    return nil
end

local function restoreAnchoredState(build, destinationFolder, placedMap)
    -- Restore the source Anchored state only after every dependent block has
    -- been created. This is deliberately a separate pass.
    local restored = 0
    local total = 0

    for _, expected in ipairs(build) do
        total += 1
        local b = placedMap[expected]
        if not b then
            b = select(1, findPlacedBlock(destinationFolder, expected, 8))
        end

        if b then
            -- If the source was unanchored, make sure it is connected to an
            -- already-created block before releasing it. This prevents a
            -- screwdriver/anchor operation from being applied to a floating
            -- block.
            if not expected.Anchored then
                local p = b:FindFirstChild("PPart")
                local connected = false
                if p and p:IsA("BasePart") then
                    for _, other in pairs(placedMap) do
                        if other ~= b then
                            local op = other and other:FindFirstChild("PPart")
                            if op and op:IsA("BasePart") then
                                local limit = math.max(p.Size.Magnitude, op.Size.Magnitude) * 0.45 + 2
                                if (p.Position - op.Position).Magnitude <= limit then
                                    connected = true
                                    break
                                end
                            end
                        end
                    end
                end
                if not connected then
                    -- Leave it anchored rather than allowing a floating block
                    -- to fall. This is safer than forcing an unsupported state.
                    setAnchored(b)
                    continue
                end
            end

            -- Existing PropertiesTool path is used for the final state.
            -- A Screwdriver, when present, may be equipped separately by the
            -- dependency stage, but no undocumented remote is guessed here.
            if expected.Anchored then
                setAnchored(b)
            else
                -- If the game accepts PropertiesTool for unanchoring, invoke
                -- the same remote with false. If it does not, the block stays
                -- anchored instead of being left floating.
                local tool = equipTool("PropertiesTool")
                local rf = tool and tool:FindFirstChild("SetPropertieRF")
                if rf then
                    pcall(function()
                        rf:InvokeServer("Anchored", {b}, false)
                    end)
                end
            end
            restored += 1
        end
    end

    return restored, total
end


-- Copy status UI
local copyStatus = {
    waiting = 0,
    total = 0,
    placed = 0,
    missing = 0,
    percent = 0,
    running = false
}

local statusFrame
local statusTitle
local statusText
local progressBar
local progressFill
local operationText
local missingText
local countText

local function createCopyStatusUI()
    if statusFrame and statusFrame.Parent then
        return
    end

    statusFrame = Instance.new("Frame")
    statusFrame.Name = "CopyBuildStatus"
    statusFrame.Size = UDim2.new(0, 360, 0, 190)
    statusFrame.Position = UDim2.new(0.5, -155, 0, 80)
    statusFrame.BackgroundTransparency = 0.08
    statusFrame.BackgroundColor3 = Color3.fromRGB(184, 242, 230) -- #B8F2E6
    statusFrame.Parent = Rayfield.Main

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
    statusTitle.TextColor3 = Color3.fromRGB(36, 67, 77)
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.Parent = statusFrame

    statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 55)
    statusText.Position = UDim2.new(0, 10, 0, 40)
    statusText.BackgroundTransparency = 1
    statusText.Text = "พร้อมใช้งาน"
    statusText.TextSize = 14
    statusText.Font = Enum.Font.Gotham
    statusText.TextColor3 = Color3.fromRGB(36, 67, 77)
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextYAlignment = Enum.TextYAlignment.Top
    statusText.Parent = statusFrame

    operationText = Instance.new("TextLabel")
    operationText.Size = UDim2.new(1, -20, 0, 24)
    operationText.Position = UDim2.new(0, 10, 0, 95)
    operationText.BackgroundTransparency = 1
    operationText.Text = "🟢 พร้อมใช้งาน"
    operationText.TextSize = 13
    operationText.Font = Enum.Font.GothamMedium
    operationText.TextColor3 = Color3.fromRGB(36, 67, 77)
    operationText.TextXAlignment = Enum.TextXAlignment.Left
    operationText.Parent = statusFrame

    missingText = Instance.new("TextLabel")
    missingText.Size = UDim2.new(1, -20, 0, 22)
    missingText.Position = UDim2.new(0, 10, 0, 118)
    missingText.BackgroundTransparency = 1
    missingText.Text = "❌ ขาด: 0 บล็อก"
    missingText.TextSize = 12
    missingText.Font = Enum.Font.Gotham
    missingText.TextColor3 = Color3.fromRGB(36, 67, 77)
    missingText.TextXAlignment = Enum.TextXAlignment.Left
    missingText.Parent = statusFrame
    countText = Instance.new("TextLabel")
    countText.Name = "BlockCount"
    countText.Size = UDim2.new(1, -20, 0, 22)
    countText.Position = UDim2.new(0, 10, 0, 116)
    countText.BackgroundTransparency = 1
    countText.Text = "🧱 พบ: 0 | 🏗️ วางแล้ว: 0 | ⏳ เหลือ: 0 | ❌ ขาด: 0 | 🔗 รอจุดยึด: 0"
    countText.TextSize = 11
    countText.Font = Enum.Font.GothamBold
    countText.TextColor3 = Color3.fromRGB(36, 67, 77)
    countText.TextXAlignment = Enum.TextXAlignment.Left
    countText.Parent = statusFrame

    local function updateBlockCount(found, placedNow, missingNow, waitingNow)
        found = tonumber(found) or 0
        placedNow = tonumber(placedNow) or 0
        missingNow = tonumber(missingNow) or 0
        waitingNow = tonumber(waitingNow) or 0
        local remaining = math.max(found - placedNow, 0)
        countText.Text = ("🧱 พบ: %d | 🏗️ วางแล้ว: %d | ⏳ เหลือ: %d | ❌ ขาด: %d | 🔗 รอจุดยึด: %d")
            :format(found, placedNow, remaining, missingNow, waitingNow)
    end

    updateBlockCount(0, 0, 0, 0)

    local legendText = Instance.new("TextLabel")
    legendText.Name = "ToolLegend"
    legendText.Size = UDim2.new(1, -20, 0, 20)
    legendText.Position = UDim2.new(0, 10, 0, 140)
    legendText.BackgroundTransparency = 1
    legendText.Text = "🧱 บล็อก  🏗️ วาง  🪛 ไขควง  🔗 จุดยึด  📏 ขนาด  🎨 สี  🔧 คุณสมบัติ  🛡️ กันตก"
    legendText.TextSize = 10
    legendText.Font = Enum.Font.Gotham
    legendText.TextXAlignment = Enum.TextXAlignment.Left
    legendText.Parent = statusFrame

    local bar = Instance.new("Frame")
    bar.Name = "ProgressBar"
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 1, -25)
    bar.BackgroundTransparency = 0.35
    bar.Parent = statusFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 7)
    barCorner.Parent = bar

    progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundTransparency = 0
    progressFill.BackgroundColor3 = Color3.fromRGB(101, 214, 176) -- mint
    progressFill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 7)
    fillCorner.Parent = progressFill
end

local function updateCopyStatus(total, placed, missing, running, waiting)
    createCopyStatusUI()

    copyStatus.total = total or 0
    copyStatus.placed = placed or 0
    copyStatus.missing = missing or 0
    copyStatus.running = running == true
    copyStatus.waiting = tonumber(waiting) or 0

    if copyStatus.total > 0 then
        copyStatus.percent = math.floor((copyStatus.placed / copyStatus.total) * 100 + 0.5)
    else
        copyStatus.percent = 0
    end

    statusText.Text = ("ทั้งหมด: %d\nวางสำเร็จ: %d\nขาด: %d\nความคืบหน้า: %d%%"):format(
        copyStatus.total,
        copyStatus.placed,
        copyStatus.missing,
        copyStatus.percent
    )

    progressFill.Size = UDim2.new(
        math.clamp(copyStatus.percent / 100, 0, 1),
        0, 1, 0
    )

    if missingText then
        missingText.Text = ("❌ ขาด: %d บล็อก"):format(copyStatus.missing)
    end

    if countText then
        local remaining = math.max(copyStatus.total - copyStatus.placed, 0)
        countText.Text = ("🧱 พบ: %d | 🏗️ วางแล้ว: %d | ⏳ เหลือ: %d | ❌ ขาด: %d | 🔗 รอจุดยึด: %d")
            :format(copyStatus.total, copyStatus.placed, remaining, copyStatus.missing, copyStatus.waiting)
    end
end

local function setOperation(text)
    createCopyStatusUI()
    operationText.Text = text
end

createCopyStatusUI()
updateCopyStatus(0, 0, 0, false, 0)

local copyBusy = false

local function performCopyBuild(build, mode)
    if copyBusy then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "กำลังทำงานอยู่ กรุณารอให้รอบปัจจุบันเสร็จก่อน",
            Duration = 4
        })
        return false
    end

    local destinationFolder = blocksFolder:FindFirstChild(player.Name)
    if not destinationFolder then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "ไม่พบพื้นที่สิ่งก่อสร้างของเรา",
            Duration = 4
        })
        return false
    end

    if #build == 0 then
        setOperation(mode == "update" and "✅ ไม่มีบล็อกใหม่ให้เพิ่ม" or "⚠️ ไม่พบบล็อก")
        return true
    end

    copyBusy = true
    build = sortBuildBySupport(build)

    local total = #build
    local placed = 0
    local placedEntries = {}
    local placedMap = {}

    updateCopyStatus(total, 0, total, true, total)
    if mode == "update" then
        setOperation(("🔄 กำลังอัปเดต: %d บล็อกใหม่"):format(total))
    else
        setOperation(("📋 กำลังก็อปปี้: %d บล็อก"):format(total))
    end

    prepareScrewdriver()

    local pending = {}
    for i = 1, total do pending[i] = i end

    local pass = 0
    local maxPasses = math.max(3, math.min(total + 2, 12))

    while #pending > 0 and pass < maxPasses do
        pass += 1
        local nextPending = {}
        local progressThisPass = 0

        setOperation(("🔗 รอบที่ %d/%d — ตรวจจุดยึด"):format(pass, maxPasses))

        for _, index in ipairs(pending) do
            local expected = build[index]

            if not expected.Anchored and not isSupported(expected, placedEntries, getPlayerZone(player)) then
                table.insert(nextPending, index)
                updateCopyStatus(total, placed, #nextPending, true, #nextPending)
                continue
            end

            setOperation(("🏗️ กำลังสร้าง 🧱 %d/%d: %s"):format(placed + 1, total, expected.Name))
            local b = placeAndVerify(expected, destinationFolder)

            if b then
                placed += 1
                progressThisPass += 1
                placedMap[expected] = b
                table.insert(placedEntries, {block = b, radius = blockRadius(expected)})
            else
                table.insert(nextPending, index)
            end

            updateCopyStatus(total, placed, #nextPending, true, #nextPending)
            task.wait(0.035)
        end

        pending = nextPending

        if #pending > 0 and progressThisPass == 0 then
            setOperation(("🛡️ กันตก: %d บล็อกยังรอ 🔗 จุดยึด"):format(#pending))
            task.wait(0.25)

            if pass >= 2 then
                local fallback = pending
                pending = {}

                for _, index in ipairs(fallback) do
                    local expected = build[index]
                    setOperation(("🛡️ วางแบบกันตก | 🧱 %s"):format(expected.Name))
                    local b = placeAndVerify(expected, destinationFolder)

                    if b then
                        placed += 1
                        placedMap[expected] = b
                        table.insert(placedEntries, {block = b, radius = blockRadius(expected)})
                    else
                        table.insert(pending, index)
                    end

                    updateCopyStatus(total, placed, #pending, true, #pending)
                end
            end
        end
    end

    local stillMissing = {}
    for i, expected in ipairs(build) do
        local b = placedMap[expected]
        if not b or not b.Parent then
            b = select(1, findPlacedBlock(destinationFolder, expected, 8))
            if b then
                placedMap[expected] = b
            else
                table.insert(stillMissing, i)
            end
        end
    end

    if #stillMissing > 0 then
        setOperation(("🔄 ตรวจซ้ำ %d บล็อก"):format(#stillMissing))
        local deadline = os.clock() + 5

        while #stillMissing > 0 and os.clock() < deadline do
            local remaining = {}
            for _, index in ipairs(stillMissing) do
                local expected = build[index]
                local b = select(1, findPlacedBlock(destinationFolder, expected, 8))
                if b then
                    placedMap[expected] = b
                else
                    table.insert(remaining, index)
                end
            end
            stillMissing = remaining
            task.wait(0.15)
        end
    end

    local created = destinationFolder:GetChildren()
    local edited = 0

    for _, expected in ipairs(build) do
        local b = placedMap[expected]
        if not b or not b.Parent then
            b = select(1, getBlock(expected, created, {}))
        end

        if b then
            setOperation(("📏 ปรับขนาด + 🎨 ทาสี | 🧱 %s"):format(expected.Name))
            rescaleBlock(b, expected.Pos, expected.Size)
            task.wait(0.035)
            paintBlock(b, expected.Color)
            task.wait(0.035)

            if expected.Transparency > 0 then
                setOperation(("🔧 ปรับคุณสมบัติ | 🧱 %s"):format(expected.Name))
                setTransparency(expected.Transparency, b)
                task.wait(0.05)
            end

            edited += 1
        end
    end

    setOperation("🪛 ตรวจไขควง + 🔗 จุดยึด ก่อนคืนสถานะ")
    local restored = restoreAnchoredState(build, destinationFolder, placedMap)

    local finalMissing = #stillMissing
    updateCopyStatus(total, placed, finalMissing, false, 0)

    -- Only verified blocks become part of the baseline. Failed blocks can be
    -- retried by the next Update Copy without duplicating successful ones.
    local copiedThisRound = {}
    for _, expected in ipairs(build) do
        local b = placedMap[expected]
        if b and b.Parent then
            table.insert(copiedThisRound, expected)
        end
    end
    markBlocksCopied(copiedThisRound)

    if finalMissing == 0 then
        if mode == "update" then
            setOperation(("✅ อัปเดตเสร็จ: เพิ่ม %d บล็อก"):format(placed))
            Rayfield:Notify({
                Title = "อัปเดตเสร็จแล้ว",
                Content = ("เพิ่ม %d บล็อก | ปรับแต่ง %d | คืนสถานะ %d"):format(placed, edited, restored),
                Duration = 6
            })
        else
            setOperation(("✅ ก็อปปี้เสร็จ: %d/%d บล็อก"):format(placed, total))
            Rayfield:Notify({
                Title = "ก็อปปี้เสร็จแล้ว",
                Content = ("สร้างครบ %d/%d บล็อก"):format(placed, total),
                Duration = 6
            })
        end
    else
        setOperation(("⚠️ เสร็จบางส่วน: %d/%d | ขาด %d"):format(placed, total, finalMissing))
        Rayfield:Notify({
            Title = mode == "update" and "อัปเดตเสร็จบางส่วน" or "ก็อปปี้เสร็จบางส่วน",
            Content = ("สร้างได้ %d/%d | ยังขาด %d บล็อก"):format(placed, total, finalMissing),
            Duration = 7
        })
    end

    copyBusy = false
    return finalMissing == 0
end

local function runCopyBuild(targetPlayer)
    if copyBusy then
        Rayfield:Notify({Title = "ก็อปปี้สิ่งก่อสร้าง", Content = "กำลังทำงานอยู่", Duration = 3})
        return
    end

    if not targetPlayer or not targetPlayer.Parent then
        Rayfield:Notify({Title = "ก็อปปี้สิ่งก่อสร้าง", Content = "กรุณาเลือกผู้เล่นก่อน", Duration = 4})
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        Rayfield:Notify({Title = "ก็อปปี้สิ่งก่อสร้าง", Content = "ไม่พบสิ่งก่อสร้างของผู้เล่นนี้", Duration = 4})
        return
    end

    local build = copyBuild(sourceFolder)
    if #build == 0 then
        Rayfield:Notify({Title = "ก็อปปี้สิ่งก่อสร้าง", Content = "ไม่พบบล็อกที่สามารถก็อปปี้ได้", Duration = 4})
        return
    end

    -- A new Copy starts a new baseline.
    knownBlocks = {}
    performCopyBuild(build, "copy")
end

local function runUpdateCopy(targetPlayer)
    if next(knownBlocks) == nil then
        Rayfield:Notify({
            Title = "อัปเดตสิ่งก่อสร้าง",
            Content = "ต้องกด 📋 ก็อปปี้ก่อน แล้วจึงกด ➖ อัปเดต",
            Duration = 5
        })
        return
    end

    if not targetPlayer then
        Rayfield:Notify({Title = "อัปเดตสิ่งก่อสร้าง", Content = "ยังไม่ได้เลือกผู้เล่น", Duration = 4})
        return
    end

    if copyBusy then
        Rayfield:Notify({Title = "อัปเดตสิ่งก่อสร้าง", Content = "กำลังทำงานอยู่ กรุณารอ", Duration = 4})
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        Rayfield:Notify({
            Title = "อัปเดตสิ่งก่อสร้าง",
            Content = "ผู้เล่นต้นทางไม่อยู่ในเกม จึงตรวจของที่เพิ่มไม่ได้",
            Duration = 5
        })
        return
    end

    local build = copyBuild(sourceFolder)
    local newBlocks = filterNewBlocks(build)

    if #newBlocks == 0 then
        setOperation("✅ ไม่มีบล็อกใหม่จากรอบล่าสุด")
        Rayfield:Notify({Title = "อัปเดตสิ่งก่อสร้าง", Content = "ไม่พบบล็อกใหม่", Duration = 4})
        return
    end

    performCopyBuild(newBlocks, "update")
end

local autoBuildTab = Window:CreateTab("Building", "rewind")

autoBuildTab:CreateSection("📋 คัดลอกสิ่งก่อสร้าง")

local playerDropdown = autoBuildTab:CreateDropdown({
    Name = "👤 เลือกผู้เล่น",
    Options = getPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local displayName = type(option) == "table" and option[1] or option
        if type(displayName) == "string" then
            local realName = getRealName(displayName)
            selectedPlayer = realName and players:FindFirstChild(realName) or nil
            if selectedPlayer then
                setOperation(("👤 เลือกผู้เล่น: %s"):format(selectedPlayer.DisplayName))
            end
        end
    end,
})

autoBuildTab:CreateButton({
    Name = "🔄 รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        playerDropdown:Refresh(getPlayers())
        Rayfield:Notify({Title = "🔄 รายชื่อผู้เล่น", Content = "รีเฟรชเรียบร้อยแล้ว", Duration = 3})
    end,
})

autoBuildTab:CreateToggle({
    Name = "📋 ก็อปปี้สิ่งก่อสร้าง",
    CurrentValue = false,
    Flag = "CopyBuildToggle",
    Callback = function(enabled)
        if enabled then
            runCopyBuild(selectedPlayer)
        else
            setOperation("⚪ ก็อปปี้: ปิด")
        end
    end,
})

autoBuildTab:CreateButton({
    Name = "➖ อัปเดตสิ่งก่อสร้าง",
    Callback = function()
        runUpdateCopy(selectedPlayer)
    end,
})

autoBuildTab:CreateParagraph({
    Title = "วิธีใช้",
    Content = "เลือกผู้เล่น → เปิด 📋 ก็อปปี้รอบแรก → รอให้ผู้เล่นสร้างเพิ่ม → กด ➖ อัปเดต\nการอัปเดตทำงาน 1 รอบแล้วหยุด และไม่สร้างบล็อกที่อยู่ในรอบก่อนซ้ำ",
})

autoBuildTab:CreateParagraph({
    Title = "🩵 สถานะระบบ",
    Content = "UI ใช้โทนฟ้านม/มิ้นต์ • Copy/Update ตรวจบล็อกและจุดยึดจากระบบเดิม • ไม่เดา Remote ฟาร์ม",
})

players.PlayerAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
    end)
end)

players.PlayerRemoving:Connect(function(leavingPlayer)
    if selectedPlayer == leavingPlayer then
        selectedPlayer = nil
        setOperation("⚠️ ผู้เล่นต้นทางออกจากเกมแล้ว")
    end

    task.wait(0.2)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
    end)
end)

Rayfield:Notify({
    Title = "คัดลอกสิ่งก่อสร้าง BABFT",
    Content = "โหลดสคริปต์เรียบร้อยแล้ว",
    Duration = 4,
})
