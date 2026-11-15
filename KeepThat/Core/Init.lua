local addonName, ns = ...

ns.name = addonName

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = getMetadata and getMetadata(addonName, "Version") or "unknown"
