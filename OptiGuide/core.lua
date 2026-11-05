-- OptiGuide core: namespace, saved vars, event bus, slash commands.
local addonName, OG = ...
OG = OG or {}
OptiGuide = OG -- debug access

OG.defaults = {
  auto = true,        -- auto accept / turn-in / single-gossip
  arrow = true,       -- waypoint arrow visible
  panel = true,       -- guide panel visible
  zoneRoute = true,   -- steer to next-route zone when out of zone
  scale = 1.0,
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
    OG:Print("commands: /og panel | arrow | auto | route | scale N | lock | unlock | step | reset")
  elseif msg == "panel" then
    OG.db.panel = not OG.db.panel; OG:UpdatePanel()
  elseif msg == "arrow" then
    OG.db.arrow = not OG.db.arrow; OG:UpdateArrow()
  elseif msg == "auto" then
    OG.db.auto = not OG.db.auto
    OG:Print("auto accept/turn-in:", OG.db.auto and "ON" or "OFF")
  elseif msg == "route" then
    OG.db.zoneRoute = not OG.db.zoneRoute; OG:Retarget()
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
