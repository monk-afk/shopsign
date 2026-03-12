local shopsign = {}
local player_positions = {}
local facing_dirs = {{x = 0, y = 0, z = -1}, {x = -1, y = 0, z = 0}, {x = 0, y = 0, z = 1}, {x = 1, y = 0, z = 0}}
local display_offsets = {
  {{x = 0.2, y = 0.2, z = 0}, {x = -0.2, y = 0.2, z = 0}, {x = 0.2, y = -0.2, z = 0}, {x = -0.2, y = -0.2, z = 0}},
  {{x = 0, y = 0.2, z = 0.2}, {x = 0, y = 0.2, z = -0.2}, {x = 0, y = -0.2, z = 0.2}, {x = 0, y = -0.2, z = -0.2}},
  {{x = -0.2, y = 0.2, z = 0}, {x = 0.2, y = 0.2, z = 0}, {x = -0.2, y = -0.2, z = 0}, {x = 0.2, y = -0.2, z = 0}},
  {{x = 0, y = 0.2, z = -0.2}, {x = 0, y = 0.2, z = 0.2}, {x = 0, y = -0.2, z = -0.2}, {x = 0, y = -0.2, z = 0.2}}
}

core.register_craft({
  output = "shopsign:shop",
  recipe = {
    {"default:chest_locked",   "default:chest_locked",   "default:chest_locked"},
    {"default:sign_wall_wood", "default:chest_locked", "default:sign_wall_wood"},
    {"default:sign_wall_wood", "default:torch",        "default:sign_wall_wood"},
  }
})

core.register_craft({
  output = "shopsign:shop_metal",
  recipe = {
    {"default:chest_locked",    "default:chest_locked",    "default:chest_locked"},
    {"default:sign_wall_steel", "default:chest_locked", "default:sign_wall_steel"},
    {"default:sign_wall_steel", "default:torch",        "default:sign_wall_steel"},
  }
})

core.register_craft({
  output = "shopsign:display_case",
  recipe = {
    {"default:steel_ingot", "default:glass",        "default:steel_ingot"},
    {"default:glass",       "default:chest_locked",       "default:glass"},
    {"default:steel_ingot", "default:glass",        "default:steel_ingot"},
  }
})

local function is_creative(player_name)
  return core.check_player_privs(player_name, {creative = true}) or core.check_player_privs(player_name, {give = true})
end

local function update_info(pos)
  local shop_meta = core.get_meta(pos)

  if shop_meta:get_int("type") == 0 then
    shop_meta:set_string("infotext", "Admin Shop")
    return
  end

  local shop_inventory = shop_meta:get_inventory()
  local shop_owner = shop_meta:get_string("owner")
  local base_stock = 0
  local stack_name = ""
  local stack_count = 0
  local stock_info = {}

  for i = 1, 4, 1 do
    stock_info["count" .. i] = shop_inventory:get_stack("give" .. i, 1):get_count()
    stock_info["name" .. i] = shop_inventory:get_stack("give" .. i, 1):get_name()
    stock_info["stock" .. i] = base_stock * stock_info["count" .. i]
    stock_info["buy" .. i] = 0

		if stock_info["name" .. i] == "" or stock_info["count" .. i] == 0 then
			stock_info["buy" .. i] = ""
			stock_info["name" .. i] = ""
		else
      for ii = 1, 32, 1 do
        stack_name = shop_inventory:get_stack("main", ii):get_name()
        stack_count = shop_inventory:get_stack("main", ii):get_count()

        if stack_name == stock_info["name" .. i] then
          stock_info["stock" .. i] = stock_info["stock" .. i] + stack_count
        end
      end

			stock_info["buy" .. i] = math.floor(stock_info["stock" .. i] / stock_info["count" .. i])

      if string.find(stock_info["name" .. i], ":") ~= nil then
        stock_info["name" .. i] = stock_info["name" .. i].split(stock_info["name" .. i], ":")[2]
      end

      stock_info["buy" .. i] = "(" .. stock_info["buy" .. i] .. ") "
      stock_info["name" .. i] = stock_info["name" .. i] .. "\n"
    end
  end
  shop_meta:set_string("infotext", ("%s's Shop:\n%s%s%s%s%s%s%s%s"):format(
      shop_owner, stock_info.buy1, stock_info.name1,
      stock_info.buy2, stock_info.name2,
      stock_info.buy3, stock_info.name3,
      stock_info.buy4, stock_info.name4
    )
  )
end

local function update_entity(pos, stat)
  local shop_pos_string = core.pos_to_string(pos)
  for _, ob in ipairs(core.get_objects_inside_radius(pos, 2)) do
    if ob and ob:get_luaentity() and
        ob:get_luaentity().shopsign and
        ob:get_luaentity().pos == shop_pos_string then
      ob:remove()
    end
  end

  if stat == "clear" then return end

  local shop_meta = core.get_meta(pos)
  local shop_inventory = shop_meta:get_inventory()
  local shop_node = core.get_node(pos)
  local facing_offset = facing_dirs[shop_node.param2 + 1]

  if not facing_offset then return end

  local entity_base_pos = {
    x = pos.x + facing_offset.x * 0.01,
    y = pos.y + facing_offset.y * 6.5/16,
    z = pos.z + facing_offset.z * 0.01
  }

  for i = 1, 4, 1 do
    local display_item = shop_inventory:get_stack("give" .. i, 1):get_name()
    local display_offset = display_offsets[shop_node.param2 + 1][i]

    if display_item ~= "" then
      local display_entity = core.add_entity({
          x = entity_base_pos.x + display_offset.x,
          y = entity_base_pos.y + display_offset.y,
          z = entity_base_pos.z + display_offset.z
        }, "shopsign:item", display_item .. ";" .. shop_pos_string
      )

      if display_entity then
        display_entity:set_yaw(math.pi * 2 - shop_node.param2 * math.pi/2)
      end
    end
  end
end

local function showform(pos, player, force_customer_view)
  local shop_meta = core.get_meta(pos)
  local creative = shop_meta:get_int("creative")
  local shop_inventory = shop_meta:get_inventory()
  local formspec = ""
  local shop_pos_string = pos.x .. ", " .. pos.y .. ", " .. pos.z
  local player_name = player:get_player_name()
  local is_owner = shop_meta:get_string("owner") == player_name

  if core.check_player_privs(player_name, {protection_bypass = true}) then
    is_owner = true
  end

  if force_customer_view then
    is_owner = false
  end

  player_positions[player_name] = pos

  if is_owner then
    if shop_meta:get_int("type") == 0 and not (
        core.check_player_privs(player_name, {creative = true}) or
        core.check_player_privs(player_name, {give = true})
      ) then

      shop_meta:set_int("creative", 0)
      shop_meta:set_int("type", 1)
      creative = 0
    end

    formspec = "size[8,10]"
      .. "button_exit[6,0;1.8,1;customer;Customer]"
      .. "label[0,0.2;Sell:]"
      .. "label[0,1.2;Price:]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give1;1,0;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";pay1;1,1;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give2;2,0;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";pay2;2,1;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give3;3,0;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";pay3;3,1;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give4;4,0;1,1;]"
      .. "list[nodemeta:" .. shop_pos_string .. ";pay4;4,1;1,1;]"

    if creative == 1 then
      formspec = formspec .. "button[6,1;2.2,1;toggle_unlimited;Toggle Limit]"
    end

    formspec = formspec
      .. "list[nodemeta:" .. shop_pos_string .. ";main;0,2;8,4;]"
      .. "list[current_player;main;0,6.2;8,4;]"
      .. "listring[nodemeta:" .. shop_pos_string .. ";main]"
      .. "listring[current_player;main]"
  else
    formspec = "size[8,6]"
      .. "list[current_player;main;0,2.2;8,4;]"
      .. "label[0,0.2;Item:]"
      .. "label[0,1.2;Price:]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give1;2,0;1,1;]"
      .. "item_image_button[2,1;1,1;" .. shop_inventory:get_stack("pay1", 1):get_name() .. ";buy1;\n\n\b\b\b\b\b" .. shop_inventory:get_stack("pay1", 1):get_count() .. "]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give2;3,0;1,1;]"
      .. "item_image_button[3,1;1,1;" .. shop_inventory:get_stack("pay2", 1):get_name() .. ";buy2;\n\n\b\b\b\b\b" .. shop_inventory:get_stack("pay2", 1):get_count() .. "]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give3;4,0;1,1;]"
      .. "item_image_button[4,1;1,1;" .. shop_inventory:get_stack("pay3", 1):get_name() .. ";buy3;\n\n\b\b\b\b\b" .. shop_inventory:get_stack("pay3", 1):get_count() .. "]"
      .. "list[nodemeta:" .. shop_pos_string .. ";give4;5,0;1,1;]"
      .. "item_image_button[5,1;1,1;" .. shop_inventory:get_stack("pay4", 1):get_name() .. ";buy4;\n\n\b\b\b\b\b" .. shop_inventory:get_stack("pay4", 1):get_count() .. "]"
  end
  core.after((0.2), function(formspec)
    return core.show_formspec(player:get_player_name(), "shopsign:showform", formspec)
  end, formspec)
end

local function allow_shop_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
  if not player then return 0 end

  local player_name = player:get_player_name()
  local shop_owner = core.get_meta(pos):get_string("owner")

  if shop_owner == player_name or
      core.check_player_privs(player_name, {protection_bypass = true}) then
    return math.min(count, 99)
  end

  return 0
end

local function receive_fields(player, pressed)
  local player_name = player:get_player_name()
  local shop_pos = player_positions[player_name]

  if not shop_pos then return end

  if pressed.customer then
    return showform(shop_pos, player, true)

  elseif pressed.toggle_unlimited then
    local shop_meta = core.get_meta(shop_pos)

    if not is_creative(player_name) then
      shop_meta:set_int("type", 1)
      shop_meta:set_int("creative", 0)
      core.chat_send_player(player_name, "You are not allowed to make a creative shop!")
      return
    end

    local player_name = player:get_player_name()

    if shop_meta:get_int("type") == 0 then
      shop_meta:set_int("type", 1)
      core.chat_send_player(player_name, "Unlimited stock disabled")
    else
      shop_meta:set_int("type", 0)
      core.chat_send_player(player_name, "Unlimited stock enabled")
    end

  elseif not pressed.quit then
    local offer_index

    for i = 1, 4 do
      offer_index = i

      if pressed["buy" .. i] then break end
    end

    local shop_meta = core.get_meta(shop_pos)
    local shop_type = shop_meta:get_int("type")
    local shop_inventory = shop_meta:get_inventory()
    local player_inventory = player:get_inventory()
    local player_name = player:get_player_name()
    local out_of_stock

    if pressed["buy" .. offer_index] then
      local item_name = shop_inventory:get_stack("give" .. offer_index, 1):get_name()
      local item_stack = item_name .. " " .. shop_inventory:get_stack("give" .. offer_index, 1):get_count()
      local price_stack = shop_inventory:get_stack("pay" .. offer_index, 1):get_name() .. " " .. shop_inventory:get_stack("pay" .. offer_index, 1):get_count()
      local shop_stack_source = "main"

      if item_name ~= "" then
        if not player_inventory:room_for_item("main", item_stack) then
          core.chat_send_player(player_name, "Error: Your inventory is full, exchange aborted.")
          return

        elseif not player_inventory:contains_item("main", price_stack) then
          core.chat_send_player(player_name, "Error: You dont have enough in your inventory to buy this, exchange aborted.")
          return

        elseif shop_type == 1 and shop_inventory:room_for_item("main", price_stack) == false then
          core.chat_send_player(player_name, "Error: The owners stock is full, cant receive, exchange aborted.")
          return

        else
          if shop_inventory:contains_item("main", item_stack) then

          elseif shop_type == 0 then
            shop_stack_source = nil

          else
            core.chat_send_player(player_name, "Error: The owners stock is end.")
            out_of_stock = 1
          end

          if not out_of_stock then
            for i = 1, 32, 1 do
              if player_inventory:get_stack("main", i):get_name() == shop_inventory:get_stack("pay" .. offer_index, 1):get_name()
                  and player_inventory:get_stack("main", i):get_wear() > 0 then
                core.chat_send_player(player_name, "Error: your item is used")
                return
              end
            end

            if shop_type == 0 then
              player_inventory:remove_item("main", price_stack)
              player_inventory:add_item("main", item_stack)
            else
              local removed_stack = shop_inventory:remove_item(shop_stack_source, item_stack)
              player_inventory:remove_item("main", price_stack)
              player_inventory:add_item("main", removed_stack)
              shop_inventory:add_item("main", price_stack)
            end

            local shopsign_owner = shop_meta:get_string("owner")
              core.log("action", player_name .. " paid " .. price_stack .. " for " .. item_stack
                .. " from Shopsign owned by " .. shopsign_owner .. " at " .. core.pos_to_string(shop_pos))
          end
        end
      end
    end
  else
    update_info(shop_pos)
    update_entity(shop_pos, "update")
    player_positions[player:get_player_name()] = nil
  end
end

core.register_on_player_receive_fields(function(player, form, pressed)
  if form == "shopsign:showform" then
    receive_fields(player, pressed)
  end
end)


core.register_entity("shopsign:item", {
  hp_max = 100,
  visual = "wielditem",
  visual_size = { x = 0.20 , y = 0.20},
  collisionbox = {0, 0, 0, 0, 0, 0},
  physical = false,
  textures = {"air"},
  shopsign = true,
  type = "",
  immortal = true,

  on_activate = function(self, staticdata)
    if staticdata ~= nil and staticdata ~= "" then
      local data = staticdata:split(';')
      if data and data[1] and data[2] then
        self.item = data[1]
        self.pos = data[2]
      end
    end
    if self.item ~= nil then
      self.object:set_properties({textures = {self.item}})
    else
      self.object:remove()
    end
  end,

  on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, punch_direction, damage)
    core.log("action", "[shopsign] Player " .. puncher:get_player_name() .. " punched shopsign entity")
    return
  end,

  get_staticdata = function(self)
    if self.item ~= nil and self.pos ~= nil then
      return self.item .. ';' ..  self.pos
    end
    return ""
  end,
})

core.register_node("shopsign:shop", {
  description = "Wooden Shop Sign",
  tiles = {
    "shopsign_wood_updn.png",
    "shopsign_wood_updn.png",
    "shopsign_wood_side.png",
    "shopsign_wood_side.png",
    "shopsign_wood_back.png",
    "shopsign_wood_face.png"},
  groups = {choppy = 1, oddly_breakable_by_hand = 1},
  drawtype = "nodebox",
  node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.0, 0.5, 0.5, 0.5}},
  paramtype2 = "facedir",
  paramtype = "light",
  sunlight_propagates = true,
  light_source = 10,

  after_place_node = function(pos, placer)
      local shop_meta = core.get_meta(pos)
      local placer_name = placer:get_player_name()
      shop_meta:set_string("owner", placer_name)
      shop_meta:set_string("infotext", "Shop by: " .. placer_name)
      shop_meta:set_int("type", 1)

      if is_creative(placer_name) then
        shop_meta:set_int("creative", 1)
        shop_meta:set_int("type", 0)
    end
  end,

  on_construct = function(pos)
      local shop_meta = core.get_meta(pos)
      shop_meta:set_int("state", 0)
      shop_meta:get_inventory():set_size("main", 32)
      shop_meta:get_inventory():set_size("give1", 1)
      shop_meta:get_inventory():set_size("pay1", 1)
      shop_meta:get_inventory():set_size("give2", 1)
      shop_meta:get_inventory():set_size("pay2", 1)
      shop_meta:get_inventory():set_size("give3", 1)
      shop_meta:get_inventory():set_size("pay3", 1)
      shop_meta:get_inventory():set_size("give4", 1)
      shop_meta:get_inventory():set_size("pay4", 1)
  end,

  on_rightclick = function(pos, node, player, itemstack, pointed_thing)
    showform(pos, player)
  end,

  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    if stack:get_wear() == 0 and (core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true})) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    if core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

    allow_metadata_inventory_move = allow_shop_inventory_move,

  on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    local shop_meta = core.get_meta(pos)
    local shop_owner = shop_meta:get_string("owner")

    local shop_inventory = shop_meta:get_inventory()
    local from_stack = shop_inventory:get_stack(from_list, from_index)
    local to_stack = shop_inventory:get_stack(to_list, to_index)
    core.log("action", player:get_player_name() ..
        " moves " .. from_stack:get_name() .. " " .. from_stack:get_count() .. " " .. from_list ..
        " to " .. to_stack:get_name() .. " " .. to_stack:get_count() .. " " .. to_list ..
          " inside Shopsign owned by " .. shop_owner .. " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_put = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
      " puts " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
      " into slot " .. listname ..
        " in Shopsign owned by " .. shop_owner ..
      " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_take = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
      " takes " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
      " from slot " .. listname ..
        " from Shopsign owned by " .. shop_owner ..
      " at " .. core.pos_to_string(pos))
  end,

  can_dig = function(pos, player)
      local shop_meta = core.get_meta(pos)
      local shop_inventory = shop_meta:get_inventory()
      if ((shop_meta:get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}))
            and shop_inventory:is_empty("main")
            and shop_inventory:is_empty("pay1")
            and shop_inventory:is_empty("pay2")
            and shop_inventory:is_empty("pay3")
            and shop_inventory:is_empty("pay4")
            and shop_inventory:is_empty("give1")
            and shop_inventory:is_empty("give2")
            and shop_inventory:is_empty("give3")
            and shop_inventory:is_empty("give4"))
          or shop_meta:get_string("owner") == "" then
      update_entity(pos, "clear")
      return true
    end
  end,
})


core.register_node("shopsign:shop_metal", {
  description = "Metal Shop Sign",
  tiles = {
    "shopsign_metal_updn.png",
    "shopsign_metal_updn.png",
    "shopsign_metal_side.png",
    "shopsign_metal_side.png",
    "shopsign_metal_back.png",
    "shopsign_metal_face.png"},
  groups = {choppy = 1, oddly_breakable_by_hand = 1},
  drawtype = "nodebox",
  node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.0, 0.5, 0.5, 0.5}},
  paramtype2 = "facedir",
  paramtype = "light",
  sunlight_propagates = true,
  light_source = 10,

  after_place_node = function(pos, placer)
      local shop_meta = core.get_meta(pos)
      local placer_name = placer:get_player_name()
      shop_meta:set_string("owner", placer_name)
      shop_meta:set_string("infotext", "Shop by: " .. placer_name)
      shop_meta:set_int("type", 1)
      if is_creative(placer_name) then
        shop_meta:set_int("creative", 1)
        shop_meta:set_int("type", 0)
    end
  end,

  on_construct = function(pos)
      local shop_meta = core.get_meta(pos)
      shop_meta:set_int("state", 0)
      shop_meta:get_inventory():set_size("main", 32)
      shop_meta:get_inventory():set_size("give1", 1)
      shop_meta:get_inventory():set_size("pay1", 1)
      shop_meta:get_inventory():set_size("give2", 1)
      shop_meta:get_inventory():set_size("pay2", 1)
      shop_meta:get_inventory():set_size("give3", 1)
      shop_meta:get_inventory():set_size("pay3", 1)
      shop_meta:get_inventory():set_size("give4", 1)
      shop_meta:get_inventory():set_size("pay4", 1)
  end,

  on_rightclick = function(pos, node, player, itemstack, pointed_thing)
    showform(pos, player)
  end,

  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    if stack:get_wear() == 0 and (core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true})) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    if core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

    allow_metadata_inventory_move = allow_shop_inventory_move,

  on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")

      local shop_inventory = shop_meta:get_inventory()
      local from_stack = shop_inventory:get_stack(from_list, from_index)
      local to_stack = shop_inventory:get_stack(to_list, to_index)
    core.log("action", player:get_player_name() ..
        " moves " .. from_stack:get_name() .. " " .. from_stack:get_count() .. " " .. from_list ..
        " to " .. to_stack:get_name() .. " " .. to_stack:get_count() .. " " .. to_list ..
          " inside Shopsign owned by " .. shop_owner .. " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_put = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
        " puts " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
        " into slot " .. listname ..
          " in Shopsign owned by " .. shop_owner ..
        " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_take = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
        " takes " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
        " from slot " .. listname ..
          " from Shopsign owned by " .. shop_owner ..
        " at " .. core.pos_to_string(pos))
  end,

  can_dig = function(pos, player)
      local shop_meta = core.get_meta(pos)
      local shop_inventory = shop_meta:get_inventory()
      if ((shop_meta:get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}))
            and shop_inventory:is_empty("main")
            and shop_inventory:is_empty("pay1")
            and shop_inventory:is_empty("pay2")
            and shop_inventory:is_empty("pay3")
            and shop_inventory:is_empty("pay4")
            and shop_inventory:is_empty("give1")
            and shop_inventory:is_empty("give2")
            and shop_inventory:is_empty("give3")
            and shop_inventory:is_empty("give4"))
          or shop_meta:get_string("owner") == "" then
      update_entity(pos, "clear")
      return true
    end
  end,
})


core.register_node("shopsign:display_case", {
  description = "Shop Display Case",
  drawtype = "glasslike_framed",
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
  groups = {choppy = 1, oddly_breakable_by_hand = 1},

  after_place_node = function(pos, placer)
    local newparam2 = core.dir_to_facedir(placer:get_look_dir())
    core.swap_node(pos, {name = "shopsign:display_case", param2 = newparam2})

      local shop_meta = core.get_meta(pos)
      local placer_name = placer:get_player_name()
      shop_meta:set_string("owner", placer_name)
      shop_meta:set_string("infotext", "Shop by: " .. placer_name)
      shop_meta:set_int("type", 1)
      if is_creative(placer_name) then
        shop_meta:set_int("creative", 1)
        shop_meta:set_int("type", 0)
    end
  end,

  on_construct = function(pos)
      local shop_meta = core.get_meta(pos)
      shop_meta:set_int("state", 0)
      shop_meta:get_inventory():set_size("main", 32)
      shop_meta:get_inventory():set_size("give1", 1)
      shop_meta:get_inventory():set_size("pay1", 1)
      shop_meta:get_inventory():set_size("give2", 1)
      shop_meta:get_inventory():set_size("pay2", 1)
      shop_meta:get_inventory():set_size("give3", 1)
      shop_meta:get_inventory():set_size("pay3", 1)
      shop_meta:get_inventory():set_size("give4", 1)
      shop_meta:get_inventory():set_size("pay4", 1)
  end,

  on_punch = function(pos, node, puncher, pointed_thing)
    if puncher:is_player() and
        core.get_meta(pos):get_string("owner") == puncher:get_player_name() then
      if node.param2 >= 3 then
        core.swap_node(pos, {name = "shopsign:display_case", param2 = 0})
      else
        core.swap_node(pos, {name = "shopsign:display_case", param2 = node.param2 + 1})
      end
      update_entity(pos, "update")
    end
  end,

  on_rightclick = function(pos, node, player, itemstack, pointed_thing)
    showform(pos, player)
  end,

  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    if stack:get_wear() == 0 and (core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true})) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    if core.get_meta(pos):get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}) then
      stack:set_count(math.min(stack:get_count(), 99))
      return stack:get_count()
    end
    return 0
  end,

    allow_metadata_inventory_move = allow_shop_inventory_move,

  on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")

      local shop_inventory = shop_meta:get_inventory()
      local from_stack = shop_inventory:get_stack(from_list, from_index)
      local to_stack = shop_inventory:get_stack(to_list, to_index)
    core.log("action", player:get_player_name() ..
        " moves " .. from_stack:get_name() .. " " .. from_stack:get_count() .. " " .. from_list ..
        " to " .. to_stack:get_name() .. " " .. to_stack:get_count() .. " " .. to_list ..
          " inside Shopsign owned by " .. shop_owner .. " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_put = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
        " puts " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
        " into slot " .. listname ..
          " in Shopsign owned by " .. shop_owner ..
        " at " .. core.pos_to_string(pos))
  end,

  on_metadata_inventory_take = function(pos, listname, index, itemstack, player)
      local shop_meta = core.get_meta(pos)
      local shop_owner = shop_meta:get_string("owner")
    core.log("action", player:get_player_name() ..
        " takes " .. itemstack:get_name() .. " " .. itemstack:get_count() ..
        " from slot " .. listname ..
          " from Shopsign owned by " .. shop_owner ..
        " at " .. core.pos_to_string(pos))
  end,

  can_dig = function(pos, player)
      local shop_meta = core.get_meta(pos)
      local shop_inventory = shop_meta:get_inventory()
      if ((shop_meta:get_string("owner") == player:get_player_name()
        or core.check_player_privs(player:get_player_name(), {protection_bypass = true}))
            and shop_inventory:is_empty("main")
            and shop_inventory:is_empty("pay1")
            and shop_inventory:is_empty("pay2")
            and shop_inventory:is_empty("pay3")
            and shop_inventory:is_empty("pay4")
            and shop_inventory:is_empty("give1")
            and shop_inventory:is_empty("give2")
            and shop_inventory:is_empty("give3")
            and shop_inventory:is_empty("give4"))
          or shop_meta:get_string("owner") == "" then
      update_entity(pos, "clear")
      return true
    end
  end,
})


core.register_alias("smartshop:shop", "shopsign:shop")
