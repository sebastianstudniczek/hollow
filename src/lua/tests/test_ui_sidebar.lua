package.path = "src/lua/?.lua;src/lua/?/init.lua;src/lua/?.lua;" .. package.path
local harness = require("tests.harness")

describe("UI sidebar test suite", function()
  local env
  local hollow
  local recorded

  local function new_sidebar()
    return hollow.ui.sidebar.new({
      width = 30,
      reserve = true,
      render = function()
        return hollow.ui.column({})
      end,
    })
  end

  setup(function()
    env = harness.boot()
    hollow = env.hollow
    recorded = env.recorded
  end)

  -- The host caches the sidebar's reserved inset and only drops the cache on a
  -- layout request. Without one, hiding the sidebar removed the widget but left
  -- the panes at their old width, so the freed columns stayed blank until some
  -- unrelated tab/pane operation refreshed the layout.
  describe("layout refresh", function()
    it("is requested when the sidebar is mounted", function()
      local before = recorded.layout_refreshes
      hollow.ui.sidebar.mount(new_sidebar())
      harness.assert_equal(
        recorded.layout_refreshes,
        before + 1,
        "mounting a sidebar should ask the host to re-lay out the panes"
      )
    end)

    it("is requested when the sidebar is hidden and shown again", function()
      local before = recorded.layout_refreshes

      harness.assert_equal(hollow.ui.sidebar.toggle(), false, "first toggle should hide the sidebar")
      harness.assert_equal(
        recorded.layout_refreshes,
        before + 1,
        "hiding the sidebar should reclaim its columns immediately"
      )

      harness.assert_equal(hollow.ui.sidebar.toggle(), true, "second toggle should show the sidebar")
      harness.assert_equal(
        recorded.layout_refreshes,
        before + 2,
        "showing the sidebar should reserve its columns immediately"
      )
    end)

    it("is requested when the sidebar is unmounted", function()
      local before = recorded.layout_refreshes
      hollow.ui.sidebar.unmount()
      harness.assert_equal(
        recorded.layout_refreshes,
        before + 1,
        "unmounting the sidebar should reclaim its columns immediately"
      )
    end)

    it("is not requested when there is nothing to toggle", function()
      local before = recorded.layout_refreshes
      harness.assert_equal(hollow.ui.sidebar.toggle(), false, "toggle without a sidebar reports hidden")
      harness.assert_equal(
        recorded.layout_refreshes,
        before,
        "toggling with no sidebar mounted changes no layout"
      )
    end)

    it("tolerates a host without request_layout_refresh", function()
      local host_api = require("hollow.state").get().host_api
      local original = host_api.request_layout_refresh
      host_api.request_layout_refresh = nil

      local ok, err = pcall(function()
        hollow.ui.sidebar.mount(new_sidebar())
        hollow.ui.sidebar.toggle()
        hollow.ui.sidebar.unmount()
      end)
      host_api.request_layout_refresh = original

      harness.assert_true(ok, "sidebar should still work on a host lacking the hook: " .. tostring(err))
    end)
  end)
end)
