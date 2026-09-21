Bridge = Bridge or {}

--[[
Populated by exactly one of bridge/frameworks/*_client.lua, chosen by
Config.Framework. Each framework file guards itself with
`if Config.Framework ~= 'xyz' then return end`, so exactly one
implementation registers its functions here.

Contract every framework file fulfils:
  Bridge.GetPlayerData()      -> table, framework player data (may be {})
  Bridge.Notify(msg, kind)    -> shows a client notification ('success'|'error'|'inform')
  Bridge.IsPlayerLoaded()     -> bool
]]
