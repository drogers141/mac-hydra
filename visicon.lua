-- Visibility Context
-- Abstraction for handling state I care about
-- Add docs

local util = dofile(package.searchpath("util", package.path))

-- dialog utility - third party - will change
require "ext.dialog.init"

visicon = {}

visicon.snapshot_dir = '/Users/drogers/.hydra/snapshots'


-- terse time format good for file names
-- timestamp - secs since epoch
local function format_from_timestamp(timestamp)
  return os.date('%Y-%m-%d_%H.%M.%S', timestamp)
end

-- returns table of the current visible windows context
function visicon.state()
  local state = {}
  -- windows in mru order
  local ow = util.orderedwindows()
  local wins = fnutils.map(ow, util.windowtable)
  if wins then
    state['windows'] = wins
    state['screen'] = util.screentable(ow[1]:screen())
    state['desktop'] = spaces.currentspace()
    -- seconds since epoch
    local now = os.time()
    state['timestamp'] = now
    -- formatted datetime - for easy reading
    state['datetime'] = os.date('%c', now)
  end
  return state
end

-- for each visibility context there is a queue
-- 2 screens and 4 desktops -> 8 vcqs
-- screens are identified by resolution
-- each queue will be kept in memory, between a min and max
-- size - the queues hold visicon states as elements
-- relies on ability to always easily determine what desktop
-- is current as well - this seems not to be a problem
-- the queues are just lua tables maintained as arrays
-- with the most recent visicon state at the end of the array
-- ie vsq[#vsq]
-- the queue allows random access for resurrecting a former state
-- which will reposition any windows with the same ids as the previous
-- state had - and have some policy for new windows created after
-- once there is a new state, that is added to the end of the list
-- resizing - when q is longer than max length, maxlen - minlen
-- elements are removed from the front of the q
local vc_queues = {}
local min_q_len, max_q_len = 50, 100

-- returns formatted multiline string with each queue name and length
-- adds asterisk to highlight current vc qname if there is one
function visicon.global_queue_status()
  local qname = visicon.get_current_vc_queue_name()
  local lines = {}
  if #util.keys(vc_queues) == 0 then
    lines[#lines+1] = "{}"
  else
    for i, v in pairs(vc_queues) do
      if qname and i == qname then
        lines[#lines+1] = i .. ": " .. #v .. " *"
      else
        lines[#lines+1] = i .. ": " .. #v
      end
    end
  end
  table.sort(lines)
  table.insert(lines, 1, "vc_queues: ")
  return (table.concat(lines,"\n"))
end

-- Store a json snapshot of the global vc_queues structure
-- holding all of the visicon queues
-- file - optional - save to file - default saves to snapshot log
function visicon.global_snapshot(file)
  local state_str = json.encode(vc_queues)
  local out = file or nil
  if not out then
    out = visicon.snapshot_dir .. '/' .. os.date('%Y-%m-%d_%H.%M.%S') .. ".json"
  end
  util.log(state_str .. "\n", out)
  util.syslog("Saved vc queues to snapshot in file: " .. out)
end

-- Initialize global vc_queues structure from json snapshot
-- snapshot_file - optional - snapshot json file to restore from
--    default restores from most recent snapshot in
--    visicon.snapshot_dir if there is one
--    success or failure logged to syslog
function visicon.restore_queues_from_snapshot(snapshot_file)
  local jsonfile = snapshot_file or nil
  if not jsonfile then
    -- json snapshot files in snapshot_dir sort by date-time
    -- so last is most recent
    snapshots = util.dir(visicon.snapshot_dir)
    table.sort(snapshots)
    jsonfile = #snapshots > 0 and snapshots[#snapshots]
  end

  if jsonfile then
    local f = assert(io.open(jsonfile, 'r'))
    local jsonstr = f:read("*a")
    f:close()
    if jsonstr then
      local vc_qs = json.decode(jsonstr)
      if vc_qs then
        vc_queues = vc_qs
        util.syslog("Restored vc queues from file: " .. jsonfile)
      else
        util.syslog("Got json string from file: " .. jsonfile ..
                    ", but no vc queues")
      end
    else
      util.syslog("Opened vc queue file: " .. jsonfile .. ", but no contents")
    end
  else
    util.syslog("No vc queue snapshot file available")
  end
end

-- returns name of the queue for the current visibility context
-- nil if not - should log that if it happens and see
-- if we need to change up
function visicon.get_current_vc_queue_name()
  local screen_id = util.get_screen_id(screen.mainscreen():frame())
  local desktop_id = spaces.currentspace()
  if screen_id and desktop_id then
    return screen_id .. 'd' .. desktop_id
  end
end

function visicon.get_vcq_structure()
  return vc_queues
end

function visicon.get_current_vc_queue()
  local qname = visicon.get_current_vc_queue_name()
--  if vc_queues[qname] then
--    util.syslog("visicon: qname=" .. qname .. ", length=" .. #vc_queues[qname])
--  end
  return vc_queues[qname]
end

-- list of vc queue names whose window states will be ignored
-- when add_current_vc_state is called
-- this is a public, global, mutable thing
visicon.vcs_to_ignore = {}

visicon.ignore_dialog = nil
-- creates and shows visicon.ignore_dialog which is a textgrid
-- moves to top right corner of screen
-- can hide() or show() in the instance
-- also can destroy(), but don't think it is really going away..
-- still - should create and destroy the dialog if used in different
-- visicons - may be a minor memory leak
function visicon.create_ignore_dialog()
  visicon.ignore_dialog = util.textgrid("Visicon Untracked",
    "The current visibility\ncontext will not be saved.")
  local w = visicon.ignore_dialog:window()
  winutil.throw_win(w, "up")
  winutil.throw_win(w, "right")
end

-- sets current vc to be ignored by state saving mechanism
-- shows a text window in the top left corner indicating this
-- window will not be dismissed until call to unignore_current_vc
function visicon.ignore_current_vc()
  local qname = assert(visicon.get_current_vc_queue_name())
  if not fnutils.contains(visicon.vcs_to_ignore, qname) then
    table.insert(visicon.vcs_to_ignore, qname)
    visicon.create_ignore_dialog()
    util.syslog("ignoring current vc: " .. qname ..
                ", currently ignoring queues: " ..
                table.concat(visicon.vcs_to_ignore, ", "))
  end
end

-- sets current vc to participate normally in state saving
-- and destroys reminder window
function visicon.unignore_current_vc()
  local qname = assert(visicon.get_current_vc_queue_name())
  local index = fnutils.indexof(visicon.vcs_to_ignore, qname)
  if index then
    table.remove(visicon.vcs_to_ignore, index)
    visicon.ignore_dialog:destroy()
    util.syslog("unignoring current vc: " .. qname ..
                ", currently ignoring queues: " ..
                table.concat(visicon.vcs_to_ignore, ", "))
  end
end

-- add current visicon state to the appropriate queue
-- create queue if it doesn't exist
-- raises assertion errors if it can't get a queue
function visicon.add_current_vc_state()
  local state = visicon.state()
  local qname = assert(visicon.get_current_vc_queue_name())
  if fnutils.contains(visicon.vcs_to_ignore, qname) then
    util.syslog("did not save vc state to queue: " .. qname ..
                ", ignoring queues: " ..
                table.concat(visicon.vcs_to_ignore, ", "))
  else
    local q = visicon.get_current_vc_queue()
    if q then
      q[#q+1] = state
    else
      vc_queues[qname] = {state}
    end
    util.syslog("saved vc state to memory: queue=" .. qname .. ", length=" .. #vc_queues[qname])
  end
end



-- set current vc to state
function visicon.set_to_state(state)
  local logstr = {"Windows set:"}
  local wins_str = table.concat(fnutils.map(util.orderedwindows(),
                                    function(w) return w:id() end), ", ")
  local state_str = table.concat(fnutils.map(state['windows'],
                                    function(w) return w.id end), ", ")
  for i, w in pairs(util.orderedwindows()) do
    for j, s in pairs(state['windows']) do
      if s.id == w:id() then
        logstr[#logstr+1] = w:id()
        w:setframe(s.frame)
      end
    end
  end
  util.syslog(table.concat(logstr, "  ") ..
              "\nWindows in Context: " .. wins_str ..
              "\nWindows in State: " .. state_str)
end

-- find the queue for this visicon and set all the windows
-- as they were in the last state saved if there is one
-- alerts if there is no saved state
function visicon.restore_to_last_state()
  local vc_q = visicon.get_current_vc_queue()
  if not vc_q then
    util.syslog("restore_to_last_state: No queue for this visicon.")
  else
    local prev_state = vc_q[#vc_q]
    if not prev_state then
      util.syslog("restore_to_last_state: No state in queue: " ..
                    visicon.get_current_vc_queue_name())
    else
      visicon.set_to_state(prev_state)
    end
  end
end


return visicon
