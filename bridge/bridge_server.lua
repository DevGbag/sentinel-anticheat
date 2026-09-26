Bridge = Bridge or {}

--[[
Populated by exactly one of bridge/frameworks/*_server.lua, chosen by
Config.Framework. Each framework file guards itself with
`if Config.Framework ~= 'xyz' then return end`, so exactly one
implementation registers its functions here.

Framework export/native names are based on each project's commonly
documented API as of this writing. Frameworks change their exports
over time, so if `Bridge.AddItem` reports failure for every item on
your server, check your installed framework version's exports against
the matching file in bridge/frameworks/ and adjust.

Contract every framework file fulfils:
  Bridge.GetItemList()                  -> { [itemName] = { label = str, weapon = bool }, ... }
  Bridge.AddItem(src, itemName, count)  -> bool success[, string reason] (reason optional, e.g. 'weight' | 'slots')
  Bridge.RemoveItem(src, itemName, count) -> bool success
  Bridge.AddMoney(src, amount, account) -> bool success
  Bridge.GetPlayerName(src)             -> string
  Bridge.IsPlayerLoaded(src)            -> bool
]]
