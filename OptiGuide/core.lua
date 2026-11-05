-- OptiGuide core: namespace, saved vars, event bus, slash commands.
local addonName, OG = ...
OG = OG or {}
OptiGuide = OG -- debug access

OG.defaults = {
  auto = true,           -- master auto accept/turn-in switch
  autoAccept = true,
  autoTurnin = true,
  autoGossip = true,
  arrow = true,          -- waypoint arrow visible
  panel = true,          -- guide panel visible
  zoneRoute = true,      -- steer to next-route zone when out of zone
  scale = 1.0,
  opacity = 1.0,         -- arrow opacity
  arrowProgress = true,  -- objective progress on arrow
  notify = true,         -- chat message on step change
  soundComplete = false, -- sound when objective/turn-in completes
  showXP = true,         -- XP/hour + ETA on panel
  showRested = true,     -- rested % on panel
  hideCombat = false,    -- hide arrow in combat
  hideInstance = true,   -- hide arrow in instances
  compact = false,       -- 1-line panel
  locked = false,
  arrowPoint = { "CENTER", UIParent, "CENTER", 0, 220 },
  panelPoint = { "TOPLEFT", UIParent, "TOPLEFT", 20, -120 },
}

local f = CreateFrame("Frame", "OptiGuideFrame", UIParent)
OG.frame = f
OG.events = {}

function OG:RegisterEvent(evt, fn)
  f:RegisterEvent(evt)
  OG.events[evt] = fn
end

f:SetScript("OnEvent", function(_, evt, ...)
  local fn = OG.events[evt]
  if fn then
    local ok, err = pcall(fn, ...)
    if not ok then
      geterrorhandler()(("OptiGuide %s: %s"):format(evt, err))
    end
  end
end)

function OG:InitDB()
  if not OptiGuideDB then OptiGuideDB = {} end
  if not OptiGuideCharDB then OptiGuideCharDB = {} end
  OG.db = OptiGuideDB
  for k, v in pairs(OG.defaults) do
    if OG.db[k] == nil then OG.db[k] = v end
  end
end

function OG:Print(...)
  local parts = { "|cff33ccffOptiGuide|r:" }
  for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
  DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
end

SLASH_OPTIGUIDE1 = "/og"
SLASH_OPTIGUIDE2 = "/optiguide"
SlashCmdList.OPTIGUIDE = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" or msg == "help" then
    OG:Print("commands: /og options | panel | arrow | auto | route | scale N | opacity N | next | prev | skip | notif | xp | compact | lock | unlock | step | reset")
  elseif msg == "options" or msg == "config" then
    if InterfaceOptionsFrame_OpenToCategory then
      pcall(InterfaceOptionsFrame_OpenToCategory, "OptiGuide")
      pcall(InterfaceOptionsFrame_OpenToCategory, "OptiGuide") -- retail needs it twice
    elseif Settings and Settings.OpenToCategory and OG.optionsCat then
      pcall(Settings.OpenToCategory, OG.optionsCat:GetID())
    else
      OG:Print("options panel unavailable - use /og commands")
    end
  elseif msg == "panel" then
    OG.db.panel = not OG.db.panel; OG:UpdatePanel()
  elseif msg == "arrow" then
    OG.db.arrow = not OG.db.arrow; OG:UpdateArrow()
  elseif msg == "auto" then
    OG.db.auto = not OG.db.auto
    OG:Print("auto accept/turn-in:", OG.db.auto and "ON" or "OFF")
  elseif msg == "route" then
    OG.db.zoneRoute = not OG.db.zoneRoute; OG:Retarget()
  elseif msg:match("^opacity") then
    local n = tonumber(msg:match("opacity%s+([%d%.]+)"))
    if n and n >= 0.2 and n <= 1 then
      OG.db.opacity = n
      if OG.arrowFrame then OG.arrowFrame:SetAlpha(n) end
      OG:Print("opacity", n)
    else OG:Print("usage: /og opacity 0.2-1") end
  elseif msg == "next" or msg == "prev" then
    OG:CycleWaypoint(msg == "next" and 1 or -1)
  elseif msg == "skip" then
    OG.target = nil; OG:Retarget(); OG:Print("step skipped")
  elseif msg == "notif" then
    OG.db.notify = not OG.db.notify; OG:Print("notifications", OG.db.notify and "ON" or "OFF")
  elseif msg == "xp" then
    OG.db.showXP = not OG.db.showXP; OG:UpdatePanel()
  elseif msg == "compact" then
    OG.db.compact = not OG.db.compact; OG:UpdatePanel()
  elseif msg:match("^scale") then
    local n = tonumber(msg:match("scale%s+([%d%.]+)"))
    if n and n >= 0.5 and n <= 3 then
      OG.db.scale = n
      if OG.arrowFrame then OG.arrowFrame:SetScale(n) end
      OG:Print("scale", n)
    else
      OG:Print("usage: /og scale 0.5-3")
    end
  elseif msg == "lock" then
    OG.db.locked = true; OG:Print("frames locked")
  elseif msg == "unlock" then
    OG.db.locked = false; OG:Print("frames unlocked - drag them")
  elseif msg == "step" then
    OG:Print(OG.currentStep or "no step")
  elseif msg == "reset" then
    wipe(OptiGuideDB); OG:InitDB(); ReloadUI()
  end
end
