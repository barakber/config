-- Standard awesome library
require("awful")
require("awful.autofocus")
require("awful.rules")
-- Theme handling library
require("beautiful")
-- Notification library
require("naughty")

-- Load Debian menu entries
require("debian.menu")

function random_wallpaper()
        awful.util.spawn_with_shell("awsetbg ~/Pictures/Wallpapers/`ls ~/Pictures/Wallpapers | shuf -n 1`") 
end
awful.hooks.timer.register(60 * 10, random_wallpaper) 

Ticker = {}
Ticker.__index = Ticker
function Ticker.create(width)
    local ticker = {}
    setmetatable(ticker, Ticker)
    ticker.width  = width
    ticker.cursor = 1
    ticker.text = "                           "
    return ticker
end

function Ticker:render()
    part1 = string.sub(self.text, self.cursor, self.cursor + self.width)
    left = self.cursor + self.width - self.text:len()
    if (self.cursor + self.width > self.text:len()) then
        part2 = string.sub(self.text, 1, (self.cursor + self.width) - (self.text:len()))
    else
        part2 = ""
    end
    self.cursor = (self.cursor + 1) % (self.text:len())
    if self.cursor == 0 then
        self.cursor = 1
    end
    return "|<span color='black' font='Courier New 10'><b>" .. part1 .. part2 .. "</b></span>|"
end

function Ticker:refresh()
    process = io.popen("./hn_articles.py")    
    self.text = process:read() .. " "
    self.cursor = 1
    process:close()
end
--ticker_obj = Ticker.create(24)
--ticker_obj:refresh()
--ticker = widget({type = "textbox", align = "right" })
--awful.hooks.timer.register(10 * 60, function() ticker_obj:refresh() end)
--awful.hooks.timer.register(0.175, function() ticker.text = ticker_obj:render() end)

InfoBar = {}
InfoBar.__index = InfoBar
function InfoBar.create()
    local infobar = {}
    setmetatable(infobar, InfoBar)
    infobar.counter     = 0
    infobar.battery     = 0
    infobar.temperature = 0
    infobar.jiffies     = 0
    infobar.cpu         = 0
    infobar.mem_total   = 0
    infobar.mem_free    = 0
    infobar.mem_used    = 0
    infobar.disk_sda3   = 0
    infobar.disk_sda6   = 0
    infobar.eth0_ip     = nil
    infobar.eth0_rx     = 0
    infobar.eth0_delta_rx = 0
    infobar.eth0_tx     = 0
    infobar.eth0_delta_tx = 0
    infobar.wlan0_ip    = nil
    infobar.wlan0_rx    = 0
    infobar.wlan0_delta_rx = 0
    infobar.wlan0_tx    = 0
    infobar.wlan0_delta_tx = 0
    infobar.ssid        = nil
    return infobar
end

function InfoBar:render()
    self.counter = self.counter + 1
    self:get_battery()
    self:get_temperature()
    self:get_cpu()
    self:get_memory()
    self:get_network_usage()
    self:get_disk()
    eth0_part = ""
    if self.eth0_ip ~= nil then
        eth0_part = string.format("<span color='#B8704D'>E: %s/%0.4d/%0.4d</span>|", self.eth0_ip, self.eth0_delta_rx, self.eth0_delta_tx)
    end
    wlan0_part = ""
    if self.wlan0_ip ~= nil then
        wlan0_part = string.format("<span color='#B8704D'>W: <b>%s</b>/%s/%0.4d/%0.4d</span>|", self.ssid, self.wlan0_ip, self.wlan0_delta_rx, self.wlan0_delta_tx)
    end
    main_part = string.format("|%s%s<span color='#FF8080'>/: %.1fGb</span>|<span color='#FF8080'>/x: %.1fGb</span>|<span color='#F0B2F0'>M: %d/%d</span>|<span color='pink'>C: %0.3d%%</span>|<span color='light blue'>T: %dC</span>|<span color='light green'>B: %0.3d%%</span>|", 
        wlan0_part, eth0_part, self.disk_sda3 / 1024, self.disk_sda6 / 1024, self.mem_used, self.mem_total, self.cpu, self.temperature, self.battery)

    return main_part
                            
end

function InfoBar:get_battery()
    file = io.open("/sys/class/power_supply/BAT0/capacity")
    self.battery = tonumber(file:read())
    file:close()
end

function InfoBar:get_temperature()
    process = io.popen("acpi -t | awk {'print $4'}")
    self.temperature = tonumber(process:read())
    process:close()
end

function InfoBar:get_cpu()
    file = io.open("/proc/stat")
    line1 = file:read()
    file:close()
    local current_cpu, newjiffies = string.match(line1, "cpu(%d*)\ +(%d+)")
    if current_cpu and newjiffies then
        if self.jiffies == 0 then
            self.jiffies = newjiffies
        end
        self.cpu = newjiffies - self.jiffies
        self.jiffies = newjiffies
    end
end
function InfoBar:get_memory()
    file = io.open("/proc/meminfo")
    self.mem_total = math.floor(tonumber(string.match(file:read(), "MemTotal: *(.*) kB")) / 1000)
    self.mem_free  = math.floor(tonumber(string.match(file:read(), "MemFree: *(.*) kB")) / 1000)
    self.mem_used  = self.mem_total - self.mem_free
    file:close()
end

function InfoBar:get_disk()
    process = io.popen("df -v /")
    process:read()
    self.disk_sda3 = math.floor(tonumber(string.match(process:read(), "/dev/sda3 +%d+ +%d+ +(%d+)")) / 1000)
    process:close()
    
    process = io.popen("df -v /x")
    process:read()
    self.disk_sda6 = math.floor(tonumber(string.match(process:read(), "/dev/sda6 +%d+ +%d+ +(%d+)")) / 1000)
    process:close()
end

function InfoBar:get_network_usage()
    process = io.popen("ifconfig eth0 | sed -n 's/^.*inet addr:\\([0-9.]*\\).*$/\\1/p'")
    self.eth0_ip = process:read()
    process:close()

    process = io.popen("ifconfig wlan0 | sed -n 's/^.*inet addr:\\([0-9.]*\\).*$/\\1/p'")
    self.wlan0_ip = process:read()
    process:close()

    if self.eth0_ip ~= nil then
        _f1 = io.open("/sys/class/net/eth0/statistics/rx_bytes")
        new_rx = math.floor(tonumber(_f1:read()) / 1024)
        self.eth0_delta_rx = new_rx - self.eth0_rx
        self.eth0_rx = new_rx
        _f1:close()

        _f1 = io.open("/sys/class/net/eth0/statistics/tx_bytes")
        new_tx = math.floor(tonumber(_f1:read()) / 1024)
        self.eth0_delta_tx = new_tx - self.eth0_tx
        self.eth0_tx = new_tx
        _f1:close()
    end

    if self.wlan0_ip ~= nil then
        process = io.popen("iwgetid -r")
        self.ssid = process:read()
        process:close()
    
        _f1 = io.open("/sys/class/net/wlan0/statistics/rx_bytes")
        new_rx = math.floor(tonumber(_f1:read()) / 1024)
        self.wlan0_delta_rx = new_rx - self.wlan0_rx
        self.wlan0_rx = new_rx
        _f1:close()

        _f1 = io.open("/sys/class/net/wlan0/statistics/tx_bytes")
        new_tx = math.floor(tonumber(_f1:read()) / 1024)
        self.wlan0_delta_tx = new_tx - self.wlan0_tx
        self.wlan0_tx = new_tx
        _f1:close()
    end
end

infobar = InfoBar.create()
info = widget({type = "textbox", align = "right" })
awful.hooks.timer.register(1, function() info.text = infobar:render() end)

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.add_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init("/usr/share/awesome/themes/default/theme.lua")

-- This is used later as the default terminal and editor to run.
--terminal = "x-terminal-emulator"
terminal = "urxvtc"
editor = os.getenv("EDITOR") or "editor"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
layouts =
{
    --awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    --awful.layout.suit.max,
    --awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier
}
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, layouts[1])
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "Debian", debian.menu.Debian_menu.Debian },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = image(beautiful.awesome_icon),
                                     menu = mymainmenu })
-- }}}

-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock({ align = "right" })

-- Create a systray
mysystray = widget({ type = "systray" })

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(function(c)
                                              return awful.widget.tasklist.label.currenttags(c, s)
                                          end, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })
    -- Add widgets to the wibox - order matters
    mywibox[s].widgets = {
        {
            mylauncher,
            mytaglist[s],
            mypromptbox[s],
            layout = awful.widget.layout.horizontal.leftright,
        },
        mylayoutbox[s],
        mytextclock,
        --ticker,
        info,
        s == 1 and mysystray or nil,
        mytasklist[s],
        layout = awful.widget.layout.horizontal.rightleft
    }
end
-- }}}

-- Keyboard map indicator and changer
kbdcfg = {}
kbdcfg.cmd = "setxkbmap"
kbdcfg.layout = { "us", "il" }
kbdcfg.current = 1  -- us is our default layout
kbdcfg.widget = widget({ type = "textbox", align = "right" })
kbdcfg.widget.text = " " .. kbdcfg.layout[kbdcfg.current] .. " "
kbdcfg.switch = function ()
    kbdcfg.current = kbdcfg.current % #(kbdcfg.layout) + 1
    local t = " " .. kbdcfg.layout[kbdcfg.current] .. " "
    kbdcfg.widget.text = t
    os.execute( kbdcfg.cmd .. t .. "-option caps:swapescape" )
end

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    -- Alt + Right Shift switches the current keyboard layout
    awful.key({ "Mod1" }, "Shift_L", function () kbdcfg.switch() end),
    
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show({keygrabber=true}) end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end),
    awful.key({ }, "F12", function () awful.util.spawn("xscreensaver-command -lock") end),
    awful.key({ }, "XF86AudioRaiseVolume",  function () awful.util.spawn("amixer set Master 2+") end),
    awful.key({ }, "XF86AudioLowerVolume",  function () awful.util.spawn("amixer set Master 2-") end),
    awful.key({ }, "XF86AudioMute",         function () awful.util.spawn("amixer -D pulse set Master 1+ toggle") end),
    awful.key({ }, "XF86AudioPlay",         function () awful.util.spawn("rhythmbox-client --play-pause") end),
    awful.key({ }, "XF86AudioNext",         function () awful.util.spawn("rhythmbox-client --next") end),
    awful.key({ }, "XF86AudioPrev",         function () awful.util.spawn("rhythmbox-client --previous") end),
    awful.key({ modkey,  }, ",",            random_wallpaper)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = 2, --beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
		     size_hints_honor = false,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "pinentry" },
      properties = { floating = true } },
    { rule = { class = "gimp" },
      properties = { floating = true } },
   -- Set Firefox to always map on tags number 2 of screen 1.
--    { rule = { class = "Firefox" },
--      properties = { tag = tags[1][4] } },
    { rule = { class = "knotes" },
      properties = { tag = tags[1][6] } },
    { rule = { class = "Rhythmbox" },
      properties = { tag = tags[1][9] } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.add_signal("manage", function (c, startup)
    -- Add a titlebar
    -- awful.titlebar.add(c, { modkey = modkey })

    -- Enable sloppy focus
    c:add_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.add_signal("focus", function(c) c.border_color = "#006400" end) --beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = "#000020" end) --beautiful.border_normal end)
--client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
--client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
awful.util.spawn_with_shell("urxvtd -q -o -f")
awful.util.spawn_with_shell("xscreensaver -no-splash")
awful.util.spawn_with_shell("nm-applet --sm-disable")
