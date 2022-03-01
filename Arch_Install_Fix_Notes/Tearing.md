Enable the TearFree option in the driver by adding the following line to your configuration file

NOTE: This breaks the whole system - why? need better solution

`/etc/X11/xorg.conf.d/20-intel.conf`

```
Section "Device"
  Identifier "Intel Graphics"
  Driver "intel"
  Option "TearFree" "true"
EndSection
```
