#!/bin/bash

# *************** BAIGEL's ARCH INSTALL ***************
# Run system update before executing this script.

# Basic Overview
# Internet connection Required ("ip link" for interface name; "wifi-menu -o [interfaceName]" to connect)
# Desktop Environment:	
# Window Manager:	Spectrwm

set -ex # prints each line of sscript for debugging
#set -e

# Coloured text function declaration
GREEN='\033[0;32m'
#echo() {
#    echo -e "{$GREEN}$1"
#}

# Temporarily line used for debugging
#trap read debug

# Functions

install_arch() {
	# Prompt user with inital warning
	echo 'WARNING: THIS SCRIPT WILL BLINDLY WIPE THE DISK!'
	echo 'Press Enter to continue...'
	read -s

	echo ' -- Starting Setup --- '

	# System Details
	DRIVE='/dev/sda'
	TIMEZONE='Australia/Brisbane'
	KEYMAP='us'

	# Get hostname and username
	#echo 'Enter username'
	#read USERNAME
	#echo 'Enter hostname: '
	#read HOSTNAME

	# Get Password
	#echo -n "Password: "
	#read -s PASSWORD
	#echo
	#echo -n "Repeat Password: "
	#read -s PASSWORD2
	#echo
	#[[ "$PASSWORD" == "$PASSWORD2" ]] || ( echo "Passwords did not match; exiting now."; exit 1; )

	# testing
	HOSTNAME='baigel-vm'
	USERNAME='baigel'
	PASSWORD='toor'

	# Setup Logging
	echo 'Enabling logging'
	exec 1> >(tee "stdout.log")
	exec 2> >(tee "stderr.log")

	# Update system clock
	echo 'Update system clock'
	timedatectl set-ntp true
	
	# Reorder mirror list
	echo ' --- Initializing Mirror Lists and Keyrings --- '
	echo 'Backing up mirrors list'
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	echo 'Recreating ordered mirror list'
	reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	#reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

	# Initate pacman keyring
	echo 'Initialise and reload keys'
	pacman-key --init
	pacman-key --populate archlinux
	#pacman-key --refresh-keys

	echo ' --- Setting Up Boot and Swap Partitions --- '

	# Setup Partitioning
	echo 'Partitioning the disk'
	sfdisk /dev/sda <<- EOF
	label: gpt
	device: /dev/sda
	unit: sectors

	,512M,uefi
	,2G,swap
	;,home
	EOF

	# Format the partitions
	echo 'Formatting partitions'
	mkfs.fat -F32 /dev/sda1
	mkfs.ext4 /dev/sda3

	# Mounting partitions
	echo 'Mounting partitions'
	mount /dev/sda3 /mnt
	mkdir -pv /mnt/efi
	mount /dev/sda1 /mnt/efi
	
	# Enable swap
	mkswap /dev/sda2
	swapon /dev/sda2

	# Install important packages using pacstrap
	echo ' --- Installing Base --- '
	pacstrap /mnt base linux linux-firmware

	# Generate fstab
	echo 'Generating the fstab file'
	genfstab -U /mnt >> /mnt/etc/fstab
	
	# Enable efivarfs
	modprobe efivarfs
	
	# Enter chroot to continue install
	echo 'Entering chroot to continue install'
	cp $0 /mnt/arch_install.sh
	arch-chroot /mnt ./arch_install.sh chroot
}

configure_arch() {


	# testing
	HOSTNAME='baigel-vm'
	USERNAME='baigel'
	PASSWORD='toor'

	echo 'Continuing setup in chroot'

	# Chroot specific setup
	echo 'Setting timezone'
	ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
	echo 'Generating /etc/adjtime'
	hwclock --systohc
	echo 'Setting localization'
	echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
	echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
	locale-gen
	echo 'Set keymap'
	echo 'KEYMAP=de-latin1' >> /etc/vconsole.conf
	echo 'Setting hostname and configuring network'
	echo "$HOSTNAME" >> /etc/hostname
	echo "127.0.0.1	localhost\n::1		localhost\n127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME" >> /etc/hosts
	#echo 'Installing zsh (needed for useradd)'
	#sudo pacman -S zsh
	echo 'Adding user'
	useradd -m -s /bin/bash -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,storage,scanner,power "$USERNAME"
	echo 'Setting root password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd
	echo 'Setting user password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd $USERNAME
	echo 'Adding root and user as sudoers'
	echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers
	chmod 440 /etc/sudoers
	
	echo 'Add multilib repository'
	printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
	echo 'Installing programs'
	install_packages
	echo 'Setting up microde'
	echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
	echo 'Enable systemctl services'
	systemctl enable cpupower.service
	echo 'Updating locate'
	locale-gen
	#echo 'Enable dhcpcd'
	#systemctl enable dhcpcd

	echo ' --- Installing Bootloader (grub) --- '
	pacman -S --noconfirm grub os-prober efibootmgr
	grub-install --recheck --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	echo 'Exiting'
	exit
	umount -R /mnt
	echo ' --- Install Finished --- '

	# System Update
	#pacman -Syyu --noconfirm??

	# Fix rofi font issue (?)
	# Download https://gitlab.manjaro.org/profiles-and-settings/desktop-settings/blob/master/community/bspwm/skel/.config/rofi/config.rasi and place into ~/.config/rofi

	# Set Wallpaper
	#git clone
	# Need to make the following wallpaper change permanent
	#feh --bg-scale ~/.wallpaper


	# Install atom addons
	#apm install save-workspace

}

# Functions

install_packages() {
	# Core software from official Arch repository
	DEVELOPMENT="gcc libstdc++5 git code python atom"
	TERMINAL="konsole exa ranger dictd xorg-xev playerctl xdotool screenfetch feh"
	LATEX="texlive-core texlive-latexextra texlive-science pdftk"
	NETWORK="netctl ifplugd dialog wireless_tools wpa_supplicant"
	TOOLS="nano dolphin firefox"
	UTILITIES="playerctl flameshot feh cpupower vlc usbutils aspell-en openssh p7zip"
	INTEL="intel-ucode"
	AUDIO="pulseaudio-alsa pulseaudio-ctl alsa-utils"
	LOGIN=""
	FONTS=""
	pacman -Sy --noconfirm $DEVELOPMENT $TERMINAL $LATEX $NETWORK $TOOLS $UTILITIES $INTEL $AUDIO $LOGIN $FONTS
	# Install Doom Emacs
	#git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
	#~/.emacs.d/bin/doom install
	
	# Software AUR Programs and other community packages
	cat > /tmp/aur_packages.sh <<- EOF
	#!/bin/bash
	AURPrograms=( github-desktop-git scrcpy yay wpa_actiond wpa_supplicant_gui spotify spotify-adblock-git steam-fonts tllocalmgr-git )
	# Prompt user for what programs to install
	installPackages=""
	for i in "${AURPrograms[@]}"
		installPackages+="$i "
	done
	cd ~
	mkdir -p aur-programs
	cd aur-programs
	for i in "${installPackages[@]}"
		do
		git clone "https://aur.archlinux.org/"$i".git"
		cd $i
		makepkg -si --noconfirm --asroot $i
		cd ..
	done
	cd
	rm -rf ~/aur-programs
	EOF
	
	
	# Other Programs
	# community: discord steam-native
	# aur: wpa_actiond spotify spotify-adblock-git steam-fonts tllocalmgr-git tbsm
}

configure_x11() {
	# Install X11 stuff
	pacman -S --noconfirm xorg xorg-server xorg-xinit
	
	# Add config details
	cat >> ~/.xinitrc <<- EOF
	/usr/bin/setxkbmap au
	#/usr/bin/numlockx off
	#/usr/bin/xautolock -time 20 -locker slock &
	~/.fehbg
	exec spectrwm
	EOF
}

install_desktop_environment() {
	# Install DE (spectrwm)
	pacman -S --noconfirm spectrwm
	echo "bar_font = xos4 Terminus:pixelsize=14" >> /.spectrwm.conf
	mkdir -p ~/.config/spectrwm
	
	# Install program manager (rofi)
	pacman -S --noconfirm rofi
}

configure_netctl() {
	echo 'Enable systemctl wifi services'
	systemctl enable net-auto-wired.service net-auto-wireless.service
}

#get_dot_files() {
	# Replace config files with config files from github
	# Awesome config
	#git clone
	# Autorun on start file
	#git clone
	# Flameshot config file
	#git clone
#}


# Jump to chroot part of the install, if that part has been reached
if [ $1 = "chroot" ] ; then
	configure_arch
else
	install_arch
fi


