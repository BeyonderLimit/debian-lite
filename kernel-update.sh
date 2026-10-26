#!/usr/bin/env bash

## configure and install minimal openbox desktop environment

## check for sudo/root
if ! [ $(id -u) = 0 ]; then
  echo "This script must run with sudo, try again..."
  exit 1
fi

cat ./xsessionrc >> /home/$SUDO_USER/.xsessionrc
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.xsessionrc

apt install -y --no-install-recommends \
	build-essential dkms meson ninja-build cmake make gcc g++ \
	linux-headers-6.12.111+deb12-amd64 \
	linux-image-6.12.111+deb12-amd64 \
	linux-source-6.12 \
	ntfs-3g gvfs featherpad xfce4-terminal \
	alsa-utils pavucontrol adwaita-qt \
	qt5ct fonts-quicksand fonts-jetbrains-mono fonts-hack fonts-cantarell \
	paper-icon-theme papirus-icon-theme moka-icon-theme \
	
	
echo 
echo "Kernel update completed"	 
echo "system rebooting"
sudo apt autoremove -y && sudo reboot now
