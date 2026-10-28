#!/bin/bash 
# creating directories
echo "creating directories"
mkdir /home/$USER/.config/openbox
mkdir /home/$USER/.config/volumeicon
mkdir /home/$USER/.config/tint2
mkdir /home/$USER/.config/dunst

echo "copying config files"
cp volumeicon/volumeicon /home/$USER/.config/volumeicon
cp openbox/*.* /home/$USER/.config/openbox/
cp dunst/dunstrc /home/$USER/.config/dunst/
cp tint2/tint2rc /home/$USER/.config/tint2/

echo "openbox theme configured"
