#!/usr/bin/env bash
bash ./scripts/debian-openbox.sh

# Create target configuration paths
mkdir -p ~/.config/openbox
mkdir -p ~/.config/tint2

# Copy default configurations into your user profile
cd ~/debian-lite/
cp config/openbox/rc.xml ~/.config/openbox/
cp config/tint2/tint2rc ~/.config/tint2/
cp config/openbox/autostart ~/.config/openbox/


sudo apt install --no-install-recommends alsa-utils brightnessctl volumeicon-alsa -y

# Install the missing Openbox engine plugins for your GUI utility
sudo apt install --no-install-recommends lxappearance-obconf -y

# Create your local themes directory if it doesn't exist
mkdir -p ~/.themes

# Clone or drop your chosen HiDPI theme folder into ~/.themes
# (Example using Celestial theme repository setup)
git clone https://github.com/zquestz/celestial-gtk-theme /tmp/celestial
cp -r /tmp/celestial/themes/* ~/.themes/

# Launch the visual customization wrapper
lxappearance

# Handle click tapping
sudo apt update && sudo apt install --no-install-recommends touchegg xdotool xinput -y

# Find your touchscreen ID using 'xinput list' if needed, though libinput usually applies this globally
xinput set-prop "Intel Precise Touch Screen" "libinput Tapping Enabled" 1 2>/dev/null || true

# Install required build tools and python utilities
sudo apt install --no-install-recommends git python3-pip python3-setuptools dmidecode -y

# Clone and run the official installer
git clone https://github.com/AdnanHodzic/auto-cpufreq.git /tmp/auto-cpufreq
cd /tmp/auto-cpufreq && sudo ./auto-cpufreq-installer

sudo apt install --no-install-recommends powertop -y

# Accelerometer Auto-Rotation
sudo apt update && sudo apt install --no-install-recommends iio-sensor-proxy inotify-tools -y

# create target tracking
mkdir -p ~/.config/openbox/scripts
cp /scripts/surface_rotate.sh ~/.config/openbox/scripts/

echo "==>Installing touchscreen dependencies.."
# touchscreen config
sudo apt install -y git build-essential meson dkms libssl-dev libsdl2-dev libcurl4-openssl-dev libli11-dev libeigen3-dev libfmt-dev libinih-dev glslc libgsl-dev libspdlog-dev cmake make autoconf automake libcairomm-1.16-dev gcc g++ 


echo "check documentation for service configuraton"
