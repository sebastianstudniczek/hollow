local hollow = _G.hollow
local state = require("hollow.state").get()
local ui = hollow.ui
local shared = require("hollow.ui.shared")
local widget_core = require("hollow.ui.widgets.core")
local M = {}

-- Showing, hiding or swapping the sidebar changes how much of the window the
-- panes get, so the host has to re-resolve the sidebar's reserved inset and
-- resize the panes to match.
--
-- The host caches that inset (App.cached_sidebar_layout) and only drops the
-- cache on a resize or a layout request. The top/bottom bars signal this
-- through bar_cache.sync_host, whose visibility changes call
-- requestLayoutRefresh, but the sidebar has no cache surface and used to
-- signal nothing. A toggle therefore flipped `sidebar_visible` and the
-- widget vanished, while the panes kept their old width and the freed
-- columns stayed blank until an unrelated tab/pane/workspace operation
-- happened to refresh the layout (e.g. running a command in a new pane).
local function request_layout_refresh()
  if type(state.host_api) == "table" and type(state.host_api.request_layout_refresh) == "function" then
    state.host_api.request_layout_refresh()
  end
end

function M.install()
  ui.sidebar = ui.sidebar or {}

  function ui.sidebar.new(opts)
    return ui.new_widget("sidebar", opts)
  end

  function ui.sidebar.mount(widget)
    widget_core.unmount_widget(state.ui.mounted_sidebar)
    state.ui.mounted_sidebar = widget
    state.ui.sidebar_visible = widget.hidden ~= true
    widget_core.mount_widget(widget)
    request_layout_refresh()
  end
  function ui.sidebar.unmount()
    widget_core.unmount_widget(state.ui.mounted_sidebar)
    state.ui.mounted_sidebar = nil
    state.ui.sidebar_visible = false
    request_layout_refresh()
  end

  function ui.sidebar.toggle()
    if not state.ui.mounted_sidebar then
      return false
    end
    state.ui.sidebar_visible = not state.ui.sidebar_visible
    request_layout_refresh()
    return state.ui.sidebar_visible
  end

  function ui._sidebar_state()
    local widget = state.ui.mounted_sidebar
    if not widget or not state.ui.sidebar_visible then
      return nil
    end

    local width = math.max(1, math.floor(tonumber(widget.width) or 24))
    local rows = {}
    for index, row in ipairs(shared.render_widget_rows(widget)) do
      rows[index] = ui.trim_row_for_width(row, width)
    end

    return {
      side = widget.side == "right" and "right" or "left",
      width = width,
      reserve = widget.reserve == true,
      rows = rows,
    }
  end
end
return M
