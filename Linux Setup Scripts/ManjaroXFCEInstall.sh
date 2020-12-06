#!/bin/bash

# *************** AHMED's MANJARO INSTALL ***************
# Important: Run system update before executing this script.
# Programs Installed Overview: 
# Settings Tweaked Overview: 

# Uninstall Unused Software
pacman -Rsn --noconfirm bauh galculator-gtk2 gcolor2 gimp gtkhash-thunar hexchat manjaro-documentation-en manjaro-hello mousepad orage pidgin samba thunderbird unrar timeshift xfburn xfce4-dict xfce4-notes-plugin xfce4-screenshooter yelp
# Should also uninstall 'xfce4-accessibility-settings' 'Qt V4L2 video capture utility'

# Install Critical Software
# Software from Official Arch Repository
sudo pacman -S --noconfirm 
# Software from AUR
git clone ...
cd ...
makepkg -si ...








