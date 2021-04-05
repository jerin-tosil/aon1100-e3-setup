#!/bin/bash

device=$(cat /proc/device-tree/model | awk  '{print $1}')
if [ "${device}" != "Raspberry" ] ; then
  echo "This device is not supported"
  exit 1
fi

I2S_DRIVER_DIR="$( pwd )/i2s"

sudo apt update
sudo apt upgrade -y
sudo apt install -y raspberrypi-kernel-headers raspberrypi-kernel git wiringpi


#Enable SPI
sudo raspi-config nonint do_spi 0

echo "================ Setting up I2S Device Driver ================"
# compile dts copy to overlays
dtc -@ -b 0 -Wno-unit_address_vs_reg -I dts -O dtb -o $I2S_DRIVER_DIR/aon1100e3-soundcard.dtbo $I2S_DRIVER_DIR/aon1100e3-soundcard.dts
sudo cp $I2S_DRIVER_DIR/aon1100e3-soundcard.dtbo /boot/overlays
sync

#Enable I2S
#grep -q "dtoverlay=i2s-mmap" /boot/config.txt || echo "dtoverlay=i2s-mmap" >> /boot/config.txt
sudo sed -i -e 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt
echo 'dtoverlay=aon1100e3-soundcard' | sudo tee --append /boot/config.txt > /dev/null

#Build and Install Audio driver
pushd $I2S_DRIVER_DIR > /dev/null
make
sudo make install
sync
make clean
popd > /dev/null

source variables.sh

#Setup AVS
echo "================ Setting up AVS SDK ================"
source avs-setup.sh $AVS_CONFIG_JSON -s $DEVICE_SERIAL_NUMBER -d $DEVICE_DESCRIPTION -m $DEVICE_MANUFACTURER_NAME
