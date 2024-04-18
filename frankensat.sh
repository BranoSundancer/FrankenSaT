#!/bin/bash

### BEGIN INIT INFO
# Provides: frankensat
# Default-Start:  2345
# Default-Stop:   016
# Short-Description: FrankenSaT
# Description: FrankenSaT - "Frankenstein" Satellite Tracker
#              https://github.com/BranoSundancer/FrankenSaT
### END INIT INFO

# Author: Branislav Vartik
# Version: 1.5

trap 'jobs -pr | grep -q ^ && kill $(jobs -pr)' SIGINT SIGTERM EXIT
SCRIPTDIR="$( cd "$( dirname "$(realpath ${BASH_SOURCE[0]})" )" && pwd )"
cd $SCRIPTDIR
SCRIPTNAME="${BASH_SOURCE[0]##*/}"
[ -z $PARENT ] && PARENT="$(ps -o comm= $PPID)"
CONFFILE=frankensat.conf
VFDFILE=/var/run/vfd

debug() {
	# display only if not headless
	if [ "$PARENT" != "init" ] ; then
		FIRST=$1
		shift
		echo $FIRST "$*" >&2
	fi
}

send() {
	debug "SEND: $*"
	echo -e "$*"
}

vfd() {
	[ -n "$VFDDEV" ] && echo $1 > $VFDDEV && echo $1 > $VFDFILE
}

init() {
	[ ! -e $CONFFILE ] && [ -e $CONFFILE.dist ] && cp -va $CONFFILE.dist $CONFFILE
	. $CONFFILE
	# check if VFDDEV really exists and launch override subprocess
	vfd FSAT
	[ -n "$VFDDEV" ] && [ -e "$VFDDEV" ] && while sleep 0.5 ; do cat < $VFDFILE > $VFDDEV ; done &
	debug -n "Waiting for Azimuth motor OpenWebif availability: "
	while ! ./openwebif_remote.sh $AZHOST powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
	debug "Ready."
	vfd INIT
	debug -n "Initializing Azimuth motor: "
	./openwebif_remote.sh $AZHOST $AZINIT | grep -v issued
	debug "Done."
	if [ -n "$ELHOST" ] ; then
		vfd EINI
		debug -n "Waiting for Elevation motor OpenWebif availability: "
		while ! ./openwebif_remote.sh $ELHOST powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
		debug "Ready."
		debug -n "Initializing Elevation motor: "
		./openwebif_remote.sh $ELHOST $ELINIT | grep -v issued
		debug "Done."
	fi
}

listen() {
	# start rotctld listener
	vfd LIST
	debug -n "Waiting for connection: "
	export AZHOST AZCENTER AZMAX ELHOST ELCENTER ELMAX VFDDEV PARENT
	nc -l -p 4533 -e $0 interpret
}

interpret() {
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
			# workaround " " according to https://adventurist.me/posts/0136
			send " "
			[ -n "$ELHOST" ] && grep -q "^A$AZINT\$" $VFDFILE && vfd E$ELINT || vfd A$AZINT
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
			sleep 0.5
			exit
			;;
		*)
			debug "UNKNOWN COMMAND"
			send "RPRT 0"
			;;
		esac
	done
	vfd DISC
	debug "Disconnected."
	sleep 0.5
}

shopt -s extglob
case "$1" in
	start)
		echo -n "Starting $SCRIPTNAME: "
		# FIXME: PIDFILE needed for -x option
		start-stop-daemon -S -b $SCRIPTDIR/$SCRIPTNAME daemon
		echo "Done."
		;;
	stop)
		echo -n "Stopping $SCRIPTNAME: "
		# FIXME: PIDFILE needed
		echo "Not implemented yet."
		;;
	install)
		ln -vsf $SCRIPTDIR/$SCRIPTNAME /etc/init.d/
		update-rc.d $SCRIPTNAME defaults
		;;
	uninstall)
		rm -vf /etc/init.d/${SCRIPTNAME##*/}
		update-rc.d $SCRIPTNAME remove
		;;
	[0-9]*)
		init
		# First parameter overrides Azimuth center from configuration file - usable for portable operation
		[ -n "$1" ] && AZCENTER=$1
		listen
		;;
	daemon)
		init
		while true ; do listen ; sleep 0.5 ; done
		;;
	interpret)
		interpret
		;;
	*)
		echo "Usage: $SCRIPTNAME {start|stop|install|uninstall|<nnn>}"
		echo "       start: start service in background"
		echo "       stop: stop service in background"
		echo "       install: install service for autostart"
		echo "       uninstall: uninstall service for autostart"
		echo "       nnn: override Azimuth center and run once in foreground"
		;;
esac
shopt -u extglob
exit 0
