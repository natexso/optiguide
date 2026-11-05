-- OptiGuide test harness: stubs the WoW API, loads addon files in toc order,
-- fires events, asserts behavior. Prints PASS/FAIL lines; sets __FAILED>0.
local FAIL = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); FAIL = FAIL + 1 end
end

-- ---------- WoW API stubs ----------
local timers = {}
C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local function runTimers()
  local t = timers; timers = {}
  for _, f in ipairs(t) do f() end
end

local frames = {}
local function mockObj(kind)
  local o = { kind = kind, shown = false, scripts = {}, texts = {}, regd = {} }
  local mt = { __index = function(_, k)
    if k == "SetScript" then return function(s, n, f) s.scripts[n] = f end
    elseif k == "GetScript" then return function(s, n) return s.scripts[n] end
    elseif k == "RegisterEvent" then return function(s, e) s.regd[e] = true end
    elseif k == "Show" then return function(s) s.shown = true end
    elseif k == "Hide" then return function(s) s.shown = false end
    elseif k == "IsShown" then return function(s) return s.shown end
    elseif k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end
    elseif k == "SetText" then return function(s, t) s.texts[#s.texts + 1] = t end
    elseif k == "SetFormattedText" then return function(s, f, ...) s.texts[#s.texts + 1] = f:format(...) end
    elseif k == "SetRotation" then return function(s, r) s.rot = r end
    elseif k == "CreateTexture" then return function(s) local t = mockObj("tex"); s.tex = t; return t end
    elseif k == "CreateFontString" then return function(s) local fs = mockObj("fs"); return fs end
    else return function() end end
  end }
  return setmetatable(o, mt)
end

CreateFrame = function(_, name) local f = mockObj("frame"); frames[name or "?"] = f; return f end
CreateVector2D = function(x, y) return { x = x, y = y } end
UIParent = mockObj("uiparent")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
wipe = function(t) for k in pairs(t) do t[k] = nil end end
geterrorhandler = function() return function(m) error(m, 0) end end
InCombatLockdown = function() return false end
ReloadUI = function() end
GetPlayerFacing = function() return TEST_FACING or 0 end
UnitPosition = function() return TEST_PX or 0, TEST_PY or 0, 0 end
UnitLevel = function() return TEST_LEVEL or 1 end
IsQuestCompletable = function() return true end

-- mock map tree: world 946 -> continent 100 "Kalimdor" -> zones
local MAPS = {
  [946] = { name = "Azeroth", parentMapID = 0 },
  [100] = { name = "Kalimdor", parentMapID = 946 },
  [200] = { name = "Durotar", parentMapID = 100 },
  [201] = { name = "Azshara", parentMapID = 100 },
  [202] = { name = "Ashenvale", parentMapID = 100 },
}
local CHILDREN = {
  [946] = { { name = "Kalimdor", mapID = 100 } },
  [100] = { { name = "Durotar", mapID = 200 }, { name = "Azshara", mapID = 201 }, { name = "Ashenvale", mapID = 202 } },
}
C_Map = {
  GetMapInfo = function(id) return MAPS[id] end,
  GetMapChildrenInfo = function(id) return CHILDREN[id] or {} end,
  GetBestMapForUnit = function() return TEST_MAP or 200 end,
  GetWorldPosFromMapPos = function(id, v) return { x = v.x * 1000, y = v.y * 1000 } end,
}

-- mock quest log
TEST_QUESTS = {
  { isHeader = false, isHidden = false, questID = 11, title = "Kill Boars" },
  { isHeader = false, isHidden = false, questID = 22, title = "Collect Cactus" },
}
C_QuestLog = {
  GetNumQuestLogEntries = function() return #TEST_QUESTS end,
  GetInfo = function(i) return TEST_QUESTS[i] end,
  GetNextWaypoint = function(qid)
    if qid == 11 then return 200, 0.10, 0.10 end  -- near player
    if qid == 22 then return 200, 0.90, 0.90 end  -- far
    return nil
  end,
}
C_SuperTrack = { SetSuperTrackedQuestID = function(q) TEST_TRACKED = q end }
C_GossipInfo = {}

-- quest interaction stubs
local called = {}
AcceptQuest = function() called.accept = true end
ContinueQuest = function() called.cont = true end
CompleteQuest = function() called.comp = true end
GetQuestReward = function() called.reward = true end
GetNumQuestChoices = function() return 1 end
GetNumAvailableQuests = function() return 1 end
GetNumActiveQuests = function() return 0 end
SelectAvailableQuest = function() called.selAvail = true end
SelectActiveQuest = function() called.selAct = true end
GetNumGossipAvailableQuests = function() return 0 end
GetNumGossipActiveQuests = function() return 0 end
GetGossipOptions = function() return {} end
GetQuestLogTitle = function() return "x" end
IsInInstance = function() return false end

-- ---------- load addon in toc order ----------
local ORDER = { "core.lua", "data_horde.lua", "router.lua", "arrow.lua", "panel.lua", "auto.lua" }
for _, fn in ipairs(ORDER) do
  local src = assert(ADDON_FILES[fn], "missing " .. fn)
  local chunk = assert(loadstring(src, "@" .. fn))
  chunk("OptiGuide", OptiGuideNS)
end

local OG = OptiGuideNS
local function fire(evt, ...) if OG.events[evt] then OG.events[evt](...) end end

-- ---------- tests ----------
check("frame registered", frames["OptiGuideFrame"] ~= nil)
check("events registered", OG.events["PLAYER_LOGIN"] ~= nil and OG.events["QUEST_LOG_UPDATE"] ~= nil)

TEST_LEVEL, TEST_MAP, TEST_PX, TEST_PY = 5, 200, 100, 100 -- lvl5 in Durotar
fire("PLAYER_LOGIN")
runTimers()
check("db initialized", OG.db ~= nil and OG.db.auto == true)
check("nearest quest picked", OG.target ~= nil and OG.target.questID == 11)
check("step text", (OG.currentStep or ""):find("Kill Boars") ~= nil)
check("arrow visible", frames["OptiGuideArrow"].shown == true)
check("panel visible", frames["OptiGuidePanel"].shown == true)
check("supertrack set", TEST_TRACKED == 11)

-- out-of-zone & no quests -> travel step
TEST_QUESTS = {}
runTimers()
TEST_LEVEL, TEST_MAP = 12, 200 -- level 12 still standing in Durotar, no quests
fire("ZONE_CHANGED_NEW_AREA")
runTimers()
check("travel step", OG.target ~= nil and OG.target.kind == "zone")
check("travel to Azshara", OG.target ~= nil and OG.target.title == "Azshara")

-- auto accept / turn-in
fire("QUEST_DETAIL")
check("auto accept", called.accept == true)
fire("QUEST_COMPLETE")
check("auto reward", called.reward == true)

-- slash commands
SlashCmdList.OPTIGUIDE("auto")
check("slash toggles auto", OG.db.auto == false)
SlashCmdList.OPTIGUIDE("auto")
check("slash toggles back", OG.db.auto == true)
SlashCmdList.OPTIGUIDE("scale 1.5")
check("slash scale", OG.db.scale == 1.5)
SlashCmdList.OPTIGUIDE("route")
check("slash route off", OG.db.zoneRoute == false)
SlashCmdList.OPTIGUIDE("route")

-- arrow math: player facing north (0), target straight east -> arrow ~ -pi/2 or +pi/2
TEST_QUESTS = { { isHeader = false, isHidden = false, questID = 33, title = "East" } }
TEST_PX, TEST_PY = 0, 0
C_QuestLog.GetNextWaypoint = function() return 200, 0.5, 0.0 end -- due east (x+)
fire("QUEST_LOG_UPDATE")
runTimers()
check("east target", OG.target ~= nil and OG.target.kind == "quest")

-- retarget should never throw with empty log
TEST_QUESTS = {}
fire("QUEST_LOG_UPDATE")
runTimers()
check("empty log no crash", true)

print("RESULT " .. (FAIL == 0 and "ALL-PASS" or (FAIL .. " FAILED")))
__FAILED = FAIL
