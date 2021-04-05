#!/bin/bash

CHANNEL_0_COEFF=$2
CHANNEL_1_COEFF=$3

case "$1" in
	start)
		printf "Starting AON1100 E3 Application ... "
        #route audio to all sinks
		pactl load-module module-combine-sink
		
        ./aon1100e3 $CHANNEL_0_COEFF $CHANNEL_1_COEFF&
        
		echo "done."
		;;
	stop)
		printf "Stopping AON1100 E3 Application ..."
		pactl unload-module module-combine-sink
		
		kill -2  `ps aux | grep aon1100e3 | sed -n 1p | awk '{print $2}'`
		
		echo "done."
		;;
	*)
		echo "usage: $0 {start|stop}"
		;;
esac
