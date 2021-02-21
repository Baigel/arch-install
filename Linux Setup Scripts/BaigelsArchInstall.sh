#!/bin/bash

# *************** BAIGEL's ARCH INSTALL ***************

# Still to do:
# - Need better power management (bat vs charging, etc) (lid closing/etc)
# - Get Bluetooth working
# - Printing
# - Auto-detection of monitors (udev/xrandr)

set -ex # x flag prints each line of script for debugging
#set -e # exit on error

# User-specific Variables (edit as necessary)
DRIVE='/dev/sda'
TIMEZONE='Europe/Belfast'
KEYMAP='us'
SHELL='/bin/zsh'
SWAP="4G"
HOSTNAME='baigel-pc'
USERNAME='baigel'
PASSWORD='toor'
BOOTLOADER=2 # UEFI: 1; BIOS: 2
GIT_NAME='Baigel'
GIT_EMAIL='@gmail.com'

## Alternate code to only prompt password on runtime
#if [ "$1" == "chroot" ] ; then
#	echo -n "Enter password: "
#	read -sr PASSWORD
#	echo
#	echo -n "Repeat password: "
#	read -sr PASSWORD2
#	echo
#	[[ "$PASSWORD" == "$PASSWORD2" ]] || ( echo "Error: Passwords did not match; exiting now"; exit 1; )
#fi

# Debug line (halts on every line)
#trap read debug

install_arch() {
	# Prompt user with inital warning
	echo 'WARNING: THIS SCRIPT WILL BLINDLY WIPE THE DISK! ($DRIVE)'
	echo 'Press Enter to continue...'
	read -sr
	enable_logging
	# Update system clock
	timedatectl set-ntp true
	fix_mirrors
	setup_partitions
	# Install important packages using pacstrap
	pacstrap /mnt base base-devel linux linux-firmware
	# Generate fstab
	genfstab -U /mnt >> /mnt/etc/fstab
	# Enter chroot to continue install
	cp "$0" /mnt/arch_install.sh
	arch-chroot /mnt ./arch_install.sh chroot
}

# Many of my personal preferences will be found in this function (and the functions that it calls)
configure_arch() {
	# Setting timezone
	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
	# Generating /etc/adjtime
	hwclock --systohc
	# Setting localization
	echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
	echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
	locale-gen
	# Set keymap
	echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf
	# Setting hostname and configuring network
	echo "$HOSTNAME" >> /etc/hostname
	printf "127.0.0.1	localhost\n::1		localhost\n127.0.1.1	%s.localdomain	%s" $HOSTNAME $HOSTNAME >> /etc/hosts
	# Adding user (first install zsh)
	pacman -Sy --noconfirm zsh
	useradd -m -s $SHELL -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,storage,scanner,power "$USERNAME"
	# Setting root password
	echo -en "$PASSWORD\n$PASSWORD" | passwd
	# Setting user password
	echo -en "$PASSWORD\n$PASSWORD" | passwd $USERNAME
	# Adding root and user as sudoers
	printf "root ALL=(ALL) ALL\n%s ALL=(ALL) ALL" $USERNAME > /etc/sudoers
	chmod 440 /etc/sudoers
	# Add multilib repository
	printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
	pacman -Sy --noconfirm
	# Installing desktop environment
	install_wm
	# Configuring X11
	configure_x11
	# Installing programs
	install_packages
	# Getting dot files
	get_dot_files
	# Setup global git config vars
	setup_git
	# Setting up microde
	echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
	# Updating locate
	locale-gen
	# Installing Bootloader (grub)
	pacman -S --noconfirm grub os-prober
	[[ $BOOTLOADER -eq 1 ]] && ( sudo pacman -S --noconfirm efibootmgr )
	[[ $BOOTLOADER -eq 1 ]] && ( grub-install --recheck --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB $DRIVE )
	[[ $BOOTLOADER -eq 2 ]] && ( grub-install --recheck --bootloader-id=GRUB $DRIVE )
	grub-mkconfig -o /boot/grub/grub.cfg
	echo 'Exiting'
	exit
	umount -R /mnt
	echo 'Install finished'
}

# Sub-Functions (called by the two main functions, install_arch and configure arch)
enable_logging() {
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
		sfdisk $DRIVE <<- EOF
		label: gpt
		device: $DRIVE
		unit: sectors

		,512M,uefi
		,$SWAP,swap
		;,home
		EOF
		# Format the partitions
		mkfs.fat -F32 ${DRIVE}1
		mkfs.ext4 ${DRIVE}3
		# Mounting partitions
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
		sfdisk ${DRIVE} <<- EOF
		label: mbr
		device: ${DRIVE}
		unit: sectors

		,$SWAP,swap
		;,linux
		EOF
		# Format the partitions
		mkfs.ext4 ${DRIVE}2
		# Mounting partitions
		mount ${DRIVE}2 /mnt
		mkdir -pv /mnt/boot
		# Enable swap
		mkswap ${DRIVE}1
		swapon ${DRIVE}1
	fi
}

install_packages() {
	# User software software
	DEVELOPMENT="git gcc make cmake libstdc++5 boost-libs boost code python emacs"
	TERMINAL="alacritty exa ranger htop gtop dictd xorg-xev xdotool feh termdown nano sysstat acpi cpupower usbutils aspell-en openssh"
	LATEX="texlive-core texlive-latexextra texlive-science"
	NETWORK="dhcpcd ifplugd dialog networkmanager"
	BLUETOOTH="bluez bluez-tools blueman"
	GUI_TOOLS="pcmanfm firefox flameshot vlc lxrandr"
	ZIP_TOOLS="p7zip unrar gzip unzip"
	INTEL="intel-ucode"
	AUDIO="pulseaudio-alsa pulseaudio pavucontrol pulseaudio-bluetooth alsa-utils playerctl"
	NOTIFICATIONS="notification-daemon dunst"
	PDF="okular pdftk"
	PRINTING="cups cups-pdf system-config-printer"
	APPEARANCE="gtk3 breeze-gtk lxappearance breeze-icons"
	OTHER="i3lock"
	pacman -Sy --noconfirm $DEVELOPMENT $TERMINAL $LATEX $NETWORK $GUI_TOOLS $INTEL $AUDIO $NOTIFICATIONS $PDF $PRINTING $APPEARANCE $OTHER
	# Enable Deamons
	systemctl enable NetworkManager
	systemctl enable cpupower.service
	systemctl enable bluetooth
	systemctl enable cups
	# Other AUR programs: yay tllocalmgr-git joplin pm-utils steam-fonts discord
	# Get Doom Emacs (~/.emacs.d/bin is added to PATH by .shellrc, meaning user will still need to run `doom` then `doom install`, just running the latter didn't seem to work??)
	git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$USERNAME/.emacs.d
	# Powerlevel10k (note: sourcing p10k config is done in ~ /zshrc)
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/$USERNAME/.powerlevel10k
	echo "[[ \$- == *i* ]] && source ~/.powerlevel10k/powerlevel10k.zsh-theme" >> /home/$USERNAME/.zshrc
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
	dunst
	EOF
}

install_wm() {
	# Install DE (spectrwm)
	pacman -S --noconfirm spectrwm
	pacman -S --noconfirm sddm
	systemctl enable sddm.service
	mkdir -p ~/.config/spectrwm
	# Install program manager (rofi)
	pacman -S --noconfirm rofi
}

# Not currently called (why?)
configure_netctl() {
	systemctl enable net-auto-wired.service net-auto-wireless.service
}

get_dot_files() {
    # Create .zshrc (for sourcing)
    touch /home/$USERNAME/.zshrc
    #chmod 776 /home/$USERNAME/.zshrc
    # Force interactive login and non-login shell to use my shell preferences (/etc/profile only needed for autorun stuff; inelegant, yes, but also easy)
    echo 'source ~/.shellrc' >> /etc/profile
    echo 'source ~/.shellrc' >> /home/$USERNAME/.zshrc
	# Replace config files with config files from github
    cd /home/$USERNAME
    GIT_FOLDER="${GIT_NAME}-Git"
    mkdir ${GIT_FOLDER}
    git clone https://github.com/Baigel/dotfiles "${GIT_FOLDER}/dotfiles"
    # Get all $HOME directory configs
	ln -s ./${GIT_FOLDER}/dotfiles/spectrwm/.spectrwm.conf .spectrwm.conf
    ln -s ./${GIT_FOLDER}/dotfiles/spectrwm/.baraction.sh .baraction.sh
    ln -s ./${GIT_FOLDER}/dotfiles/shell_preferences/.shellrc .shellrc
    ln -s ./${GIT_FOLDER}/dotfiles/xmodmap/.xmodmaprc .xmodmaprc
    ln -s ./${GIT_FOLDER}/dotfiles/.wallpaper .wallpaper
    # Get ranger config
    mkdir -p /home/$USERNAME/.config/ranger
    ln -s ./${GIT_FOLDER}/dotfiles/ranger/rc.conf .config/ranger/rc.conf
    # Get notifications (dunst) config
    mkdir -p /home/$USERNAME/.config/dunst
    ln -s ./${GIT_FOLDER}/dotfiles/dunst/dunstrc .config/dunst/dunstrc
    # Copy systemd files over (instead of soft linking, to avoid permission issues)
    cp -f ./${GIT_FOLDER}/dotfiles/systemd/logind.conf /etc/systemd/logind.conf
    # Give directory ownership to user (recursive)
    chown $USERNAME:$USERNAME -R /home/$USERNAME
}

setup_git() {
	git config --global user.name "${GIT_NAME}"
	git config --global user.name "${GIT_EMAIL}"
	git config --global color.ui true
	git config --global core.editor emacs
}

# Jump to chroot part of the install, if called with $1=chroot
if [ "$1" != "chroot" ] ; then
	install_arch
else
	configure_arch
fi
