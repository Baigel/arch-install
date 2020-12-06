#!/bin/bash

# *************** BAIGEL's ARCH INSTALL ***************
# Run system update before executing this script.

# Basic Overview
# This script requires an internet connection ("ip link" for interface name; "wifi-menu -o [interfaceName]" to connect)
# Desktop Environment:	KDE(?)
# Window Manager:	Spectrwm

set -ex

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
	HOSTNAME='ahmed-vm'
	USERNAME='ahmed'
	PASSWORD='toor'

	# Setup Logging
	echo 'Enabling logging'
	exec 1> >(tee "stdout.log")
	exec 2> >(tee "stderr.log")


	# Update system clock
	echo 'Update system clock'
	timedatectl set-ntp true

	echo ' --- Setting Up Boot and Swap Partitions --- '

	# Setup Partitioning
	echo 'Partitioning the disk'
	sfdisk /dev/sda << EOF
label: gpt
device: /dev/sda
unit: sectors

,512M,linux
,2G,swap
;,home
EOF

	# Format the partitions and enable swap
	echo 'Formatting partitions'
	mkfs.fat -F32 /dev/sda1
	mkswap /dev/sda2
	swapon /dev/sda2
	mkfs.ext4 /dev/sda3

	echo ' --- Initializing Mirror Lists and Keyrings --- '

	# Reorder mirror list
	echo 'Backing up mirrors list'
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	echo 'Recreating ordered mirror list'
	reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	#reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

	# Initate pacman keyring
	echo 'Initialise and reload keys'
	pacman-key --init
	pacman-key --populate archlinux
	pacman-key --refresh-keys

	# Mounting partitions
	echo 'Mounting partitions'
	mount /dev/sda3 /mnt
	mkdir -pv /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi

	# Install important packages using pacstrap
	echo ' --- Installing Base --- '
	pacstrap /mnt base linux linux-firmware

	# Install Base
	#echo ' --- Installing Base --- '
	#echo 'Install essential packages'
	#echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
	#pacstrap /mnt base base-devel
	#pacstrap /mnt syslinux
	# Absolute chad just gonna assume that chroot worked
	#echo 'Unmounting filesystems'
	#umount /mnt/boot
	#umount /mnt
	#swapoff /dev/vg00/swap
	#vgchange -an

	#
	#echo ' --- Entering Chroot --- '
	#cp $0 /mnt/setup.sh
	#arch-chroot /mnt ./setup.sh chroot


	# Configure the system
	echo ' --- Configuring the System --'
	echo 'Generating the fstab file'
	genfstab -U /mnt >> /mnt/etc/fstab
	echo 'Entering chroot to continue install'
	cp $0 /mnt/arch_install.sh
	arch-chroot /mnt ./arch_install.sh chroot
}

configure_arch() {

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
	echo 'Adding user'
	useradd -m -s /bin/zsh -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,storage,scanner,power,adbusers,wireshark "$USERNAME"
	echo 'Setting root password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd
	echo 'Setting user password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd $USERNAME
	echo 'Adding user as a sudoer'
	echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers
	chmod 440 /etc/sudoers
	echo 'Enable dhcpcd'
	systemctl enable dhcpcd
	echo 'Setting up microde'
	echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
	echo 'Enable systemctl services'
	systemctl enable cronie.service cpupower.service ntpd.service slim.service
	echo 'Enable systemctl wifi services'
	systemctl enable net-auto-wired.service net-auto-wireless.service
	echo 'Updating locate'
	updatedb

	echo ' --- Installing Bootloader (grub) --- '
	pacman -S grub os-prober
	grub-install --recheck --target=i386-pc /dev/sda1
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
	git clone
	# Need to make the following wallpaper change permanent
	feh --bg-scale ~/.wallpaper


	# Install atom addons
	apm install save-workspace

}

# Functions

install_packages() {
	# Install Software
	IDEs="visual-studio-code-bin atom"
	TERMINAL="konsole exa ranger dictd xorg-xev playerctl xdotool screenfetch feh"
	LATEX="texlive-core texlive-latexextra texlive-science pdftk"
	OTHER="discord steam dolphin"
	TOOLS="manjaro-pulse"
	# Fix up keys (?)
	sudo pacman-key --refresh-keys
	sudo pacman -Sy --noconfirm archlinux-keyring && sudo pacman -Su --noconfirm
	sudo hwclock -w
	# Software from Official Arch Repository
	pacman -S --noconfirm $IDES $TERMINAL $LATEX $OTHER
	# Software AUR Programs
	AURPrograms=( yay spotify spotify-adblock-git flameshot-git github-desktop-git scrcpy google-keep-nativefier tllocalmgr-git )
	cd ~
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


