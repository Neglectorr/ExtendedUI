local TotemRangeUtil = {}

TotemRangeUtil.positions = {}  -- [slot] = {x, y, mapID, timestamp}
TotemRangeUtil.range = 20      -- yards; pas aan voor andere afstanden

function TotemRangeUtil:SavePosition(slot)
    local x, y, _, mapID = UnitPosition("player")
    if x and y and mapID then
        self.positions[slot] = {x=x, y=y, mapID=mapID, timestamp=GetTime()}
    end
end

function TotemRangeUtil:IsPlayerInRange(slot)
    local curx, cury, _, curMapID = UnitPosition("player")
    local t = self.positions[slot]
    if t and t.mapID == curMapID and curx and cury then
        local dx = curx - t.x
        local dy = cury - t.y
        local dist = math.sqrt(dx*dx + dy*dy)
        return dist <= self.range
    end
    return true -- geen positie bekend; altijd in range
end

-- Event handler: Sla alleen hier de positie op!
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
eventFrame:SetScript("OnEvent", function(_, _, slot)
    local haveTotem, _, _, duration, _ = GetTotemInfo(slot)
    if haveTotem and duration and duration > 0 then
        TotemRangeUtil:SavePosition(slot)
    end
end)

_G.TotemRangeUtil = TotemRangeUtil  -- Optioneel: globaal beschikbaar maken
return TotemRangeUtil