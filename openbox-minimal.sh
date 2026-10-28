#!/usr/bin/env bash

## configure and install minimal xfce desktop environment

## check for sudo/root
if ! [ $(id -u) = 0 ]; then
  echo "This script must run with sudo, try again..."
  exit 1
fi

cat ./xsessionrc >> /home/$SUDO_USER/.xsessionrc
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.xsessionrc

apt install -y --no-install-recommends \
    xinit \
    xorg \
    openbox \
    menu plank arc-theme \
    obconf \
    conky \
    jgmenu \
    picom \
    tint2 firefox-esr \
    dunst mpv \
    rofi \
    kitty fish zsh \
    feh \
    volumeicon-alsa alsa-utils pavucontrol \
    pulseaudio \    
    
apt install -y --no-install-recommends nitrogen  xbacklight pcmanfm lxappearance lxpanel gmrun xfce4-terminal \
    brightnessctl gvfs lxterminal mpv network-manager network-manager-gnome nm-tray \
    adwaita-qt \
    qt5ct fonts-quicksand fonts-jetbrains-mono fonts-hack fonts-cantarell paper-icon-theme papirus-icon-theme moka-icon-theme greybird-gtk-theme featherpad
    
echo 
echo openbox install complete, please reboot and issue 'startx'
echo
