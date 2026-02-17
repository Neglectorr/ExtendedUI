local TotemRangeUtil = {}

TotemRangeUtil.positions = {}  -- [slot] = {x, y, mapID, timestamp}
TotemRangeUtil.totemCoords = {} -- [slot] = {x, y, mapID, timestamp}
TotemRangeUtil.range = 20      -- yards; pas aan voor andere afstanden

-- Totem offsets: per slot (1=Aarde, 2=Vuur, 3=Water, 4=Lucht bij TBC/Classic)
TotemRangeUtil.offsetYards = 3 -- Totem afstand in yards (~2.7 meter)
TotemRangeUtil.offsetAngles = {
    [1] = math.rad(315), -- Earth: rechts voor
    [2] = math.rad(45),  -- Fire: links voor
    [3] = math.rad(135), -- Water: rechts achter
    [4] = math.rad(225), -- Air: links achter
}

-- Save exact player position (legacy fallback), plus totem position using facing!
function TotemRangeUtil:SavePosition(slot)
    local x, y, _, mapID = UnitPosition("player")
    local facing = GetPlayerFacing() -- radians, 0 = north
    if x and y and mapID and facing then
        self.positions[slot] = {x=x, y=y, mapID=mapID, timestamp=GetTime()}
        -- Bereken totem positie
        local angle = self.offsetAngles[slot] or 0
        local ox = math.cos(facing + angle) * self.offsetYards
        local oy = math.sin(facing + angle) * self.offsetYards
        local totX = x + ox
        local totY = y + oy
        self.totemCoords[slot] = {x=totX, y=totY, mapID=mapID, timestamp=GetTime(), facing=facing, offsetAngle=angle}
        -- Debug print
        -- print(("Totem pos slot %d: %.2f, %.2f (player %.2f, %.2f) facing %.3f offset %.1f"):format(slot, totX, totY, x, y, facing, math.deg(angle)))
    end
end

-- Check range from player position to last stored totem spawn position
function TotemRangeUtil:IsPlayerInRange(slot)
    local curx, cury, _, curMapID = UnitPosition("player")
    local t = self.totemCoords[slot]
    if t and t.mapID == curMapID and curx and cury then
        local dx = curx - t.x
        local dy = cury - t.y
        local dist = math.sqrt(dx*dx + dy*dy)
        return dist <= self.range
    end
    return true -- geen positie bekend; altijd in range
end

-- Event handler: Alleen hier de positie EN de totem-coord opslaan
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
eventFrame:SetScript("OnEvent", function(_, _, slot)
    local haveTotem, _, _, duration, _ = GetTotemInfo(slot)
    if haveTotem and duration and duration > 0 then
        TotemRangeUtil:SavePosition(slot)
    end
end)

_G.TotemRangeUtil = TotemRangeUtil  -- Globaal beschikbaar maken (optioneel)
return TotemRangeUtil