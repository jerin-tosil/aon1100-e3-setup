#!/bin/bash
#
# Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#  http://aws.amazon.com/apache2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#

set -o errexit  # Exit the script if any statement fails.
#set -o nounset  # Exit the script if any uninitialized variable is used.

WORKING_DIR="$(pwd)"
SOURCE_FOLDER="sdk-source"
THIRD_PARTY_FOLDER="third-party"
BUILD_FOLDER="sdk-build"
DB_FOLDER="db"
INSTALL_FOLDER="sdk-install"

SOURCE_PATH="$WORKING_DIR/$SOURCE_FOLDER"
THIRD_PARTY_PATH="$WORKING_DIR/$THIRD_PARTY_FOLDER"
BUILD_PATH="$WORKING_DIR/$BUILD_FOLDER"
DB_PATH="$WORKING_DIR/$DB_FOLDER"
CONFIG_DB_PATH="$DB_PATH"
INSTALL_PATH="$WORKING_DIR/$INSTALL_FOLDER"
INPUT_CONFIG_FILE="$SOURCE_PATH/avs-device-sdk/Integration/AlexaClientSDKConfig.json"
OUTPUT_CONFIG_FILE="$BUILD_PATH/Integration/AlexaClientSDKConfig.json"
TEMP_CONFIG_FILE="$BUILD_PATH/Integration/tmp_AlexaClientSDKConfig.json"

AVS_GIT_URL="git://github.com/alexa/avs-device-sdk.git"
AVS_GIT_TAG="v1.22.0"

PORT_AUDIO_FILE="pa_stable_v190600_20161030.tgz"
PORT_AUDIO_DOWNLOAD_URL="http://www.portaudio.com/archives/$PORT_AUDIO_FILE"

SOUND_CONFIG="$HOME/.asoundrc"
START_SCRIPT="$WORKING_DIR/startsample.sh"

PATCH_FILE="aon_avs_patch.patch"

usage() {
	echo  'Usage: setup.sh <config-json-file> [OPTIONS]'
	echo  'The <config-json-file> can be downloaded from developer portal and must contain the following:'
	echo  '   "clientId": "<OAuth client ID>"'
	echo  '   "productId": "<your product name for device>"'
	echo  ''
	echo  'Optional parameters'
	echo  '  -s <serial-number>  If nothing is provided, the default device serial number is 12345'
	echo  '  -d <description>    The description of the device.'
	echo  '  -m <manufacturer>   The device manufacturer name.'
	echo  '  -h                  Display this help and exit'
}

install_dependencies() {
	sudo apt -y install git gcc cmake build-essential libsqlite3-dev libcurl4-openssl-dev libfaad-dev libssl-dev libsoup2.4-dev libgcrypt20-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-good libasound2-dev doxygen
}

build_port_audio() {
	# build port audio
	pushd $THIRD_PARTY_PATH > /dev/null
	wget -c $PORT_AUDIO_DOWNLOAD_URL
	tar zxf $PORT_AUDIO_FILE

	pushd portaudio
	./configure --without-jack
	make
	popd > /dev/null
	popd > /dev/null
}

clone_avs_sdk() {
	pushd $SOURCE_PATH > /dev/null
	git clone --depth 1 --branch $AVS_GIT_TAG $AVS_GIT_URL
	popd > /dev/null
}

apply_aon_patch() {
	cp $PATCH_FILE $SOURCE_PATH/avs-device-sdk/
	pushd $SOURCE_PATH/avs-device-sdk/ > /dev/null
	git apply $PATCH_FILE
	popd > /dev/null
}

build_avs_sdk() {
	pushd $BUILD_PATH > /dev/null
	cmake "$SOURCE_PATH/avs-device-sdk" \
		-DGSTREAMER_MEDIA_PLAYER=ON -DPORTAUDIO=ON \
		-DAON1100_KEY_WORD_DETECTOR=ON \
		-DPORTAUDIO_LIB_PATH="$THIRD_PARTY_PATH/portaudio/lib/.libs/libportaudio.a" \
		-DPORTAUDIO_INCLUDE_DIR="$THIRD_PARTY_PATH/portaudio/include" 

	make SampleApp -j4
	popd > /dev/null
}

generate_start_script() {
	cat << EOF > "$START_SCRIPT"
bash run.sh start $CHANNEL_0_COEFF_FILE $CHANNEL_1_COEFF_FILE
sleep 2

cd "$BUILD_PATH/SampleApp/src"

./SampleApp "$OUTPUT_CONFIG_FILE" DEBUG9
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi


CONFIG_JSON_FILE=$1
if [ ! -f "$CONFIG_JSON_FILE" ]; then
    echo "Config json file not found!"
    show_help
    exit 1
fi
shift 1

OPTIONS=s:m:d:h
while getopts "$OPTIONS" opt ; do
    case $opt in
        s )
            DEVICE_SERIAL_NUMBER="$OPTARG"
            ;;
        d )
            DEVICE_DESCRIPTION="$OPTARG"
            ;;
        m )
            DEVICE_MANUFACTURER_NAME="$OPTARG"
            ;;
        h )
            show_help
            exit 1
            ;;
    esac
done

if [[ ! "$DEVICE_SERIAL_NUMBER" =~ [0-9a-zA-Z_]+ ]]; then
   echo 'Device serial number is invalid!'
   exit 1
fi

install_dependencies

mkdir -p $BUILD_PATH
mkdir -p $SOURCE_PATH
mkdir -p $THIRD_PARTY_PATH
mkdir -p $DB_PATH

build_port_audio

if [ ! -d "$SOURCE_PATH/avs-device-sdk" ]
then
	clone_avs_sdk
	apply_aon_patch
fi

build_avs_sdk

# Create configuration file with audioSink configuration at the beginning of the file
cat << EOF > "$OUTPUT_CONFIG_FILE"
 {
    "gstreamerMediaPlayer":{
        "audioSink":"alsasink"
    },
EOF

pushd $SOURCE_PATH/avs-device-sdk/tools/Install > /dev/null
cp $WORKING_DIR/$CONFIG_JSON_FILE $SOURCE_PATH/avs-device-sdk/tools/Install
bash genConfig.sh config.json $DEVICE_SERIAL_NUMBER $CONFIG_DB_PATH $SOURCE_PATH/avs-device-sdk $TEMP_CONFIG_FILE \
  -DSDK_CONFIG_MANUFACTURER_NAME="$DEVICE_MANUFACTURER_NAME" -DSDK_CONFIG_DEVICE_DESCRIPTION="$DEVICE_DESCRIPTION"

popd > /dev/null

# Delete first line from temp file to remove opening bracket
sed -i -e "1d" $TEMP_CONFIG_FILE

# Append temp file to configuration file
cat $TEMP_CONFIG_FILE >> $OUTPUT_CONFIG_FILE

# Delete temp file
rm $TEMP_CONFIG_FILE


generate_start_script

chmod +x $START_SCRIPT
chmod +x $AON1100E3_CTRL_PNL
echo
echo " ******************* Completed Configuration/Build *******************"
echo " **** Please Reboot the RPI and execute the script startsample.sh ****"
echo " *********************************************************************"