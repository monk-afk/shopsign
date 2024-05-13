local follow_market_cashflow = minetest.settings:get_bool("money_market_trends") and
        minetest.global_exists("money") == true

local shopsign = {}
local user = {}
local tmp = {}
local dir = {{x=0,y=0,z=-1},{x=-1,y=0,z=0},{x=0,y=0,z=1},{x=1,y=0,z=0}}
local dpos = {
  {{x=0.2,y=0.2,z=0},{x=-0.2,y=0.2,z=0},{x=0.2,y=-0.2,z=0},{x=-0.2,y=-0.2,z=0}},
  {{x=0,y=0.2,z=0.2},{x=0,y=0.2,z=-0.2},{x=0,y=-0.2,z=0.2},{x=0,y=-0.2,z=-0.2}},
  {{x=-0.2,y=0.2,z=0},{x=0.2,y=0.2,z=0},{x=-0.2,y=-0.2,z=0},{x=0.2,y=-0.2,z=0}},
  {{x=0,y=0.2,z=-0.2},{x=0,y=0.2,z=0.2},{x=0,y=-0.2,z=-0.2},{x=0,y=-0.2,z=0.2}}
}


minetest.register_craft({
	output = "shopsign:shop",
	recipe = {
		{"default:chest_locked",   "default:chest_locked",   "default:chest_locked"},
		{"default:sign_wall_wood", "default:chest_locked", "default:sign_wall_wood"},
		{"default:sign_wall_wood", "default:torch",        "default:sign_wall_wood"},
	}
})

minetest.register_craft({
	output = "shopsign:shop_metal",
	recipe = {
		{"default:chest_locked",    "default:chest_locked",    "default:chest_locked"},
		{"default:sign_wall_steel", "default:chest_locked", "default:sign_wall_steel"},
		{"default:sign_wall_steel", "default:torch",        "default:sign_wall_steel"},
	}
})

minetest.register_craft({
	output = "shopsign:display_case",
	recipe = {
		{"default:steel_ingot", "default:glass",        "default:steel_ingot"},
		{"default:glass",       "default:chest_locked",       "default:glass"},
		{"default:steel_ingot", "default:glass",        "default:steel_ingot"},
	}
})

local function is_creative(pname)
	return minetest.check_player_privs(pname, {creative=true}) or minetest.check_player_privs(pname, {give=true})
end

local update_info = function(pos)
	local meta=minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local owner=meta:get_string("owner")
	local gve=0

	if meta:get_int("type")==0 then
		meta:set_string("infotext","Admin Shop")
		return false
	end
	local name=""
	local count=0
	local stuff={}
	for i=1,4,1 do
		stuff["count" ..i]=inv:get_stack("give" .. i,1):get_count()
		stuff["name" ..i]=inv:get_stack("give" .. i,1):get_name()
		stuff["stock" ..i]=gve*stuff["count" ..i]
		stuff["buy" ..i]=0
		for ii=1,32,1 do
			name=inv:get_stack("main",ii):get_name()
			count=inv:get_stack("main",ii):get_count()
			if name==stuff["name" ..i] then
				stuff["stock" ..i]=stuff["stock" ..i]+count
			end
		end
		local nstr=(stuff["stock" ..i]/stuff["count" ..i]) ..""
		nstr=nstr.split(nstr, ".")
		stuff["buy" ..i]=tonumber(nstr[1])

		if stuff["name" ..i]=="" or stuff["buy" ..i]==0 then
			stuff["buy" ..i]=""
			stuff["name" ..i]=""
		else
			if string.find(stuff["name" ..i],":")~=nil then
				stuff["name" ..i]=stuff["name" ..i].split(stuff["name" ..i],":")[2]
			end
			stuff["buy" ..i]="(" ..stuff["buy" ..i] ..") "
			stuff["name" ..i]=stuff["name" ..i] .."\n"
		end
	end
		meta:set_string("infotext",
		owner .."'s Shop:\n"
		.. stuff.buy1 ..  stuff.name1
		.. stuff.buy2 ..  stuff.name2
		.. stuff.buy3 ..  stuff.name3
		.. stuff.buy4 ..  stuff.name4
		)
end

local update_entity = function(pos, stat)
--clear
	local spos=minetest.pos_to_string(pos)
	for _, ob in ipairs(minetest.get_objects_inside_radius(pos, 2)) do
		if ob and ob:get_luaentity() and ob:get_luaentity().shopsign and ob:get_luaentity().pos==spos then
			ob:remove()	
		end
	end
  
	if stat=="clear" then return end
--update
	local meta=minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local node=minetest.get_node(pos)
	local dp = dir[node.param2+1]
	if not dp then return end
	pos.x = pos.x + dp.x*0.01
	pos.y = pos.y + dp.y*6.5/16
	pos.z = pos.z + dp.z*0.01
	for i=1,4,1 do
		local item=inv:get_stack("give" .. i,1):get_name()
		local pos2=dpos[node.param2+1][i]
		if item~="" then
			tmp.item=item
			tmp.pos=spos
			local e = minetest.add_entity({x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z},"shopsign:item")
			e:set_yaw(math.pi*2 - node.param2 * math.pi/2)
		end
	end
end


local showform = function(pos,player,re)
	local meta=minetest.get_meta(pos)
	local creative=meta:get_int("creative")
	local inv = meta:get_inventory()
	local gui=""
	local spos=pos.x .. "," .. pos.y .. "," .. pos.z
	local uname=player:get_player_name()
	local owner=meta:get_string("owner")==uname
	if minetest.check_player_privs(uname, {protection_bypass=true}) then owner=true end
	if re then owner=false end
	user[uname]=pos
	if owner then
		if meta:get_int("type")==0 and not (minetest.check_player_privs(uname, {creative=true}) or minetest.check_player_privs(uname, {give=true})) then
			meta:set_int("creative",0)
			meta:set_int("type",1)
			creative=0
		end

		gui=""
		.."size[8,10]"

		.."button_exit[6,0;1.8,1;customer;Customer]"
		.."label[0,0.2;Sell:]"
		.."label[0,1.2;Price:]"
		.."list[nodemeta:" .. spos .. ";give1;1,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay1;1,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give2;2,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay2;2,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give3;3,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay3;3,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give4;4,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay4;4,1;1,1;]"

		if creative==1 then
			gui = gui .."button[6,1;2.2,1;toggle_unlimited;Toggle Limit]"
		end
		gui=gui
		.."list[nodemeta:" .. spos .. ";main;0,2;8,4;]"
		.."list[current_player;main;0,6.2;8,4;]"
		.."listring[nodemeta:" .. spos .. ";main]"
		.."listring[current_player;main]"
	else
		gui=""
		.."size[8,6]"
		.."list[current_player;main;0,2.2;8,4;]"
		.."label[0,0.2;Item:]"
		.."label[0,1.2;Price:]"
		.."list[nodemeta:" .. spos .. ";give1;2,0;1,1;]"
		.."item_image_button[2,1;1,1;".. inv:get_stack("pay1",1):get_name() ..";buy1;\n\n\b\b\b\b\b" .. inv:get_stack("pay1",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give2;3,0;1,1;]"
		.."item_image_button[3,1;1,1;".. inv:get_stack("pay2",1):get_name() ..";buy2;\n\n\b\b\b\b\b" .. inv:get_stack("pay2",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give3;4,0;1,1;]"
		.."item_image_button[4,1;1,1;".. inv:get_stack("pay3",1):get_name() ..";buy3;\n\n\b\b\b\b\b" .. inv:get_stack("pay3",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give4;5,0;1,1;]"
		.."item_image_button[5,1;1,1;".. inv:get_stack("pay4",1):get_name() ..";buy4;\n\n\b\b\b\b\b" .. inv:get_stack("pay4",1):get_count() .."]"
	end
	minetest.after((0.2), function(gui)
		return minetest.show_formspec(player:get_player_name(), "shopsign:showform",gui)
	end, gui)
end


local receive_fields = function(player, pressed)
		local pname = player:get_player_name()
		local pos = user[pname]
		if not pos then
			return
    end

		if pressed.customer then
			return showform(pos, player, true)

		elseif pressed.toggle_unlimited then
			local meta = minetest.get_meta(pos)
			if not is_creative(pname) then
				meta:set_int("type", 1)
				meta:set_int("creative", 0)
				minetest.chat_send_player(pname, "You are not allowed to make a creative shop!")
				return
			end

			local pname = player:get_player_name()
			if meta:get_int("type") == 0 then
				meta:set_int("type", 1)
				minetest.chat_send_player(pname, "Unlimited stock disabled")
			else
				meta:set_int("type", 0)
				minetest.chat_send_player(pname, "Unlimited stock enabled")
			end

		elseif not pressed.quit then
			local n = 1

			for i = 1, 4, 1 do
				n = i
				if pressed["buy" .. i] then break end
			end

			local meta=minetest.get_meta(pos)
			local type=meta:get_int("type")
			local sellall=meta:get_int("sellall")
			local inv=meta:get_inventory()
			local pinv=player:get_inventory()
			local pname=player:get_player_name()
			local check_storage

			if pressed["buy" .. n] then
				local name=inv:get_stack("give" .. n,1):get_name()
				local stack=name .." ".. inv:get_stack("give" .. n,1):get_count()
				local pay=inv:get_stack("pay" .. n,1):get_name() .." ".. inv:get_stack("pay" .. n,1):get_count()
				local stack_to_use="main"

				if name~="" then

					if not pinv:room_for_item("main", stack) then
						minetest.chat_send_player(pname, "Error: Your inventory is full, exchange aborted.")
						return
					elseif not pinv:contains_item("main", pay) then
						minetest.chat_send_player(pname, "Error: You dont have enough in your inventory to buy this, exchange aborted.")
						return
					elseif type==1 and inv:room_for_item("main", pay)==false then
						minetest.chat_send_player(pname, "Error: The owners stock is full, cant receive, exchange aborted.")
					else
						if inv:contains_item("main", stack) then
						elseif sellall==1 and inv:contains_item("give" .. n, stack) then
							stack_to_use="give" .. n
						else
							minetest.chat_send_player(pname, "Error: The owners stock is end.")
							check_storage=1
						end
						if not check_storage then
							for i=0,32,1 do
								if pinv:get_stack("main", i):get_name()==inv:get_stack("pay" .. n,1):get_name() and pinv:get_stack("main",i):get_wear()>0 then
									minetest.chat_send_player(pname, "Error: your item is used")
									return
								end
							end

							local rastack=inv:remove_item(stack_to_use, stack)
							pinv:remove_item("main", pay)
							pinv:add_item("main", rastack)

              local shopsign_owner = meta:get_string("owner")
              minetest.log("action", pname .." paid ".. pay.. " for " .. stack
                .. " from Shopsign owned by " .. shopsign_owner .. " at " .. minetest.pos_to_string(pos))

              if follow_market_trends then
                money_api.economic_indicator(pname, pay, stack, pos, shopsign_owner)
              end

							if type==1 then inv:add_item("main", pay) end
							if type==0 then inv:add_item("main", rastack) end
						end
					end
				end
			end
		else
			update_info(pos)
			update_entity(pos,"update")
			user[player:get_player_name()]=nil
		end
end

minetest.register_on_player_receive_fields(function(player, form, pressed)
	if form=="shopsign:showform" then
		receive_fields(player,pressed)
	end
end)


minetest.register_entity("shopsign:item",{
    hp_max = 100,
    visual="wielditem",
    visual_size={x=.20,y=.20},
    collisionbox = {0,0,0,0,0,0},
    physical=false,
    textures={"air"},
    shopsign=true,
    type="",
    immortal=true,

	on_activate = function(self, staticdata)
		if tmp.item ~= nil then
			self.item=tmp.item
			self.pos=tmp.pos
			tmp={}
		else
			if staticdata ~= nil and staticdata ~= "" then
				local data = staticdata:split(';')
				if data and data[1] and data[2] then
					self.item = data[1]
					self.pos = data[2]
				end
			end
		end
		if self.item ~= nil then
			self.object:set_properties({textures={self.item}})
		else
			self.object:remove()
		end
	end,
  on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
    minetest.log("action", "[shopsign] Player "..puncher:get_player_name().." punched shopsign entity")
      --[[
        someone damaged the shopsign entity, sometimes fatally, unsure what that does and am unable to replicate
          2024-04-25 06:11:27: ACTION[Server]: player (id=7371, hp=16) punched LuaEntitySAO "smartshop:item" at (-21,-15016,1184) (id=11717, hp=1), damage=0
          2024-04-25 06:11:27: ACTION[Server]: player (id=7371, hp=16) punched LuaEntitySAO "smartshop:item" at (-21,-15016,1184) (id=11718, hp=1), damage=0
          2024-04-25 06:11:27: ACTION[Server]: player (id=7371, hp=16) punched LuaEntitySAO "smartshop:item" at (-21,-15016,1184) (id=11717, hp=0), damage=1
          2024-04-25 06:11:27: ACTION[Server]: player (id=7371, hp=16) punched LuaEntitySAO "smartshop:item" at (-21,-15016,1184) (id=11718, hp=1), damage=0
      ]]
      return
  end,

	get_staticdata = function(self)
		if self.item ~= nil and self.pos ~= nil then
			return self.item .. ';' ..  self.pos
		end
		return ""
	end,
})


minetest.register_node("shopsign:shop", {
	description = "Wooden Shop Sign",
-- Textures of node; +Y(top), -Y(btm), +X(right), -X(left), +Z, -Z
	tiles = {
    "shopsign_wood_updn.png",
    "shopsign_wood_updn.png",
    "shopsign_wood_side.png",
    "shopsign_wood_side.png",
    "shopsign_wood_back.png",
    "shopsign_wood_face.png"},
	groups = {choppy = 1, oddly_breakable_by_hand = 1},
	drawtype="nodebox",
	node_box = {type="fixed",fixed={-0.5,-0.5,-0.0,0.5,0.5,0.5}},
	paramtype2="facedir",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 10,
after_place_node = function(pos, placer)
		local meta=minetest.get_meta(pos)
		meta:set_string("owner",placer:get_player_name())
		meta:set_string("infotext", "Shop by: " .. placer:get_player_name())
		meta:set_int("type",1)
		meta:set_int("sellall",1)

    if is_creative(placer:get_player_name()) then
			meta:set_int("creative",1)
			meta:set_int("type",0)
			meta:set_int("sellall",0)
		end
	end,
on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		meta:set_int("state", 0)
		meta:get_inventory():set_size("main", 32)
		meta:get_inventory():set_size("give1", 1)
		meta:get_inventory():set_size("pay1", 1)
		meta:get_inventory():set_size("give2", 1)
		meta:get_inventory():set_size("pay2", 1)
		meta:get_inventory():set_size("give3", 1)
		meta:get_inventory():set_size("pay3", 1)
		meta:get_inventory():set_size("give4", 1)
		meta:get_inventory():set_size("pay4", 1)
	end,
on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		showform(pos,player)
	end,
allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if stack:get_wear()==0 and (minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true})) then
		return stack:get_count()
		end
		return 0
	end,
allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
		return stack:get_count()
		end
		return 0
	end,
allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
		return count
		end
		return 0
	end,
can_dig = function(pos, player)
		local meta=minetest.get_meta(pos)
		local inv=meta:get_inventory()
    if ((meta:get_string("owner") == player:get_player_name()
        or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}))
          and inv:is_empty("main")
          and inv:is_empty("pay1")
          and inv:is_empty("pay2")
          and inv:is_empty("pay3")
          and inv:is_empty("pay4")
          and inv:is_empty("give1")
          and inv:is_empty("give2")
          and inv:is_empty("give3")
          and inv:is_empty("give4"))
        or meta:get_string("owner")=="" then
      update_entity(pos,"clear")
      return true		end
	end,
})



minetest.register_node("shopsign:shop_metal", {
	description = "Metal Shop Sign",
-- Textures of node; +Y(top), -Y(btm), +X(right), -X(left), +Z, -Z
	tiles = {
    "shopsign_metal_updn.png",
    "shopsign_metal_updn.png",
    "shopsign_metal_side.png",
    "shopsign_metal_side.png",
    "shopsign_metal_back.png",
    "shopsign_metal_face.png"},
	groups = {choppy = 1, oddly_breakable_by_hand = 1},
	drawtype="nodebox",
	node_box = {type="fixed",fixed={-0.5,-0.5,-0.0,0.5,0.5,0.5}},
	paramtype2="facedir",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 10,
after_place_node = function(pos, placer)
		local meta=minetest.get_meta(pos)
		meta:set_string("owner",placer:get_player_name())
		meta:set_string("infotext", "Shop by: " .. placer:get_player_name())
		meta:set_int("type",1)
		meta:set_int("sellall",1)
    if is_creative(placer:get_player_name()) then
			meta:set_int("creative",1)
			meta:set_int("type",0)
			meta:set_int("sellall",0)
		end
	end,
on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		meta:set_int("state", 0)
		meta:get_inventory():set_size("main", 32)
		meta:get_inventory():set_size("give1", 1)
		meta:get_inventory():set_size("pay1", 1)
		meta:get_inventory():set_size("give2", 1)
		meta:get_inventory():set_size("pay2", 1)
		meta:get_inventory():set_size("give3", 1)
		meta:get_inventory():set_size("pay3", 1)
		meta:get_inventory():set_size("give4", 1)
		meta:get_inventory():set_size("pay4", 1)
	end,
on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		showform(pos,player)
	end,
allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if stack:get_wear()==0 and (minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true})) then
		return stack:get_count()
		end
		return 0
	end,
allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
		return stack:get_count()
		end
		return 0
	end,
allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
		return count
		end
		return 0
	end,
can_dig = function(pos, player)
		local meta=minetest.get_meta(pos)
		local inv=meta:get_inventory()
    if ((meta:get_string("owner") == player:get_player_name()
        or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}))
          and inv:is_empty("main")
          and inv:is_empty("pay1")
          and inv:is_empty("pay2")
          and inv:is_empty("pay3")
          and inv:is_empty("pay4")
          and inv:is_empty("give1")
          and inv:is_empty("give2")
          and inv:is_empty("give3")
          and inv:is_empty("give4"))
        or meta:get_string("owner")=="" then
      update_entity(pos,"clear")
      return true
		end
	end,
})




minetest.register_node("shopsign:display_case", {
	description = "Shop Display Case",
	drawtype="glasslike_framed",
	paramtype = "light",
	paramtype2 = "glasslikeliquidlevel",
	legacy_wallmounted = true,
	legacy_facedir_simple = true,
	is_ground_content = false,
	sunlight_propagates = true,
	light_source = 7,
  use_texture_alpha = "blend",
	tiles = {
    {
      name = "shopsign_display_inner.png",
      backface_culling = true,
      scale = 1
    },
    {
      name = "shopsign_display_outer.png",
      backface_culling = false,
      scale = 1,
    },
  },

  special_tiles = {"shopsign_display_carpet.png"},
  -- backface_culling = false,
  -- scale = 1,
	groups = {choppy = 1, oddly_breakable_by_hand = 1},

  after_place_node = function(pos, placer)
    local newparam2 = minetest.dir_to_facedir(placer:get_look_dir())
		minetest.swap_node(pos, {name = "shopsign:display_case", param2 = newparam2})

    local meta=minetest.get_meta(pos)
    meta:set_string("owner",placer:get_player_name())
    meta:set_string("infotext", "Shop by: " .. placer:get_player_name())
    meta:set_int("type",1)
    meta:set_int("sellall",1)
    if is_creative(placer:get_player_name()) then
      meta:set_int("creative",1)
      meta:set_int("type",0)
      meta:set_int("sellall",0)
    end
  end,

  on_construct = function(pos)
    local meta=minetest.get_meta(pos)
    meta:set_int("state", 0)
    meta:get_inventory():set_size("main", 32)
    meta:get_inventory():set_size("give1", 1)
    meta:get_inventory():set_size("pay1", 1)
    meta:get_inventory():set_size("give2", 1)
    meta:get_inventory():set_size("pay2", 1)
    meta:get_inventory():set_size("give3", 1)
    meta:get_inventory():set_size("pay3", 1)
    meta:get_inventory():set_size("give4", 1)
    meta:get_inventory():set_size("pay4", 1)
  end,

  on_punch = function(pos, node, puncher, pointed_thing)
    if puncher:is_player() and
        minetest.get_meta(pos):get_string("owner") == puncher:get_player_name() then
      if node.param2 >= 3 then
        minetest.swap_node(pos, {name = "shopsign:display_case", param2 = 0})
      else
        minetest.swap_node(pos, {name = "shopsign:display_case", param2 = node.param2+1})
      end
      update_entity(pos,"update")
    end
  end,

  on_rightclick = function(pos, node, player, itemstack, pointed_thing)
    showform(pos,player)
  end,
  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    if stack:get_wear()==0 and (minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true})) then
    return stack:get_count()
    end
    return 0
  end,
  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
    return stack:get_count()
    end
    return 0
  end,
  allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
    return count
    end
    return 0
  end,
  can_dig = function(pos, player)
    local meta=minetest.get_meta(pos)
    local inv=meta:get_inventory()
    if ((meta:get_string("owner") == player:get_player_name()
        or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}))
          and inv:is_empty("main")
          and inv:is_empty("pay1")
          and inv:is_empty("pay2")
          and inv:is_empty("pay3")
          and inv:is_empty("pay4")
          and inv:is_empty("give1")
          and inv:is_empty("give2")
          and inv:is_empty("give3")
          and inv:is_empty("give4"))
        or meta:get_string("owner")=="" then
      update_entity(pos,"clear")
      return true
    end
  end,
})

--
minetest.register_alias("smartshop:shop", "shopsign:shop")