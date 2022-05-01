-- Simple captcha mod for Minetest.

-- Helper globals
local DIR = minetest.get_modpath(minetest.get_current_modname())

-- Imports
local PPM = dofile(DIR.."/ppm.lua")

-- Informational log
--local function I(msg) minetest.log("info", "[MOD]minecaptcha: "..msg) end
local function I(msg) minetest.log("[MOD]minecaptcha: "..msg) end
--local function D(msg) minetest.log("verbose", "[MOD]minecaptcha: "..msg) end
local function D(msg) minetest.log("[MOD]minecaptcha: "..msg) end
local function E(msg) minetest.log("error", "[MOD]minecaptcha: "..msg) end

-- Global colors as bytes
local FORM_NAME = "captcha"
local rng = PcgRandom(os.time())

-- Settings
local cfg = {
	-- Enabled triggers
	on_joinplayer = minetest.settings:get_bool("minecaptcha.on_joinplayer") or false,
	on_newplayer = minetest.settings:get_bool("minecaptcha.on_newplayer") or true,
	-- Enabled actions
	on_newplayer_remove_accounts = minetest.settings:get_bool("minecaptcha.on_newplayer_remove_accounts") or true,
	enable_ban = minetest.settings:get_bool("minecaptcha.enable_ban") or false,
	-- Before and after privs
	privs_during = minetest.settings:get("minecaptcha.privs_during_captcha") or "",
	privs_after = minetest.settings:get("minecaptcha.privs_on_success") or "",
	-- Time limit before kicking player
	time_limit = tonumber(minetest.settings:get("minecaptcha.time_limit") or 300)
}

-- Ranks settings
-- Using this method, lua will validate all conditions are nonzero and non-nil and set the variable to the result of the last expression
local ranks = minetest.settings:get_bool("minecaptcha.use_ranks") and minetest.get_modpath("ranks") and ranks

if ranks then
	I("Ranks detected and support enabled!")
	if cfg.privs_during == "" then
		ranks.register("minecaptcha_none", {
			strict_privs = true,
			revoke_extra = true,
			privs = {}
		})
		cfg.privs_during = "minecaptcha_none"
	end
	cfg.bypass_ranks = {}
	local bypass = minetest.settings:get("minecaptcha.bypass_ranks")
	if bypass ~= "" then
		for str in string.gmatch(bypass, "([^,]+)") do
			cfg.bypass_ranks[string.trim(str)] = true
		end
	end
else
	if cfg.privs_during then cfg.privs_during = minetest.string_to_privs(cfg.privs_during) end
	if cfg.privs_after then cfg.privs_after = minetest.string_to_privs(cfg.privs_after) end
end

-- Split bypass_users
cfg.bypass_users = {}
local bypass = minetest.settings:get("minecaptcha.bypass_users") or ""
if bypass ~= "" then
	for str in string.gmatch(bypass, "([^,]+)") do
		cfg.bypass_users[string.trim(str)] = true
	end
end


I("Loaded settings: "..dump(cfg))

-- If privs_after is empty then we need to store privs/rank while waiting for captcha verifications

local player_privs
if cfg.privs_after == "" then
	D("Creating table to hold player privs during captcha verifications")
	player_privs = {}
end

-- Load basic number textures
local numbers = {}
for i=0, 9 do
	numbers[i] = PPM.read(DIR.."/ppm-textures/"..i..".ppm")
end
D("Loaded "..#numbers.." numeric textures.")

-- Generates a random captcha image
local function new_captcha()
	-- Let's grab random numbers first
	local n1 = rng:next(0,9)
	local n2 = rng:next(0,9)
	local n3 = rng:next(0,9)
	local n4 = rng:next(0,9)
	D("Creating captcha n1="..n1..", n2="..n2..", n3="..n3..", n4="..n4)
	-- Record the response for current challenge
	local response = n1..""..n2..""..n3..""..n4
	-- Creates a small in-memory captcha
	local canvas = PPM.new(32, 14)
	PPM.draw(numbers[n1], canvas, 3, 1)
	PPM.draw(numbers[n2], canvas, 2, 8)
	PPM.draw(numbers[n3], canvas, 3, 16)
	PPM.draw(numbers[n4], canvas, 2, 22)
	-- TODO(ronoaldo): add some random noise the the image, like a blur effect
	-- Render the challenge as PNG
	local data = PPM.pixel_array(canvas)
--	local png = minetest.encode_png(32, 14, data)
--	local png64 = minetest.encode_base64(png)
	local texture = "blank.bmp"
	------------------------- REMOVE THIS ------------------------
	minetest.chat_send_all(tostring(response))
	--------------------------------------------------------------
	return response, texture
end

-- Sends a text message to the player
local function show_message_to_player(player, msg)
	minetest.chat_send_player(player:get_player_name(), "[minecaptcha] "..msg)
end

-- Sends an error message to the player
local function show_error_to_player(player, msg)
	show_message_to_player(player, minetest.colorize("#F00", msg))
end

-- Sends a success message to the player
local function show_success_to_player(player, msg)
	show_message_to_player(player, minetest.colorize("#0F0", msg))
end

local challenges = {}

-- Callback to execute when a new player joins the game.
local function show_captcha_to_player(player)
	local name = player:get_player_name()
	local texture
	-- Save the challenges and send the texture inline as a small PNG file.
	challenges[name], texture = new_captcha()
	D("Generated new captcha for player "..name.." texture => "..texture)
	show_message_to_player(player, "Are you a robot? Solve the captcha before interacting with the server.")
	local fs = "formspec_version[5]"
		.."size[8,4]"
		.."image[0.6,0.9;1.6,1.6;"..texture.."]"
		.."field[2.5,1.3;5.2,1.2;captcha_solution;Type the numbers:;]"
		.."button[5.5,2.9;2.2,0.9;captcha_send;Send]"
	minetest.show_formspec(name, FORM_NAME, fs)
end

local function validate_storage(name, i)
	if minetest.get_player_ip(name) == nil then
		player_privs[name] = nil
	else
		if i < 30 then	-- Give up after 300 seconds
			minetest.after(10, validate_storage, i+1)
		end
	end
end

local function manage_privileges(name, enable)
	D("managing privs for "..name)
	if ranks then
		D("using ranks, enable is "..tostring(enable))
		if enable then
			if player_privs and player_privs[name] then
				ranks.set_rank(name, player_privs[name])
				player_privs[name] = nil
			else
				ranks.set_rank(name, cfg.privs_after)
			end
		else
			if player_privs then
				player_privs[name] = ranks.get_rank(name)
				minetest.after(10, validate_storage, 0)
			end
			ranks.set_rank(name, cfg.privs_during)
		end
	else
		D("without ranks, enable is "..tostring(enable))
		if enable then
			if player_privs and player_privs[name] then
				minetest.set_player_privs(name, player_privs[name])
				player_privs[name] = nil
			else
				minetest.set_player_privs(name, cfg.privs_after)
			end
		else
			if player_privs then
				player_privs[name] = minetest.get_player_privs(name)
				minetest.after(10, validate_storage, 0)
			end
			minetest.set_player_privs(name, cfg.privs_during)
		end
	end

--[[	local managed_privs = minetest.string_to_privs(cfg.managed_privs)
	D("Managed privs: "..cfg.managed_privs.. " enabling? "..dump(enable))
	local player_privs = minetest.get_player_privs(name)
	D("Current privs"..dump(player_privs))
	local need_to_set = false
	for k, v in pairs(managed_privs) do
		if enable then
			if not player_privs[k] then
				D("> Granting "..k)
				player_privs[k] = true
				need_to_set = true
			end
		else
			if player_privs[k] then
				D("> Revoking "..k)
				player_privs[k] = nil
				need_to_set = true
			end
		end
	end
	if need_to_set then
		D("Updating player privs (privs changed) ...")
		minetest.set_player_privs(name, player_privs)
		D("Managed privs revoked")
	end]]
end

-- Callback to execute when a form is submited, parsing the captcha response.
local function on_form_submit(player, formname, fields)
	if formname ~= FORM_NAME then return end

	local name = player:get_player_name()
	local solution = fields["captcha_solution"] or ""

	I("Parsing captcha response from "..name..": "..minetest.write_json(fields))
	if solution ~= challenges[name] then
		I("Player "..name.." sent an invalid solution: "..solution)
		show_error_to_player(player, "The numbers are wrong!")
		show_captcha_to_player(player)
	else
		I("Player "..name.." sent a valid solution: "..solution)
		D("Setting player privs")
		manage_privileges(name, true)
		D("Cleaning up server variables")
		player:get_meta():set_int("captcha_solved", 1)
		challenges[name] = nil
		show_success_to_player(player, "You entered the correct numbers!")
		minetest.close_formspec(name, FORM_NAME)
	end

	return true
end


local function on_joinplayer(player, is_new)

	if not player then return end
	local name = player:get_player_name()

	D("Player "..name.." joined")
	D("Checking for name in bypass_users")
	if cfg.bypass_users and cfg.bypass_users[name] then return end
	if ranks and cfg.bypass_ranks then
		local user_rank = ranks.get_rank(name)
		if cfg.bypass_ranks[user_rank] then return end
	end

	local meta = player:get_meta()
	if is_new then meta:set_int("captcha_newplayer", 1) end

	if cfg.on_joinplayer or (meta:get_int("captcha_newplayer") == 1 and meta:get_int("captcha_solved") ~= 1) then
		D("Revoking privileges")
		manage_privileges(name, false)
		meta:set_int("captcha_solved", 0)
	end

	if cfg.time_limit then minetest.after(cfg.time_limit, function(name)
			local player = minetest.get_player_by_name(name)
			local m = player:get_meta()
			if meta:get_int("captcha_solved") == 0 then
				if cfg.enable_ban then
					minetest.ban_player(name)
				else
					minetest.kick_player(name, "Failed to complete captcha")
				end
				-- Copied this here because I don't know if using minetest.kick_player will call on_leaveplayer
				if cfg.on_newplayer and cfg.on_newplayer_remove_accounts and
						meta:get_int("captcha_newplayer") then
					I("Removing new player account who hasn't solved the captcha: '"..name.."'")
					local res = minetest.remove_player(name)
						I("Player account '"..name.."' removal result: "..dump(res))
				end
			end
		end, name)	-- need to pass name to it after defining the function
	end
	show_captcha_to_player(player)
end

local function on_leaveplayer(player)
	if not player then return end
	local name = player:get_player_name()
	D("Player "..name.." is leaving, running checks")
	if player_privs then player_privs[name] = nil end
	local m = player:get_meta()
	D("Player meta: "..dump(m:to_table()))
	if m:get_int("captcha_solved") == 0 then
		if cfg.on_newplayer and cfg.on_newplayer_remove_accounts then
			D("Checking if we need to remove the account")
			if m:get_int("captcha_newplayer") == 1 then
				I("Removing new player account who hasn't solved the captcha: '"..name.."'")
--				minetest.after(1, function()
				   local res = minetest.remove_player(name)
					I("Player account '"..name.."' removal result: "..dump(res))
--				end)
			end
		elseif cfg.enable_ban and (cfg.on_joinplayer or cfg.on_newplayer) then
			D("Captcha not solved, banning player")
			if not minetest.ban_player(name) then
				-- Maybe add support here for other ban mods?
				-- I don't know if they use the builtin ban methods so this may already be complete?
				D("Failed to ban player")
			end
		end
	end
end

-- Register callbacks
if cfg.on_newplayer then
	D("Inserting into minetest.registered_on_newplayer")
	minetest.register_on_newplayer(function(player) on_joinplayer(player, true) end)
end
if cfg.on_joinplayer then
	D("Inserting into minetest.registered_on_joinplayer")
	minetest.register_on_joinplayer(function(player) on_joinplayer(player, false) end)
end
minetest.register_on_leaveplayer(on_leaveplayer)
minetest.register_on_player_receive_fields(on_form_submit)

-- We're done, show up on server logs.
I("Mod loaded")
