if SC and SC._data.sc_ai_toggle or restoration and restoration.Options:GetValue("SC/SC") then

	-- Extends the UnitNetworkHandler class to add our own unit network calls
	-- For function modifications use the original function name it will be prefixed later
	-- RestorationMod__UnitNetworkHandler = RestorationMod__UnitNetworkHandler or class(UnitNetworkHandler)

	-- Will add a prefix of `RestorationMod__` to all functions our definitions use
	-- Required to maintain compatibility with normal lobbies.
	-- restoration:rename_handler_funcs(RestorationMod__UnitNetworkHandler)
	
	local orig_sync_player = UnitNetworkHandler.sync_player_movement_state
	function UnitNetworkHandler:sync_player_movement_state(unit, state, down_time, unit_id_str,...) --i can't reverse engineer RPC stuff and make my own unitnetworkhandler functions so... guess i'll die
	--instead, hijack this function. use "unit", since i can't/don't know how to pass a unit through BLT Lua Networking, and argument "state" as string of my choice, and the other fields i don't care about. 
	--todo see if i can pass the current time for better repair sync?
		if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
			return
		end
	--	PrintTable({unit,state,down_time,unit_id_str})
		if alive(unit) then --receive repair update status from host
			if state == "start_repair_eq_sentry" then --repair start/finish are controlled by host only, naturally
				unit:base():start_repairmode()
				return
			elseif state == "finish_repair_eq_sentry" then 
				unit:base():finish_repairmode()
				return
			end
		end
		return orig_sync_player(self,unit,state,down_time,unit_id_str,...)
	end

	function UnitNetworkHandler:picked_up_sentry_gun(unit, rpc)
		local peer = self._verify_sender(rpc)

		if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
			return
		end

		if alive(unit) then --receive client interaction request as host
			if unit:character_damage():dead() then --on received sentry interaction request -> repair
				local sentry_type = unit:base():get_type()
				local sentry_type_index = sentry_type == "sentry_gun" and 1 or sentry_type == "sentry_gun_silent" and 2

				unit:base():start_repairmode()
			else --on received sentry interaction request -> pick up
				local sentry_type = unit:base():get_type()
				local sentry_type_index = sentry_type == "sentry_gun" and 1 or sentry_type == "sentry_gun_silent" and 2

				managers.network:session():send_to_peer(peer, "picked_up_sentry_gun_response", unit:id(), unit:weapon():ammo_total(), unit:weapon():ammo_max(), sentry_type_index)
				unit:base():remove()
			end
		end
	end

	function UnitNetworkHandler:action_spooc_start(unit, target_u_pos, flying_strike, action_id)
		if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
			return
		end

		local action_desc = {
			block_type = "walk",
			type = "spooc",
			path_index = 1,
			body_part = 1,
			nav_path = {
				unit:position()
			},
			target_u_pos = target_u_pos,
			flying_strike = flying_strike,
			action_id = action_id,
			blocks = {
				act = -1,
				turn = -1,
				walk = -1
			}
		}

		if flying_strike then
			action_desc.blocks.idle = -1
			action_desc.blocks.light_hurt = -1
			action_desc.blocks.heavy_hurt = -1
			action_desc.blocks.fire_hurt = -1
			action_desc.blocks.hurt = -1
			action_desc.blocks.expl_hurt = -1
			action_desc.blocks.taser_tased = -1
		end

		unit:movement():action_request(action_desc)
	end

	function UnitNetworkHandler:action_aim_state(unit, state)
		if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
			return
		end

		if state then
			local shoot_action = {
				block_type = "action",
				body_part = 3,
				type = "shoot"
			}

			unit:movement():action_request(shoot_action)
		else
			unit:movement():sync_action_aim_end()
		end
	end
	-- function UnitNetworkHandler:place_grenade_crate(pos, rot, rpc)
	-- 	local peer = self._verify_sender(rpc)
	
	-- 	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
	-- 		return
	-- 	end
	
	-- 	if not managers.player:verify_equipment(peer:id(), "grenade_crate") then
	-- 		return
	-- 	end
	
	-- 	local unit = GrenadeCrateBase.spawn(pos, rot, peer:id())
	
	-- 	if unit then
	-- 		unit:base():set_server_information(peer:id())
	-- 	end
	-- end

	function UnitNetworkHandler:sync_add_doted_enemy(enemy_unit, variant, weapon_unit, dot_length, dot_damage, user_unit, is_molotov_or_hurt_animation, rpc)
		if variant == 0 then
			managers.fire:sync_add_fire_dot(enemy_unit, nil, weapon_unit, dot_length, dot_damage, user_unit, is_molotov_or_hurt_animation)
		else
			if variant == 1 then
				variant = "poison"
			elseif variant == 2 then
				variant = "dot"
			else
				variant = nil
			end

			if weapon_unit and alive(weapon_unit) and weapon_unit:base() then
				if weapon_unit:base().is_husk_player then
					local peer_id = managers.network:session():peer_by_unit(weapon_unit):id()
					local peer = managers.network:session():peer(peer_id)

					weapon_unit = peer:melee_id()
				else
					weapon_unit = weapon_unit:base().melee_weapon and weapon_unit:base():melee_weapon() or weapon_unit

					if weapon_unit == "weapon" then
						weapon_unit = nil
					end
				end
			end

			managers.dot:sync_add_dot_damage(enemy_unit, variant, weapon_unit, dot_length, dot_damage, user_unit, is_molotov_or_hurt_animation, variant, weapon_id)
		end
	end
end
