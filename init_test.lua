-- Load testing framework
lu = require('luaunit')

-- Mock global 'dump'
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Reproduce strings:trim()
-- Ref: https://github.com/ronoaldo/minetest/blob/master/builtin/common/misc_helpers.lua#L206
function string:trim()
	return (self:gsub("^%s*(.-)%s*$", "%1"))
end

-- Mock desired settings per testing
_SETTINGS = {}

-- Mock minetest global namespace
minetest = {
    get_modpath = function() return "./" end,
    get_current_modname = function() return "minecaptcha" end,
    settings = {
        get = function(self, k) if _SETTINGS[k] then return _SETTINGS[k] else return nil end end,
        get_bool = function(self, k) if _SETTINGS[k] then return _SETTINGS[k] else return nil end end,
    },
    string_to_privs = function() return end,
    log = function(level, msg) print("    ", level, msg) end,
    register_on_newplayer = function() return end,
    register_on_leaveplayer = function() return end,
    register_on_joinplayer = function() return end,
    register_on_player_receive_fields = function() return end,
    is_mock_server = true,
}

-- Mock minetest pseudo random
PcgRandom = function()
    return { next = function(min, max) return min + (max - min / 2) end }
end

-- TestSuite: configuration options
TestCfg = {}
    function TestCfg:testWithBypassSingleUser()
        _SETTINGS["minecaptcha.bypass_users"] = "user1"
        local mod = dofile('init.lua')
        lu.assertEquals(mod.cfg.bypass_users["user1"], true)
    end

    function TestCfg:testWithBypassTwoUsers()
        _SETTINGS["minecaptcha.bypass_users"] = "user1,user2"
        local mod = dofile('init.lua')
        lu.assertEquals(mod.cfg.bypass_users["user1"], true)
        lu.assertEquals(mod.cfg.bypass_users["user2"], true)
    end

    function TestCfg:testNoRanksModWithConfig()
        _SETTINGS["minecaptcha.bypass_ranks"] = "rank1"
        local mod = dofile('init.lua')
        lu.assertIsNil(mod.cfg.bypass_ranks)
    end

    function TestCfg:testNoRanksModWithTwoRanksInConfig()
        _SETTINGS["minecaptcha.bypass_ranks"] = "rank1,rank2"
        local mod = dofile('init.lua')
        lu.assertIsNil(mod.cfg.bypass_ranks)
    end

    function TestCfg:testWithDefaults()
        local mod = dofile('init.lua')
        lu.assertItemsEquals(mod.cfg.bypass_users, {})
        lu.assertIsNil(mod.cfg.bypass_ranks)
    end

    function TestCfg:tearDown()
        _SETTINGS = {}
    end

    function TestCfg:setUp()
        print()
        minetest.log("server", "Minetest Mock Server starting ...")
    end

lu.LuaUnit:run()