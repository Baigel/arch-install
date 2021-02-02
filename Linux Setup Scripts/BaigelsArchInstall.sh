#!/bin/bash

# *************** BAIGEL's ARCH INSTALL ***************

# Basic Overview:
# Desktop Environment:
# Window Manager:	Spectrwm

set -ex # x flag prints each line of script for debugging
#set -e # exit on error

# User-specific Variables (edit as necessary)
DRIVE='/dev/sda'
TIMEZONE='Europe/Belfast'
KEYMAP='us'
SWAP="2G"
HOSTNAME='baigel-pc'
USERNAME='baigel'
PASSWORD='toor'
# UEFI: 1; BIOS: 2
BOOTLOADER=2
GIT_NAME='baigel'
GIT_EMAIL='baigel'

## Alternate code to only prompt password on runtime (don't leave it here
# though, as then it would prompt both when run initially and when entering
# chroot)
#echo -n "Enter password: "
#read -sr PASSWORD
#echo
#echo -n "Repeat password: "
#read -sr PASSWORD2
#echo
#[[ "$PASSWORD" == "$PASSWORD2" ]] || ( echo "Error: Passwords did not match; exiting now."; exit 1; )

# Debug line (halts on every line)
#trap read debug

install_arch() {
	# Prompt user with inital warning
	echo 'WARNING: THIS SCRIPT WILL BLINDLY WIPE THE DISK!'
	echo 'Press Enter to continue...'
	read -sr
	echo ' -- Starting Setup --- '
	enable_logging
	# Update system clock
	echo 'Update system clock'
	timedatectl set-ntp true
	fix_mirrors
	echo ' --- Setting Up Boot and Swap Partitions --- '
	setup_partitions
	# Install important packages using pacstrap
	echo ' --- Installing Base --- '
	pacstrap /mnt base base-devel linux linux-firmware
	# Generate fstab
	echo 'Generating the fstab file'
	genfstab -U /mnt >> /mnt/etc/fstab
	# Enter chroot to continue install
	echo 'Entering chroot to continue install'
	cp "$0" /mnt/arch_install.sh
	arch-chroot /mnt ./arch_install.sh chroot
}

configure_arch() {
	echo 'Continuing setup in chroot'
	# Chroot specific setup
	echo 'Setting timezone'
	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
	echo 'Generating /etc/adjtime'
	hwclock --systohc
	echo 'Setting localization'
	echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
	echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
	locale-gen
	echo 'Set keymap'
	echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf
	echo 'Setting hostname and configuring network'
	echo "$HOSTNAME" >> /etc/hostname
	printf "127.0.0.1	localhost\n::1		localhost\n127.0.1.1	%s.localdomain	%s" $HOSTNAME $HOSTNAME >> /etc/hosts
	echo 'Adding user'
	useradd -m -s /bin/bash -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,storage,scanner,power "$USERNAME"
	echo 'Setting root password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd
	echo 'Setting user password'
	echo -en "$PASSWORD\n$PASSWORD" | passwd $USERNAME
	echo 'Adding root and user as sudoers'
	printf "root ALL=(ALL) ALL\n%s ALL=(ALL) ALL" $USERNAME > /etc/sudoers
	chmod 440 /etc/sudoers
	echo 'Add multilib repository'
	printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
	pacman -Sy --noconfirm
	echo 'Installing desktop environment'
	install_de
	echo 'Configuring X11'
	configure_x11
	echo 'Installing programs'
	install_packages
	echo 'Getting dot files'
	get_dot_files
	setup_git
	echo 'Setting up microde'
	echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
	echo 'Enable systemctl services'
	systemctl enable cpupower.service
	echo 'Updating locate'
	locale-gen
	echo ' --- Installing Bootloader (grub) --- '
	pacman -S --noconfirm grub os-prober
	[[ $BOOTLOADER -eq 1 ]] && ( sudo pacman -S --noconfirm efibootmgr )
	[[ $BOOTLOADER -eq 1 ]] && ( grub-install --recheck --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB $DRIVE )
	[[ $BOOTLOADER -eq 2 ]] && ( grub-install --recheck --bootloader-id=GRUB $DRIVE )
	grub-mkconfig -o /boot/grub/grub.cfg
	echo 'Exiting'
	exit
	umount -R /mnt
	echo ' --- Install Finished --- '
	# Set Wallpaper
	#git clone
	# Need to make the following wallpaper change permanent
	#feh --bg-scale ~/.wallpaper
	# Install atom addons
	#apm install save-workspace
}

# Functions

enable_logging() {
	echo 'Enabling logging'
	exec 1> >(tee "stdout.log")
	exec 2> >(tee "stderr.log")
}

fix_mirrors() {
	# Backing up mirrors list
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	# Recreating ordered mirror list
	reflector --latest 5 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	#reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	# Initate pacman keyring
	pacman-key --init
	pacman-key --populate archlinux
}

setup_partitions() {
	# BOOTLOADER: 1 is UEFI and 2 is BIOS)
	if [[ $BOOTLOADER -eq 1 ]]
	then
		# Setup Partitioning
		echo 'Partitioning the disk'
		sfdisk $DRIVE <<- EOF
		label: gpt
		device: $DRIVE
		unit: sectors

		,512M,uefi
		,$SWAP,swap
		;,home
		EOF
		# Format the partitions
		echo 'Formatting partitions'
		mkfs.fat -F32 ${DRIVE}1
		mkfs.ext4 ${DRIVE}3
		# Mounting partitions
		echo 'Mounting partitions'
		mount ${DRIVE}3 /mnt
		mkdir -pv /mnt/efi
		mount ${DRIVE}1 /mnt/efi
		# Enable swap
		mkswap ${DRIVE}2
		swapon ${DRIVE}2
		# Enabling efivarfs
		modprobe efivarfs
	elif [[ $BOOTLOADER -eq 2 ]]
	then
		# Setup Partitioning
		echo 'Partitioning the disk'
		sfdisk ${DRIVE} <<- EOF
		label: mbr
		device: ${DRIVE}
		unit: sectors

		,2G,swap
		;,linux
		EOF
		# Format the partitions
		echo 'Formatting partitions'
		mkfs.ext4 ${DRIVE}2
		# Mounting partitions
		echo 'Mounting partitions'
		mount ${DRIVE}2 /mnt
		mkdir -pv /mnt/boot
		# Enable swap
		mkswap ${DRIVE}1
		swapon ${DRIVE}1
	fi
}

install_packages() {
	# Core software from official Arch repositories
	DEVELOPMENT="git gcc libstdc++5 boost-libs boost git code python atom"
	TERMINAL="alacritty exa ranger dictd xorg-xev xdotool screenfetch feh"
	LATEX="texlive-core texlive-latexextra texlive-science pdftk"
	NETWORK="dhcpcd ifplugd dialog network-manager-applet"
	# wireless_tools wpa_supplicant
	GUI_TOOLS="nano dolphin firefox flameshot vlc"
	CLI_TOOLS="packer playerctl feh termdown cpupower usbutils aspell-en openssh p7zip"
	INTEL="intel-ucode"
	AUDIO="pulseaudio-alsa pulseaudio pulseaudio-bluetooth pasystray alsa-utils playerctl"
	LOGIN=""
	FONTS=""
	pacman -Sy --noconfirm $DEVELOPMENT $TERMINAL $LATEX $NETWORK $GUI_TOOLS $CLI_TOOLS $INTEL $AUDIO $LOGIN $FONTS
	# Install Doom Emacs
	#git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
	#~/.emacs.d/bin/doom install
	# Software AUR Programs and other community packages
	# Other software: github-desktop-git scrcpy yay wpa_actiond wpa_supplicant_gui
					# spotify spotify-adblock-git steam-fonts tllocalmgr-git discord steam-native
	#cat > /aur_install.sh <<- EOF
	#cd ~
	#mkdir -p aur-programs
	#cd aur-programs
	#AURPrograms=( yay wpa_actiond wpa_supplicant_gui spotify spotify-adblock-git steam-fonts tllocalmgr-git )
	#echo "\${AURPrograms}"
	#for i in "\${AURPrograms[@]}"
	#	do
	#	echo "Package: \$i"
	#	{
	#	git clone "https://aur.archlinux.org/\$i.git"
	#	cd \$i
	#	makepkg -si --noconfirm \$i
	#	cd ..
	#	} || echo "Package \$i not found!"
	#done
	#cd
	#rm -rf ~/aur-programs
	#EOF
	#chmod +x /aur_install.sh
	#su -s /bin/bash -l $USERNAME -c "/aur_install.sh"
}

configure_x11() {
	# Install X11 stuff
	pacman -S --noconfirm xorg xorg-server xorg-xinit
	# Add config details
	cat >> ~/.xinitrc <<- EOF
	/usr/bin/setxkbmap us
	#/usr/bin/numlockx off
	#/usr/bin/xautolock -time 20 -locker slock &
	~/.fehbg
	exec spectrwm
	EOF
}

install_de() {
	# Install DE (spectrwm)
	pacman -S --noconfirm spectrwm
	pacman -S --noconfirm sddm
	systemctl enable sddm.service
	echo "bar_font = xos4 Terminus:pixelsize=14" >> /.spectrwm.conf
	mkdir -p ~/.config/spectrwm
	# Spectrwm dependencies (temporary until custom config implemented)
	pacman -S --noconfirm xlockmore xterm
	# Install program manager (rofi)
	pacman -S --noconfirm rofi
}

configure_netctl() {
	echo 'Enable systemctl wifi services'
	systemctl enable net-auto-wired.service net-auto-wireless.service
}

get_dot_files() {
	# Replace config files with config files from github
	cd ~
	git clone https://github.com/Baigel/dotfiles
	mv -f ./dotfiles/spectrwm/.spectrwm.conf .
	mv -f ./dotfiles/shell_preferences/.shellrc .
	mv -f ./dotfiles/xmodmap/.xmodmaprc .
	mv -f ./dotfiles/.wallpaper .
}

setup_git(){
	git config --global user.name "${GIT_NAME}"
	git config --global user.name "${GIT_EMAIL}"
	git config --global color.ui true
	git config --global core.editor emacs
}

# Jump to chroot part of the install, if that part has been reached
if [ "$1" != "chroot" ] ; then
	install_arch
else
	configure_arch
fi
