local color = require("hollow.color")
local shared = require("hollow.ui.shared")
local hollow = _G.hollow
local state = require("hollow.state").get()
local ui = hollow.ui
local tbl = hollow.tbl
local util = hollow.util
local M = {}
function M.leader_state()
  local value = hollow.keymap.get_leader_state()
  return value and value.active and value or nil
end

function M.copy_mode_state()
  local value = state.copy_mode
  return value and value.active == true and value or nil
end

function M.quick_select_state()
  local value = state.quick_select
  return value and value.active == true and value or nil
end

local function special_mode_theme()
  local resolved = shared.resolve_theme().ui
  local all = resolved.widgets.all
  local base_bg = color.normalize_hex_color(all.panel_bg, resolved.top_bar.background)
  local mode_copy_bg =
    color.normalize_hex_color(color.brighten_hex_color(base_bg, 0.08, base_bg), base_bg)
  local mode_leader_bg =
    color.normalize_hex_color(color.darken_hex_color(base_bg, 0.04, base_bg), base_bg)
  local hint_key_bg =
    color.normalize_hex_color(color.brighten_hex_color(base_bg, 0.14, base_bg), base_bg)
  return {
    bg = color.normalize_hex_color(
      resolved.status and resolved.status.bg,
      resolved.top_bar.background
    ),
    fg = color.normalize_hex_color(resolved.status and resolved.status.fg, all.title),
    chip_bg = base_bg,
    chip_fg = color.normalize_hex_color(all.fg, resolved.status and resolved.status.fg),
    accent = color.normalize_hex_color(resolved.accent, all.title),
    muted = color.normalize_hex_color(all.muted, all.fg),
    divider = color.normalize_hex_color(all.divider, resolved.status and resolved.status.fg),
    counter = color.normalize_hex_color(all.counter, all.muted),
    copy_bg = mode_copy_bg,
    quick_select_bg = color.normalize_hex_color(
      color.brighten_hex_color(base_bg, 0.12, base_bg),
      base_bg
    ),
    leader_bg = mode_leader_bg,
    hint_key_bg = hint_key_bg,
  }
end

local function special_mode_chip(text, style)
  return ui.span(
    text,
    util.merge_tables(util.clone_value({
      bold = true,
      radius = 4,
      padding = { left = 2, right = 2, top = 1, bottom = 1 },
      margin = { right = 1 },
    }), style)
  )
end

local function special_mode_key(text, style)
  return ui.span(
    text,
    util.merge_tables(util.clone_value({
      bold = true,
      radius = 4,
      padding = { left = 1, right = 1, top = 0, bottom = 0 },
    }), style)
  )
end

local function special_mode_hint(key, label, theme)
  return {
    special_mode_key(key, {
      fg = theme.fg,
      bg = theme.hint_key_bg,
    }),
    ui.span(" " .. label .. " ", {
      fg = theme.muted,
    }),
  }
end

local function flatten_nodes(items)
  return tbl(items)
    :flat_map(function(item)
      if type(item) == "table" and item[1] ~= nil and item._type == nil then
        return item
      end
      return { item }
    end)
    :get()
end

local function copy_mode_search_chip(copy_mode, theme)
  local pieces = tbl({
    special_mode_key("/", {
      fg = theme.fg,
      bg = theme.hint_key_bg,
    }),
    ui.span(copy_mode.query ~= "" and copy_mode.query or "search", {
      fg = theme.chip_fg,
    }),
  })

  if copy_mode.match_count > 0 then
    pieces:concat({
      ui.span(string.format("  %d/%d", copy_mode.match_index or 0, copy_mode.match_count), {
        fg = theme.counter,
      }),
    })
  elseif copy_mode.query ~= "" then
    pieces:concat({
      ui.span("  0/0", {
        fg = theme.counter,
      }),
    })
  end

  if copy_mode.selecting then
    pieces:concat({
      ui.span(copy_mode.block and "  BLK" or "  SEL", {
        fg = theme.accent,
        bold = true,
      }),
    })
  end

  return ui.group(flatten_nodes(pieces:concat({ ui.span(" ") }):get()), {
    bg = theme.copy_bg,
    radius = 4,
    padding = { left = 2, right = 2, top = 1, bottom = 1 },
    margin = { right = 1 },
  })
end

local BAR_STYLES = { bar = true, overlay = true }

--- How the mode strip is presented: docked "bar" (default) or floating "overlay".
---@return "bar"|"overlay"
function M.style()
  local value = hollow.config.get("bottombar_style")
  return BAR_STYLES[value] and value or "bar"
end

local function leader_hints(leader, theme)
  if leader == nil or leader.next_display == nil or #leader.next_display == 0 then
    return {}
  end
  return tbl(leader.next_display)
    :map(function(item)
      local key, label = item:match("^([^:]+):(.+)$")
      return special_mode_hint(key or item, label or "", theme)
    end)
    :get()
end

--- Presentation-agnostic description of the active special mode, or nil when
--- none is active. `chips` and `legend.nodes` are already-styled span nodes; the
--- bar and overlay presenters below only decide how to lay them out.
---@param theme table
---@return table|nil
function M.mode_model(theme)
  local copy_mode = M.copy_mode_state()
  if copy_mode ~= nil then
    return {
      chips = {
        {
          id = "mode:copy",
          node = special_mode_chip(" COPY ", { bg = theme.copy_bg, fg = theme.accent }),
        },
        { id = "mode:search", node = copy_mode_search_chip(copy_mode, theme) },
      },
      legend = {
        id = "mode:copy-legend",
        nodes = flatten_nodes({
          special_mode_hint("h/j/k/l", "move", theme),
          special_mode_hint("gg/G", "ends", theme),
          special_mode_hint("v", "sel", theme),
          special_mode_hint("C-v", "blk", theme),
          special_mode_hint("n/N", "match", theme),
          special_mode_hint("y", "copy", theme),
          special_mode_hint("q", "exit", theme),
        }),
      },
    }
  end

  local quick_select = M.quick_select_state()
  if quick_select ~= nil then
    return {
      chips = {
        {
          id = "mode:quick-select",
          node = special_mode_chip(
            " QUICK SELECT ",
            { bg = theme.quick_select_bg, fg = theme.accent }
          ),
        },
        {
          id = "mode:quick-select-action",
          node = special_mode_chip(
            " " .. (quick_select.action == "copy" and "copy" or "open/copy") .. " ",
            { bg = theme.chip_bg, fg = theme.chip_fg }
          ),
        },
      },
      legend = {
        id = "mode:quick-select-legend",
        nodes = flatten_nodes({
          special_mode_hint("a-z", "choose", theme),
          special_mode_hint("Backspace", "undo", theme),
          special_mode_hint("Esc", "exit", theme),
        }),
      },
    }
  end

  local leader = M.leader_state()
  if leader ~= nil then
    local remaining_ms = math.max(0, tonumber(leader.remaining_ms) or 0)
    return {
      remaining_ms = remaining_ms,
      chips = {
        {
          id = "mode:leader",
          node = special_mode_chip(" LEADER ", { bg = theme.leader_bg, fg = theme.fg }),
        },
      },
      legend = {
        id = "mode:leader-legend",
        cache_ttl_ms = math.max(1, remaining_ms),
        nodes = flatten_nodes(leader_hints(leader, theme)),
      },
    }
  end

  return nil
end

---@param model table
---@return table[]
local function bar_items(model)
  local items = {}
  for _, chip in ipairs(model.chips) do
    items[#items + 1] = ui.bar.custom({
      id = chip.id,
      render = function()
        return chip.node
      end,
    })
  end
  items[#items + 1] = ui.spacer()
  items[#items + 1] = ui.bar.custom({
    id = model.legend.id,
    cache_ttl_ms = model.legend.cache_ttl_ms,
    render = function()
      return model.legend.nodes
    end,
  })
  return items
end

---@param model table|nil
local function overlay_row(model)
  if model == nil then
    return ui.row({})
  end
  local nodes = {}
  for _, chip in ipairs(model.chips) do
    nodes[#nodes + 1] = chip.node
  end
  for _, node in ipairs(model.legend.nodes) do
    nodes[#nodes + 1] = node
  end
  return ui.row(flatten_nodes(nodes))
end

local function overlay_options(theme)
  local user = hollow.config.get("bottombar_overlay")
  user = type(user) == "table" and user or {}
  local chrome = util.merge_tables(
    util.clone_value({
      bg = theme.bg,
      border = theme.divider,
      border_size = 1,
      radius = 4,
      padding = { left = 1, right = 1, top = 0, bottom = 0 },
    }),
    type(user.chrome) == "table" and user.chrome or {}
  )
  return {
    align = user.align or "bottom_center",
    chrome = shared.normalize_overlay_chrome(chrome),
  }
end

-- One floating widget serves every mode that is presented as an overlay. It
-- re-reads the mode state on each render, so only its lifetime is synced from
-- the bottombar render below.
local mode_overlay = { widget = nil }

local function sync_mode_overlay(model, theme)
  if model == nil then
    if mode_overlay.widget ~= nil then
      ui.overlay.remove(mode_overlay.widget)
      mode_overlay.widget = nil
    end
    return
  end

  if mode_overlay.widget == nil then
    local opts = overlay_options(theme)
    local widget
    widget = ui.overlay.new({
      align = opts.align,
      chrome = opts.chrome,
      render = function()
        return overlay_row(M.mode_model(special_mode_theme()))
      end,
      on_unmount = function()
        if mode_overlay.widget == widget then
          mode_overlay.widget = nil
        end
      end,
    })
    mode_overlay.widget = widget
    ui.overlay.push(widget)
  end

  -- Leader timeout is detected lazily by the keymap, so let the overlay expire
  -- on its own; every leader step re-syncs and pushes the deadline forward.
  mode_overlay.widget._expires_at = model.remaining_ms ~= nil
      and util.host_now_ms(state.host_api) + model.remaining_ms
    or nil
end

function M.widget()
  local theme = special_mode_theme()
  return ui.new_widget("bottombar", {
    height = shared.resolve_topbar_theme().height,
    style = { bg = theme.chip_bg },
    layout = {
      padding = { left = 1, right = 1, top = 0, bottom = 0 },
    },
    render = function()
      local model = M.mode_model(theme)
      local overlay = M.style() == "overlay"

      sync_mode_overlay(overlay and model or nil, theme)
      if model == nil or overlay then
        return {}
      end
      return bar_items(model)
    end,
  })
end

--- Partial configuration of the built-in bottombar (the counterpart of
--- `hollow.ui.topbar.configure`). Values are stored as ordinary config keys.
---@param opts { style?: "bar"|"overlay", overlay?: { align?: string, chrome?: table } }|nil
function M.configure(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("hollow.ui.bottombar.configure(opts) expects a table")
  end

  local values = {}
  if opts.style ~= nil then
    if not BAR_STYLES[opts.style] then
      error('hollow.ui.bottombar.configure: style must be "bar" or "overlay"')
    end
    values.bottombar_style = opts.style
  end
  if opts.overlay ~= nil then
    if type(opts.overlay) ~= "table" then
      error("hollow.ui.bottombar.configure: overlay must be a table")
    end
    values.bottombar_overlay = opts.overlay
  end

  if next(values) ~= nil then
    hollow.config.set(values)
  end
end

function M.visible_item_count(items)
  return tbl(items):count(function(item)
    return item.kind ~= "spacer"
  end)
end
return M
