### Monitor Hotplugging
Create `/etc/udev/rules.d/95-monitor-hotplug.rules` and add the following too it:
```
#Rule for executing commands when an external screen is plugged in.
SUBSYSTEM=="drm", ACTION=="change", RUN+="/bin/monitor_hotplug.sh"
```

Also add `monitor_hotplug.sh` (as an executable) in the `/bin/` directory

```
#!/bin/bash
echo "Monitor Event at $(date)" >>/tmp/scripts.log

export DISPLAY=:0
export XAUTHORITY=/home/ahmed/.Xauthority

function connect(){
        xrandr --output DP-1 --auto --right-of eDP-1
}
function disconnect(){
        xrandr --output DP-1 --auto
}

xrandr | grep "DP-1 connected" | grep -v "eDP-1" &> /dev/null && connect || disconnect
```
