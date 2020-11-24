#!/bin/bash

# *************** BAIGEL's MANJARO AWESOME INSTALL ***************
# Run system update before executing this script.

# Current Issues
# - Code is incredible specific (to manjaro awesome), a better script would be more generalized to work with, say, any version of manjaro, or conver a blank slate (like arch) into a fully custom syste)


# System Update
#pacman -Syyu --noconfirm??


# Fix Pacman Key issues
gpg --keyserver hkp://keys.gnupg.net --recv-keys 4773BD5E130D1D45  # Used for fixing spotify (may need to change regularly idk)
pacman -S archlinux-keyring
pacman-key --refresh-keys


# Fix rofi font issue
# Download https://gitlab.manjaro.org/profiles-and-settings/desktop-settings/blob/master/community/bspwm/skel/.config/rofi/config.rasi and place into ~/.config/rofi


# Uninstall Unused Software
pacman -Rsn --noconfirm bauh gimp hexchat manjaro-hello mousepad xfce-screenshooter thunderbird transmission-gtk pidgin xfburn orage audacious lxterminal zathura-djvu zathura-pdf-poppler zathura gtkhash-thunar thunar-archive-plugin thunar-media-tags-plugin thuar-shares-plugin thunar-volman thunar


# Install Software
# List all installs
IDEs="visual-studio-code-bin atom"
TERMINAL="konsole exa ranger dictd xorg-xev playerctl xdotool screenfetch feh"
LATEX="texlive-core texlive-latexextra texlive-science pdftk"
OTHER="discord steam dolphin"
TOOLS="manjaro-pulse"
# Fix up keys
sudo pacman-key --refresh-keys
sudo pacman -Sy --noconfirm archlinux-keyring && sudo pacman -Su --noconfirm
sudo hwclock -w
# Software from Official Arch Repository
pacman -S --noconfirm $IDES $TERMINAL $LATEX $OTHER
# Software AUR Programs
AURPrograms=( yay spotify spotify-adblock-git flameshot-git github-desktop-git scrcpy google-keep-nativefier tllocalmgr-git )
mkdir aur-programs
cd aur-programs
for i in "${AURPrograms[@]}"
    do
    git clone "https://aur.archlinux.org/"$i".git"
    cd $i
    makepkg -si --noconfirm $i
    cd ..
    done
cd
rm -rf ~/aur-programs
# Install Doom Emacs
git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
~/.emacs.d/bin/doom install

# Set Wallpaper
git clone
# Need to make the following wallpaper change permanent
feh --bg-scale ~/.wallpaper


# Replace config files with config files from github
# Awesome config
git clone
# Autorun on start file
git clone
# Flameshot config file
git clone

# Install atom addons
apm install save-workspace

# Finish Up
reboot


