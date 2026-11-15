-- Picks the running client's data. Each TOC loads only its own Data/*_Era.lua or Data/*_Forever.lua
-- files, so whichever catalog is present tells us the client; nothing else needs to tell them apart.
local _, ns = ...

local D = ns.Data or {}
ns.Data = D
D.Catalog = D.Catalog_Era or D.Catalog_Forever
D.Routes = D.Routes_Era or D.Routes_Forever
ns.client = D.Catalog and D.Catalog.client or nil
