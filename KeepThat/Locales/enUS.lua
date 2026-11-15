-- Player-facing text. English is the key: L["Some sentence"] returns "Some sentence" unless a
-- locale file loaded after this one has assigned a translation. A missing entry never errors.
local _, ns = ...

ns.L = setmetatable({}, { __index = function(_, key) return key end })
