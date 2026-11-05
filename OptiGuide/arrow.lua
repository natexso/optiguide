-- Waypoint arrow: rotates toward target, shows distance + objective text.
-- Bearing math: world x = east(+), y = north(+). Player facing is radians
-- CCW from north, so direction vector = (-sin f, cos f) and the target
-- angle from north satisfies atan2(-dx, dy). Rotation = target - facing.
local _, OG = ...

local frame = CreateFrame("Frame", "OptiGuideArrow", UIParent)
OG.arrowFrame = frame
frame:SetSize(90, 110)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(s) if not OG.db.locked then s:StartMoving() end end)
frame:SetScript("OnDragStop", function(s)
  s:StopMovingOrSizing()
  local p, _, rp, x, y = s:GetPoint()
  OG.db.arrowPoint = { p, UIParent, rp, x, y }
end)

local tex = frame:CreateTexture(nil, "ARTWORK")
tex:SetSize(48, 48)
tex:SetPoint("TOP", frame, "TOP", 0, 0)
tex:SetTexture("Interface\\MINIMAP\\MinimapArrow")

local dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dist:SetPoint("TOP", tex, "BOTTOM", 0, -2)
dist:SetText("")

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("TOP", dist, "BOTTOM", 0, -2)
label:SetWidth(160)
label:SetText("")

local elapsed = 0
frame:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.1 then return end
  elapsed = 0
  OG:RefreshArrow()
end)

function OG:RefreshArrow()
  local t = OG.target
  if not (OG.db and OG.db.arrow and t and t.wx) then
    frame:Hide()
    return
  end
  local px, py = OG:PlayerWorld()
  if not px then frame:Hide() return end
  local dx, dy = t.wx - px, t.wy - py
  local facing = GetPlayerFacing() or 0
  local angle = math.atan2(-dx, dy) - facing
  tex:SetRotation(-angle) -- SetRotation is CCW-positive; negate to match heading
  dist:SetFormattedText("%d yd", math.sqrt(dx * dx + dy * dy))
  label:SetText(t.title or "")
  frame:Show()
end

function OG:UpdateArrow()
  if not OG.arrowFrame then return end
  if OG.db and OG.db.arrow and OG.target and OG.target.wx then
    local p = OG.db.arrowPoint
    frame:ClearAllPoints()
    frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    frame:SetScale(OG.db.scale or 1)
    frame:Show()
    OG:RefreshArrow()
  else
    frame:Hide()
  end
end
