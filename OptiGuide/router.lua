-- Router: decides the current guidance target (zone hop or nearest quest
-- objective), refreshes arrow/panel, and nudges Blizzard super-tracking.
local _, OG = ...

OG.target = nil
OG.currentStep = nil

-- cached zone-name -> uiMapID resolution (per continent)
local mapCache = {}
local function TopMap(mapID)
  local info = C_Map.GetMapInfo(mapID)
  local guard = 0
  while info and info.parentMapID and info.parentMapID ~= 0 and guard < 12 do
    info = C_Map.GetMapInfo(info.parentMapID)
    guard = guard + 1
  end
  return info
end

function OG:MapIDForZone(name, cont)
  mapCache[cont] = mapCache[cont] or {}
  if mapCache[cont][name] then return mapCache[cont][name] end
  local top
  for _, m in ipairs(C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Continent) or {}) do -- 946 = cosmos/world
    if m.name == cont then top = m break end
  end
  if not top then return nil end
  local function find(id)
    for _, m in ipairs(C_Map.GetMapChildrenInfo(id, Enum.UIMapType.Zone) or {}) do
      if m.name == name then return m.mapID end
      local r = find(m.mapID)
      if r then return r end
    end
    return nil
  end
  local found = find(top.mapID)
  mapCache[cont][name] = found or false
  return found or nil
end

local function WorldPos(mapID, x, y)
  if not (mapID and x and y) then return nil end
  local ok, v = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
  if ok and v then return v.x, v.y end
  return nil
end

function OG:PlayerWorld()
  local ok, x, y, inst = pcall(UnitPosition, "player")
  if ok and x then return x, y, inst end
  return nil
end

local function RouteZone(level)
  for _, z in ipairs(OG.route) do
    if level >= z.lo and level <= z.hi then return z end
  end
  if level > 0 and level < 120 then return OG.route[#OG.route] end
  return nil
end

function OG:CurrentZoneName()
  local m = C_Map.GetBestMapForUnit("player")
  if not m then return nil, nil end
  local info = C_Map.GetMapInfo(m)
  return info and info.name or nil, m
end

-- pick the closest quest-log waypoint on the player's continent
local function BestQuestWaypoint()
  local px, py = OG:PlayerWorld()
  if not px then return nil end
  local pMap = C_Map.GetBestMapForUnit("player")
  local pTop = pMap and TopMap(pMap)
  local best, bestD
  local n = C_QuestLog.GetNumQuestLogEntries()
  for i = 1, n do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and not info.isHidden then
      local mID, wx, wy = C_QuestLog.GetNextWaypoint(info.questID)
      if mID and wx and wy then
        local wTop = TopMap(mID)
        if wTop and pTop and wTop.mapID == pTop.mapID then
          local mx, my = WorldPos(mID, wx, wy)
          if mx then
            local d = (mx - px) ^ 2 + (my - py) ^ 2
            if not bestD or d < bestD then
              bestD = d
              best = { kind = "quest", questID = info.questID, title = info.title,
                       mapID = mID, x = wx, y = wy, wx = mx, wy = my }
            end
          end
        end
      end
    end
  end
  return best
end

function OG:Retarget()
  local level = UnitLevel("player") or 1
  local zoneName = OG:CurrentZoneName()
  local qp = BestQuestWaypoint()

  if qp then
    OG.target = qp
    OG.currentStep = ("Quest: %s"):format(qp.title or "?")
    -- let Blizzard's native tracker reinforce it (minimap pin + arrow)
    pcall(C_SuperTrack.SetSuperTrackedQuestID, qp.questID)
  elseif OG.db and OG.db.zoneRoute then
    local rz = RouteZone(level)
    if rz and zoneName ~= rz.zone then
      local mID = OG:MapIDForZone(rz.zone, rz.cont)
      if mID then
        local wx, wy = WorldPos(mID, rz.x, rz.y)
        OG.target = { kind = "zone", mapID = mID, x = rz.x, y = rz.y,
                      wx = wx, wy = wy, title = rz.zone, hub = rz.hub }
        OG.currentStep = ("Travel: %s (%d-%d) - %s"):format(rz.zone, rz.lo, rz.hi, rz.hub or "")
      else
        OG.target = nil
        OG.currentStep = ("Travel: %s (%d-%d)"):format(rz.zone, rz.lo, rz.hi)
      end
    else
      OG.target = nil
      OG.currentStep = rz and ("In zone: %s - quest at %s"):format(rz.zone, rz.hub or "?") or "Endgame"
    end
  else
    OG.target = nil
    OG.currentStep = "No waypoint"
  end

  OG:UpdateArrow()
  OG:UpdatePanel()
end

local pending = false
local function ScheduleRetarget()
  if pending then return end
  pending = true
  C_Timer.After(0.35, function()
    pending = false
    OG:Retarget()
  end)
end

OG:RegisterEvent("PLAYER_LOGIN", function()
  OG:InitDB()
  ScheduleRetarget()
end)
for _, e in ipairs({
  "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
  "QUEST_WATCH_LIST_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP",
  "PLAYER_ENTERING_WORLD", "QUEST_POI_UPDATE",
}) do
  OG:RegisterEvent(e, ScheduleRetarget)
end
