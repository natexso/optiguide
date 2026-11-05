-- Guide panel: current step + route progress + next zone.
local _, OG = ...

local panel = CreateFrame("Frame", "OptiGuidePanel", UIParent, "BackdropTemplateMixin")
OG.panel = panel
panel:SetSize(280, 96)
panel:SetFrameStrata("MEDIUM")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(s) if not OG.db.locked then s:StartMoving() end end)
panel:SetScript("OnDragStop", function(s)
  s:StopMovingOrSizing()
  local p, _, rp, x, y = s:GetPoint()
  OG.db.panelPoint = { p, UIParent, rp, x, y }
end)
panel:SetBackdrop({
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0, 0, 0, 0.6)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 10, -8)
title:SetText("|cff33ccffOptiGuide|r")

local step = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
step:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
step:SetWidth(260)
step:SetJustifyH("LEFT")

local nextz = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nextz:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -6)
nextz:SetWidth(260)
nextz:SetJustifyH("LEFT")

local xp = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
xp:SetPoint("TOPLEFT", nextz, "BOTTOMLEFT", 0, -6)
xp:SetWidth(260)
xp:SetJustifyH("LEFT")

local info = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
info:SetPoint("TOPLEFT", xp, "BOTTOMLEFT", 0, -6)
info:SetText("/og help for commands")

-- XP/hour tracker -> level ETA
local xpStart, xpStartXP
local function XPLine()
  local parts = {}
  if OG.db.showXP and UnitXP and UnitXPMax then
    local now, max = UnitXP("player"), UnitXPMax("player")
    if not xpStart then xpStart, xpStartXP = GetTime(), now end
    local elapsed = GetTime() - xpStart
    local gained = now - xpStartXP
    if elapsed > 300 and gained > 0 then
      local xph = gained / elapsed * 3600
      local eta = (max - now) / xph * 3600
      parts[#parts + 1] = ("%.0f xp/hr, next lvl ~%dm"):format(xph, eta / 60)
    else
      parts[#parts + 1] = "xp/hr warming up..."
    end
  end
  if OG.db.showRested and GetXPExhaustion and UnitXPMax then
    local r = GetXPExhaustion()
    if r and r > 0 then
      parts[#parts + 1] = ("rested %.0f%%"):format(r / UnitXPMax("player") * 50)
    end
  end
  return table.concat(parts, " | ")
end

function OG:NextZoneLabel(level)
  for _, z in ipairs(OG.route) do
    if level < z.lo then return ("Next: %s at %d"):format(z.zone, z.lo) end
  end
  return "Route complete"
end

function OG:UpdatePanel()
  if not OG.panel then return end
  if OG.db and OG.db.panel then
    local p = OG.db.panelPoint
    panel:ClearAllPoints()
    panel:SetPoint(p[1], p[2], p[3], p[4], p[5])
    step:SetText(OG.currentStep or "...")
    if OG.db.compact then
      nextz:SetText("")
      xp:SetText("")
      info:SetText("")
      panel:SetHeight(52)
    else
      local lvl = UnitLevel("player") or 1
      nextz:SetText(OG:NextZoneLabel(lvl))
      xp:SetText(XPLine())
      info:SetText("/og help for commands")
      panel:SetHeight(96)
    end
    panel:Show()
  else
    panel:Hide()
  end
end

OG:RegisterEvent("PLAYER_XP_UPDATE", function() OG:UpdatePanel() end)
