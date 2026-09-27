--!nonstrict
-- Service registry. Main.server fills this table so modules can call each other
-- without circular requires: S.Combat.hit(...), S.State.profile(player), ...
local S: any = {}
return S
