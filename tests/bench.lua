-- OptiGuide CPU benchmark: stub API, load addon, measure Retarget + arrow
-- refresh cost per call. Budget: well under 1ms per retarget, ~0.01ms per
-- arrow tick (arrow runs at 10Hz).
local timers = {}
C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local function runTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end

local function mockObj(kind)
  local o = { shown = false, scripts = {}, texts = {}, regd = {} }
  local mt = { __index = function(_, k)
    if k == "SetScript" then return function(s, n, f) s.scripts[n] = f end
    elseif k == "Show" then return function(s) s.shown = true end
    elseif k == "Hide" then return function(s) s.shown = false end
    elseif k == "IsShown" then return function(s) return s.shown end
    elseif k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end
    elseif k == "SetRotation" then return function(s, r) s.rot = r end
    elseif k == "SetFormattedText" then return function(s, f, ...) s.texts[#s.texts+1] = f:format(...) end
    elseif k == "SetText" then return function(s, t) s.texts[#s.texts+1] = t end
    elseif k == "CreateTexture" then return function(s) return mockObj("tex") end
    elseif k == "CreateFontString" then return function(s) return mockObj("fs") end
    elseif k == "RegisterEvent" then return function(s, e) s.regd[e] = true end
    else return function() end end
  end }
  return setmetatable(o, mt)
end

CreateFrame = function(_, n) return mockObj("frame") end
CreateVector2D = function(x, y) return { x = x, y = y } end
UIParent = mockObj("uip")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
wipe = function(t) for k in pairs(t) do t[k] = nil end end
geterrorhandler = function() return function(m) error(m, 0) end end
InCombatLockdown = function() return false end
GetPlayerFacing = function() return 0.7 end
UnitPosition = function() return 1234.5, 678.9, 0 end
UnitLevel = function() return 24 end
ReloadUI = function() end

local MAPS = { [946]={name="A",parentMapID=0}, [100]={name="Kalimdor",parentMapID=946} }
local CHILDREN = { [946]={{name="Kalimdor",mapID=100}} }
CHILDREN[100] = {}
for i = 1, 40 do
  MAPS[200+i] = { name = "Zone"..i, parentMapID = 100 }
  CHILDREN[100][i] = { name = "Zone"..i, mapID = 200+i }
end
C_Map = {
  GetMapInfo = function(id) return MAPS[id] end,
  GetMapChildrenInfo = function(id) return CHILDREN[id] or {} end,
  GetBestMapForUnit = function() return 210 end,
  GetWorldPosFromMapPos = function(id, v) return { x = v.x * 1000, y = v.y * 1000 } end,
}

-- 25-quest log (typical max) each with waypoint
TEST_QUESTS = {}
for i = 1, 25 do TEST_QUESTS[i] = { isHeader=false, isHidden=false, questID=1000+i, title="Q"..i } end
C_QuestLog = {
  GetNumQuestLogEntries = function() return #TEST_QUESTS end,
  GetInfo = function(i) return TEST_QUESTS[i] end,
  GetNextWaypoint = function(q) return 210, (q % 100) / 100, (q % 7) / 7 end,
}
C_SuperTrack = { SetSuperTrackedQuestID = function() end }
C_GossipInfo = {}

local ORDER = { "core.lua", "data_horde.lua", "router.lua", "arrow.lua", "panel.lua", "auto.lua" }
for _, fn in ipairs(ORDER) do
  assert(loadstring(ADDON_FILES[fn], "@" .. fn))("OptiGuide", OptiGuideNS)
end
local OG = OptiGuideNS
OG.events["PLAYER_LOGIN"](); runTimers()

local N = 2000
collectgarbage("collect")
local t0 = os.clock()
for i = 1, N do OG:Retarget() end
local rt = (os.clock() - t0) / N * 1000

t0 = os.clock()
for i = 1, N do OG:RefreshArrow() end
local ar = (os.clock() - t0) / N * 1000

t0 = os.clock()
for i = 1, N do OG:UpdatePanel() end
local up = (os.clock() - t0) / N * 1000

-- steady-state per-frame cost estimate at 10Hz arrow + retarget ~1/sec
local perSec = rt * 1 + ar * 10 + up * 1
print(("BENCH retarget=%.3fms arrow=%.4fms panel=%.3fms est_per_sec=%.3fms")
  :format(rt, ar, up, perSec))
print("BENCH " .. (perSec < 5 and "PASS(cpu<5ms/sec)" or "FAIL"))
