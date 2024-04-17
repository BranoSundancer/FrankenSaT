#!/bin/bash
# FrankenSaT - "Frankenstein" Satellite Tracker
# Author: Branislav Vartik
# Version: 1.2

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPTDIR

function debug() {
	if [ "$MODE" != "inetd" ] ; then
		FIRST=$1
		shift
		echo $FIRST "$*" >&2
	fi
}

function send() {
	debug "SEND: $*"
	echo -e "$*"
}

function vfd() {
	[ -n "$VFDDEV" ] && echo $1 > $VFDDEV && echo $1 > /dev/shm/vfd
#	[ -n "$VFDDEV" ] && echo $1 > /dev/shm/vfd
}


# Detect operation mode
if [ "$1" = "-i" ] ; then
	# When Azimuth center does not change we can run forever with static config
	# echo "4533 stream tcp nowait root /home/root/frankensat.sh frankensat.sh -i" >> /etc/inetd.conf ; /etc/init.d/inetd.busybox restart
	MODE=inetd
	shift
elif [ -z $AZCENTER ] ; then
	# Normal mode
	MODE=listener
else
	# Interprets rotctl client commands after connect
	MODE=interpreter
fi

trap 'jobs -pr | grep -q ^ && sleep 1 && kill $(jobs -pr)' SIGINT SIGTERM EXIT
# First parameter overrides Azimuth center from configuration file - usable for portable operation
[ -n "$1" ] && AZCENTER=$1
if [ "$MODE" != "interpreter" ] ; then
	. frankensat.conf
	# check if VFDDEV really exists and launch override subprocess
	vfd FSAT
	[ -n "$VFDDEV" ] && [ -e "$VFDDEV" ] && while sleep 0.5 ; do cat < /dev/shm/vfd > $VFDDEV ; done &
	debug -n "Waiting for OpenWebif availability: "
	while ! ./openwebif_remote.sh $AZHOST powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
	debug "Ready."
	# Zero all digits, especially tenths, since we ill use only whole numbers
	INITSEQUENCE="exit exit exit exit exit exit blue up up up right down down down down ok exit down down ok up up 0 0 0 0"
	vfd INIT
	debug -n "Initializing Azimuth motor: "
	./openwebif_remote.sh $AZHOST $INITSEQUENCE | grep -v issued
	debug "Done."
	if [ -n "$ELHOST" ] ; then
		vfd EINI
		debug -n "Initializing Elevation motor: "
		./openwebif_remote.sh $ELHOST $INITSEQUENCE | grep -v issued
		debug "Done."
	fi
	if [ "$MODE" = "listener" ] ; then
		# start rotctld emulator
		vfd LIST
		debug -n "Waiting for connection: "
		export AZHOST AZCENTER AZMAX ELHOST ELCENTER ELMAX VFDDEV
		nc -l -p 4533 -e $0
	fi
fi
if [ "$MODE" != "listener" ] ; then
	# rotctl interpreter
	AZ=0.000000
	EL=0.000000
	AZOLD=-1
	ELOLD=-1

	vfd CONN
	debug "Connected."
	while read line ; do
		line=$(echo "$line" | tr -d '\r')
		debug "RECV: $line"
		cmd=$(echo "$line" | cut -d " " -f 1)
		case $cmd in
		p)
			# send "$AZ\n$EL"
			# FIXME: Probably must be both lines send in single packet, otherwise gpredict decodes it as ERROR
			# Workaround " " according to https://adventurist.me/posts/0136
			send " "
			[ -n "$ELHOST" ] && grep -q "^A$AZINT\$" /dev/shm/vfd && vfd E$ELINT || vfd A$AZINT
			;;
		P)
			send "RPRT 0"
			AZ=$(printf "%.6f" $(echo "$line" | cut -d " " -f 2 | tr , .))
			AZINT=${AZ%.*}
			vfd A$AZINT
			AZROT=$((AZINT+AZMAX/2-AZCENTER))
			[ $AZROT -ge 360 ] && AZROT=$((AZROT-360))
			[ $AZROT -lt 0 ] && AZROT=$((360+AZROT))
			[ $AZROT -gt 180 ] && AZROT=0
			[ $AZROT -gt $AZMAX ] && AZROT=$AZMAX
			if [ "$AZROT" -ne "$AZOLD" ] ; then
				debug "AZMOTOR: $AZROT/$AZMAX (AZCENTER:$AZCENTER)"
				AZROT=$(printf '%03d\n' "$AZROT")
				./openwebif_remote.sh $AZHOST left left left ${AZROT:0:1} ${AZROT:1:1} ${AZROT:2:1} yellow | grep -v issued >&2
				AZOLD=$AZROT
			fi
			if [ -n "$ELHOST" ] ; then
				EL=$(printf "%.6f" $(echo "$line" | cut -d " " -f 3 | tr , .))
				ELINT=${EL%.*}
				vfd E$ELINT
				ELROT=$((ELINT+ELMAX/2-ELCENTER))
				[ $ELROT -lt 0 ] && ELROT=0
				[ $ELROT -gt 90 ] && ELROT=90
				[ $ELROT -gt $ELMAX ] && ELROT=$ELMAX
				if [ "$ELROT" -ne "$ELOLD" ] ; then
					debug "ELMOTOR: $ELROT/$ELMAX (ELCENTER:$ELCENTER)"
					ELROT=$(printf '%03d\n' "$ELROT")
					./openwebif_remote.sh $ELHOST left left left ${ELROT:0:1} ${ELROT:1:1} ${ELROT:2:1} yellow | grep -v issued >&2
					ELOLD=$ELROT
				fi
			fi
			;;
		S)
			send "RPRT 0"
			vfd STOP
			;;
		q)
			send "RPRT 0"
			vfd QUIT
			exit
			;;
		*)
			debug "UNKNOWN COMMAND"
			send "RPRT 0"
			;;
		esac
	done
	vfd DISC
fi
