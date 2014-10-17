-- Hydra main config
-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu (or press cmd-alt-ctrl R}

-- local importing - non-dev
--local util = dofile(package.searchpath("util", package.path))
--local winops = dofile(package.searchpath("winops", package.path))
--local visicon = dofile(package.searchpath("visicon", package.path))

-- ** for dev **
-- export these names into global namespace - ie repl
-- so reload config rather than need to reload each in repl
util = dofile(package.searchpath("util", package.path))
winops = dofile(package.searchpath("winops", package.path))
winutil = dofile(package.searchpath("winutil", package.path))
visicon = dofile(package.searchpath("visicon", package.path))

---------------
-- RUN TESTS
---------------
function run_tests()
  dofile(package.searchpath("test", package.path))
end

-----------------------------
-- Temporary Util
-----------------------------


function win_and_screen_rects()
  local w = window.focusedwindow()
  local s = w:screen()
  return w:frame(), s:frame(), s:visibleframe(), s:frame_including_dock_and_menu(), s:frame_without_dock_or_menu()
end

function win_and_screen()
  w, sf, svf, sfdm, sfnodm = win_and_screen_rects()
  print("Current Win:")
  print(inspect(w))
  print("Current Screen:")
  print("frame():")
  print(inspect(sf))
  print("visibleframe()")
  print(inspect(svf))
  print("frame_including_dock_and_menu():")
  print(inspect(sfdm))
  print("frame_without_dock_or_menu():")
  print(inspect(sfnodm))
end

-----------------------
-- From Default init
-----------------------

-- show an alert to let you know Hydra's running
hydra.alert("Hydra config loaded", 1.5)

-- open a repl with mash-R; requires https://github.com/sdegutis/hydra-cli
--hotkey.bind({"cmd", "ctrl", "alt"}, "R", repl.open)

-- show a helpful menu
hydra.menu.show(function()
    local t = {
      {title = "Reload Config", fn = hydra.reload},
      {title = "Open REPL", fn = repl.open},
      {title = "-"},
      {title = "About Hydra", fn = hydra.showabout},
      {title = "Check for Updates...", fn = function() hydra.updates.check(nil, true) end},
      {title = "Quit", fn = os.exit},
    }

    if not hydra.license.haslicense() then
      table.insert(t, 1, {title = "Buy or Enter License...", fn = hydra.license.enter})
      table.insert(t, 2, {title = "-"})
    end

    return t
end)

-----------------------
-- Window Operations
-----------------------

-- move the window to the right half of the screen
function movewindow_righthalf()
  local win = window.focusedwindow()
  local newframe = win:screen():frame_without_dock_or_menu()
  newframe.w = newframe.w / 2
  newframe.x = newframe.x + newframe.w -- comment out this line to push it to left half of screen
  win:setframe(newframe)
end

function movewindow_lefthalf()
  local win = window.focusedwindow()
  local newframe = win:screen():frame_without_dock_or_menu()
  newframe.w = newframe.w / 2
  win:setframe(newframe)
end

-- disposable - checking setframe() behavior
function setframe(w, f)
  w:setsize(f)
  w:settopleft(f)
--  w:setsize(f)
end

function win_by_app_name(name)
  return fnutils.find(util.orderedwindows(), function(w)
    return w:application():title()
  end)
end

-- beginning to think about tiling
-- here we take a window and another window
-- we want to tile our window to the other window
-- in whatever direction makes sense - without having to
-- pass in direction, to minimize calls
-- fill - optional - if truthy after tiling the window
--    to the other window in one direction, fill the screen
--    in the orthogonal direction
-- TODO - haven't needed yet, but have not implemented vertical tiling
function tile_window_to(win, otherwin, fill)
  local f = win:frame()
  local otherf = otherwin:frame()
  local s = screen.mainscreen():frame_without_dock_or_menu()
  deltax, deltay = otherf.x - f.x, otherf.y - f.y
  local newf = {x=f.x, y=f.y, w=f.w, h=f.h}
  util.syslog("f: " .. util.str(f))
  util.syslog("otherf: " .. util.str(otherf))
  util.syslog("delta x=" .. deltax .. ", y=" .. deltay)

  if math.abs(deltax) > math.abs(deltay) then
    -- tile horizontally
    if deltax > 0 then
      util.syslog("delta x > zero -  tiling left")
      newf.w = otherf.x
      newf.x = 0
    else
      util.syslog("delta x < 0 - tiling on right")
      newf.w = s.w - otherf.w - otherf.x
      newf.x = otherf.x + otherf.w
    end
  else
    -- tile vertically
    util.syslog("abs(deltax) <= abs(deltay)")
  end
  util.syslog("newf: " .. util.str(newf))

  win:setframe(newf)
end

-- same logic as tiling one window to the other, but don't
-- resize the window
-- as with tiling - not implementing vertical butting yet
function butt_window_to(win, otherwin)
  local f = win:frame()
  local otherf = otherwin:frame()
  deltax, deltay = otherf.x - f.x, otherf.y - f.y
  local newf = {x=f.x, y=f.y, w=f.w, h=f.h}
  util.syslog("f: " .. util.str(f))
  util.syslog("otherf: " .. util.str(otherf))
  util.syslog("delta x=" .. deltax .. ", y=" .. deltay)

  if math.abs(deltax) > math.abs(deltay) then
    -- tile horizontally
    if deltax > 0 then
      util.syslog("delta x > zero -  tiling left")
      newf.x = otherf.x - newf.w
    else
      util.syslog("delta x < 0 - tiling on right")
      newf.x = otherf.x + otherf.w
    end
  else
    -- tile vertically
    util.syslog("abs(deltax) <= abs(deltay) - tiling vertically")
  end
  util.syslog("newf: " .. util.str(newf))

  win:setframe(newf)

end

-- make window win's frame the same size and location
-- as window otherwin
function copy_window_geo(win, otherwin)
  local f = otherwin:frame()
  local newf = {x=f.x, y=f.y, w=f.w, h=f.h}
  win:setframe(newf)
end

function tile_first_to_second_ordered_window()
  local wins = util.orderedwindows()
  if #wins >= 2 then
    tile_window_to(wins[1], wins[2])
  end
end

function butt_first_to_second_ordered_window()
  local wins = util.orderedwindows()
  if #wins >= 2 then
    butt_window_to(wins[1], wins[2])
  end
end

function copy_window_geo_first_to_second_ordered_window()
  local wins = util.orderedwindows()
  if #wins >= 2 then
    copy_window_geo(wins[1], wins[2])
  end
end

---------------------------
-- Window History Operation
---------------------------

-- module level cache of window geometry history to traverse
local _win_geo_hist = nil

function clear_geo_hist()
  _win_geo_hist = nil
end

local function _win_geo_hist_iterator(win)
  local q = visicon.get_current_vc_queue()
  local geo_hist = util.reverse(visicon.win_frame_history_by_app(q, win:application():title()))
  print("geo_hist: " .. #geo_hist)
  if #geo_hist > 0 then
    local index = 0
    return function (step_by)
        index = math.min(math.max(1, index + step_by), #geo_hist)
        print("index=" .. index)
        return geo_hist[index]
      end
  else
    return nil
  end
end

-- get a closure around the geometry history for window by app title
-- returns a function that takes an int and adds that to the current index in the
-- array of frames for the window in question
-- so f = get_geo_hist(current_win) ->
-- f(1) returns next frame going backward in history
-- f(-1) returns next frame going forward in history
-- both directions are bounded by
-- ** call clear_geo_hist() after done invoking for a window
function get_geo_hist(win)
  if not _win_geo_hist then
    _win_geo_hist = _win_geo_hist_iterator(win)
  end
  return _win_geo_hist
end

-- traverse the geometry history of the focused window
-- set frame to each new geometry in traversal
-- at ends of traversal, frame stays the same
-- ** must call clear_geo_hist before you want to invoke for a new window
-- step_by - integer - step iterator by - +1: increment history index by 1
--    -1: decrement index by 1, etc
function traverse_focused_win_geo_hist(step_by)
  local win = window.focusedwindow()
  local f = get_geo_hist(win)
  local frame = f(step_by)
  win:setframe(frame)
end

-- go further back in window's geometry history by app in visicon queue
focused_win_geo_hist_next = fnutils.partial(traverse_focused_win_geo_hist, 1)
-- come back toward present in windows's geo history
focused_win_geo_hist_previous = fnutils.partial(traverse_focused_win_geo_hist, -1)


-- Window and app info
function order_wins_info_str()
  s = {}
  for i, v in pairs(util.orderedwindows()) do
    s[i] = i .. ": " .. v:application():title().. "\t- " .. table.concat(v:frame(), ", ") .. v:title()
  end
  return table.concat(s, "\n")
end

function order_wins_info_alert()
  hydra.alert(order_wins_info_str(), 10)
end

-- print visible context state to hydra log
function log_visicon_state()
  util.log(inspect(visicon.state()) .. "\n")
end

function alert_queue_status()
  local status_text = visicon.global_queue_status()
  hydra.alert(status_text, 3)
end

-- KEY BINDINGS
-- note - these are parsed by an external program so keep same format
--    in particular - keep 'bindings = {' and final '}' on their own lines
bindings = {
{mods={"cmd", "ctrl", "alt"}, key="R", func=movewindow_righthalf, text="Move window to right half"},
{mods={"cmd", "ctrl", "alt"}, key="L", func=movewindow_lefthalf, text="Move window to left half"},
{mods={"cmd", "ctrl", "alt"}, key="K", func=alert_bindings, text="Show key bindings"},
{mods={"cmd", "ctrl", "alt"}, key="W", func=order_wins_info_alert, text="Show window info for context"},
{mods={"cmd", "ctrl", "alt"}, key="I", func=visicon.ignore_current_vc, text="Ignore current vc - stop saving state changes automatically."},
{mods={"cmd", "ctrl", "alt"}, key="U", func=visicon.unignore_current_vc, text="Unignore current vc - resume normal automatic saving of state changes"},

-- Moved these to modal bindings, not erasing though - may want to restore some
--{mods={"cmd", "ctrl"}, key="right", func=winops.move_win_right_5, text="Move window to right 5 percent of screen size"},
--{mods={"cmd", "ctrl"}, key="left", func=winops.move_win_left_5, text="Move window to left 5 percent of screen size"},
--{mods={"cmd", "ctrl"}, key="up", func=winops.move_win_up_5, text="Move window to up 5 percent of screen size"},
--{mods={"cmd", "ctrl"}, key="down", func=winops.move_win_down_5, text="Move window to down 5 percent of screen size"},
--
--{mods={"cmd", "ctrl", "alt"}, key="right", func=winops.resize_win_right_5, text="Grow window to right 5 percent of screen size"},
--{mods={"cmd", "ctrl", "alt"}, key="left", func=winops.resize_win_left_5, text="Shrink window from right 5 percent of screen size"},
--{mods={"cmd", "ctrl", "alt"}, key="up", func=winops.resize_win_up_5, text="Shrink window from bottom 5 percent of screen size"},
--{mods={"cmd", "ctrl", "alt"}, key="down", func=winops.resize_win_down_5, text="Grow window downwards 5 percent of screen size"},
--
--{mods={"cmd", "ctrl", "shift"}, key="right", func=winops.throw_right, text="Throw window to right edge of screen"},
--{mods={"cmd", "ctrl", "shift"}, key="left", func=winops.throw_left, text="Throw window to left edge of screen"},
--{mods={"cmd", "ctrl", "shift"}, key="down", func=winops.throw_down, text="Throw window to bottom edge of screen"},
--{mods={"cmd", "ctrl", "shift"}, key="up", func=winops.throw_up, text="Throw window to top edge of screen"},
--
--{mods={"ctrl", "alt"}, key="T", func=tile_first_to_second_ordered_window, text="Tile first to second ordered window"},

{mods={"ctrl", "alt"}, key="S", func=visicon.add_current_vc_state, text="Save visicon state to vc queue"},
{mods={"ctrl", "alt"}, key="L", func=visicon.restore_to_last_state, text="Restore visicon to last saved state in vc queue"},
{mods={"ctrl", "alt"}, key="G", func=visicon.global_snapshot, text="Save a global json snapshot of all vc queues"},
{mods={"ctrl", "alt"}, key="R", func=visicon.restore_queues_from_snapshot, text="Restore global vc queues structure from last json snapshot"},
{mods={"ctrl", "alt"}, key="Q", func=alert_queue_status, text="Show global queue status in alert dialog"},
}

-- formatted multiline string of key bindings and what they do
function bindings_string()
  output = {}
  for i, v in pairs(bindings) do
    output[i] = table.concat(v.mods, "+") .. " " .. v.key .. ": " .. v.text
  end
  return table.concat(output,"\n")
end

-- Show key bindings in an alert
function alert_bindings()
  hydra.alert(bindings_string(), 5)
end


-- BIND ALL KEYS
for i, v in pairs(bindings) do
  hotkey.new(v.mods, v.key, v.func):enable()
end

-- modal bindings comments are also parsed externally
-- so follow formatting

-- MODAL BINDINGS
-- ctrl+alt V            Adjust Volume
--    up      Raise by 3 percent
--    down    Lower by 3 percent
--    escape  Exit Mode
--
-- ctrl+alt W            Focused Window Operations
--    right     Move window to right 5 percent of screen size
--    left      Move window to left 5 percent of screen size
--    up        Move window up 5 percent of screen size
--    down      Move window down 5 percent of screen size
--    cmd right   Expand window to right 5 percent of screen size
--    cmd left    Shrink window from right 5 percent of screen size
--    cmd up      Shrink window from bottom 5 percent of screen size
--    cmd down    Expand window downwards 5 percent of screen size
--    shift right   Throw window to right edge of screen
--    shift left    Throw window to left edge of screen
--    shift up      Throw window to top edge of screen
--    shift down    Throw window to bottom edge of screen
--    cmd+shift right   Expand window to right edge of screen
--    cmd+shift left    Expand window to left edge of screen
--    cmd+shift up      Expand window to top edge of screen
--    cmd+shift down    Expand window to bottom edge of screen
--    T         Tile first to second ordered window
--    B         Butt first to second ordered window
--    C         Copy geometry of second ordered window to first
--
--    Change geometry by going backward in history of windows with same app in
--    Current Visicon Queue - only unique geometries, so if no change, you are at end
--    N         Change geometry to next back in history
--    P         Change geometry to previous (ie forward in history)
--    escape    Exit Mode

local volkey = hotkey.modal.new({"ctrl", "alt"}, "v")
volkey:bind({}, "up", util.volume_up)
volkey:bind({}, "down", util.volume_down)
volkey:bind({}, "escape", function() volkey:exit() end)
function volkey:entered()
  notify.show("Mode Activated", "",
              "Volume adjust mode.", "")
end
function volkey:exited()
  notify.show("Mode Deactivated", "",
              "Leaving volume adjust mode.\nVolume: " ..
              audiodevice.defaultoutputdevice():volume(), "")
end

local winkey = hotkey.modal.new({"ctrl", "alt"}, "w")
winkey:bind({}, "right", winops.move_win_right_5)
winkey:bind({}, "left", winops.move_win_left_5)
winkey:bind({}, "up", winops.move_win_up_5)
winkey:bind({}, "down", winops.move_win_down_5)

winkey:bind({"cmd"}, "right", winops.resize_win_right_5)
winkey:bind({"cmd"}, "left", winops.resize_win_left_5)
winkey:bind({"cmd"}, "up", winops.resize_win_up_5)
winkey:bind({"cmd"}, "down", winops.resize_win_down_5)

winkey:bind({"shift"}, "right", winops.throw_right)
winkey:bind({"shift"}, "left", winops.throw_left)
winkey:bind({"shift"}, "up", winops.throw_up)
winkey:bind({"shift"}, "down", winops.throw_down)

winkey:bind({"cmd", "shift"}, "right", winops.expand_fill_right)
winkey:bind({"cmd", "shift"}, "left", winops.expand_fill_left)
winkey:bind({"cmd", "shift"}, "up", winops.expand_fill_up)
winkey:bind({"cmd", "shift"}, "down", winops.expand_fill_down)

winkey:bind({}, "t", tile_first_to_second_ordered_window)
winkey:bind({}, "b", butt_first_to_second_ordered_window)
winkey:bind({}, "c", copy_window_geo_first_to_second_ordered_window)

winkey:bind({}, "n", focused_win_geo_hist_next)
winkey:bind({}, "p", focused_win_geo_hist_previous)

winkey:bind({}, "escape", function() winkey:exit() end)

function winkey:entered()
  local qname = assert(visicon.get_current_vc_queue_name())
  if not fnutils.contains(visicon.vcs_to_ignore, qname) then
    notify.show("Mode Activated", "",
              "Focused window operations.", "")
  end
end

-- deal with any cleanup
function winkey:exited()
  -- clear geometry history for focused window if being traversed
  -- note that depending on usage, might want to make this smarter
  -- and have the closure function confirm the app of the focused window
  -- and reset there if it changes - this might facilitate operating on multiple
  -- windows in a single session
  clear_geo_hist()
  -- note that I am now guarding the notification calls with
  -- a check to see if the current visicon is being ignored
  -- which duplicates logic in visicon.add_current_vc_state
  -- for now I am fine with it, as this is just a convenience
  -- and the logic in add_current_vc_state wants to be there
  -- no matter how it is invoked
  visicon.add_current_vc_state()
  local qname = assert(visicon.get_current_vc_queue_name())
  if not fnutils.contains(visicon.vcs_to_ignore, qname) then
    notify.show("Mode Deactivated", "",
              "Leaving window operations mode - saved vc state", "")
  end
end


--hotkey.new({"cmd", "ctrl", "alt"}, "K", print_bindings):enable()

-- bind your custom function to a convenient hotkey
-- note: it's good practice to keep hotkey-bindings separate from their functions, like we're doing here
--hotkey.new({"cmd", "ctrl", "alt"}, "R", movewindow_righthalf):enable()
--hotkey.new({"cmd", "ctrl", "alt"}, "L", movewindow_lefthalf):enable()


-- uncomment this line if you want Hydra to make sure it launches at login
-- hydra.autolaunch.set(true)

-- when the "update is available" notification is clicked, open the website
notify.register("showupdate", function() os.execute('open https://github.com/sdegutis/Hydra/releases') end)

-- check for updates every week, and also right now (when first launching)
timer.new(timer.weeks(1), hydra.updates.check):start()
hydra.updates.check()
