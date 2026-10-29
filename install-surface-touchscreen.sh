
echo "Starting Surface Pro 5 Touchscreen config"

bash scripts/touchscreen/build-ipts.sh       # 1. kernel module (DKMS) -> check single touch
bash scripts/touchscreen/build-iptsd.sh      # 2. iptsd                -> multi-touch + pen
bash scripts/touchscreen/build-touchegg.sh   # 3. optional gestures (local .deb, removable with apt)
bash scripts/touchscreen/status.sh           # health check at any time

echo "copying auto-rotate"
mkdir -p ~/.config/openbox/scripts

sudo apt update && sudo apt install --no-install-recommends iio-sensor-proxy inotify-tools -y

sudo cp config/openbox/scripts/surface_rotate.sh ~/.config/openbox/scripts/
chmod +x ~/.config/openbox/scripts/surface_rotate.sh

sudo iptsd-find-hidraw                 # e.g. /dev/hidraw2
sudo systemctl stop 'iptsd@*'
sudo iptsd /dev/hidraw2                # Ctrl+C to stop

sudo reboot now
