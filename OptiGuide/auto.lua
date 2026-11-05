-- Auto accept / turn-in / single-option gossip. All calls guarded so a
-- missing API on this client degrades to manual play instead of errors.
local _, OG = ...

local function ok(...)
  return OG.db and OG.db.auto and not InCombatLockdown()
end
local function on(key)
  return OG.db and OG.db.auto and OG.db[key] ~= false and not InCombatLockdown()
end

OG:RegisterEvent("GOSSIP_SHOW", function()
  if not on("autoGossip") then return end
  local nAvail = (C_GossipInfo.GetNumAvailableQuests and C_GossipInfo.GetNumAvailableQuests())
              or (GetNumGossipAvailableQuests and GetNumGossipAvailableQuests()) or 0
  local nAct = (C_GossipInfo.GetNumActiveQuests and C_GossipInfo.GetNumActiveQuests())
            or (GetNumGossipActiveQuests and GetNumGossipActiveQuests()) or 0
  if nAvail == 1 and nAct == 0 then
    if C_GossipInfo.SelectAvailableQuest then C_GossipInfo.SelectAvailableQuest(1)
    elseif SelectGossipAvailableQuest then SelectGossipAvailableQuest(1) end
  elseif nAct == 1 and nAvail == 0 then
    if C_GossipInfo.SelectActiveQuest then C_GossipInfo.SelectActiveQuest(1)
    elseif SelectGossipActiveQuest then SelectGossipActiveQuest(1) end
  else
    local opts = (C_GossipInfo.GetOptions and C_GossipInfo.GetOptions())
              or (GetGossipOptions and { GetGossipOptions() }) or {}
    local n = C_GossipInfo.GetOptions and #opts or (#opts / 2)
    if n == 1 and nAvail == 0 and nAct == 0 then
      if C_GossipInfo.SelectOption then C_GossipInfo.SelectOption(1)
      elseif SelectGossipOption then SelectGossipOption(1) end
    end
  end
end)

OG:RegisterEvent("QUEST_GREETING", function()
  if not on("autoAccept") and not on("autoTurnin") then return end
  local na, nc = GetNumAvailableQuests() or 0, GetNumActiveQuests() or 0
  if nc > 0 and on("autoTurnin") then SelectActiveQuest(1)
  elseif na == 1 and on("autoAccept") then SelectAvailableQuest(1) end
end)

OG:RegisterEvent("QUEST_DETAIL", function()
  if on("autoAccept") and AcceptQuest then AcceptQuest() end
end)

OG:RegisterEvent("QUEST_PROGRESS", function()
  if on("autoTurnin") and IsQuestCompletable and IsQuestCompletable() and ContinueQuest then
    ContinueQuest()
  end
end)

OG:RegisterEvent("QUEST_COMPLETE", function()
  if not on("autoTurnin") then return end
  local n = (GetNumQuestChoices and GetNumQuestChoices()) or 0
  if n <= 1 and GetQuestReward then
    GetQuestReward(n == 1 and 1 or nil)
  elseif CompleteQuest then
    CompleteQuest() -- multi-choice rewards stay manual
  end
end)
