
echo "Starting Surface Pro 5 Touchscreen config"

sudo ./script/touchscreen/build-ipts.sh       # 1. kernel module (DKMS) -> check single touch
sudo ./script/touchscreen/build-iptsd.sh      # 2. iptsd                -> multi-touch + pen
sudo ./script/touchscreen/build-touchegg.sh   # 3. optional gestures (local .deb, removable with apt)
sudo ./script/touchscreen/status.sh           # health check at any time

sudo iptsd-find-hidraw                 # e.g. /dev/hidraw2
sudo systemctl stop 'iptsd@*'
sudo iptsd /dev/hidraw2                # Ctrl+C to stop

sudo reboot now
