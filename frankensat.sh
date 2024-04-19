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
# Version: 1.7

SCRIPTREAL=$(realpath ${BASH_SOURCE[0]})
SCRIPTDIR="$( cd "$( dirname "$SCRIPTREAL" )" && pwd )"
cd $SCRIPTDIR
SCRIPTNAME="${SCRIPTREAL##*/}"
[ -z $PARENT ] && PARENT="$(ps -o comm= $PPID)"
CONFFILE=frankensat.conf
PIDFILE=/var/run/frankensat.pid
VFDFILE=/var/run/vfd

killtree() {
	for child in $(pgrep -P $1) ; do
		killtree $child
	done
	[ -z "$2" ] && kill $1
}

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

init_conf() {
	[ ! -e $CONFFILE ] && [ -e $CONFFILE.dist ] && cp -va $CONFFILE.dist $CONFFILE
	. $CONFFILE
	# check if VFDDEV really exists and launch override subprocess
	vfd FSAT
	[ -n "$VFDDEV" ] && [ -e "$VFDDEV" ] && while sleep 0.5 ; do cat < $VFDFILE > $VFDDEV ; done &
}

init_motors() {
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
	echo $?
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
			[ -n "$ELHOST" ] && grep -q "^$AZINTVFD\$" $VFDFILE && vfd $ELINTVFD || vfd $AZINTVFD
			;;
		P)
			send "RPRT 0"
			AZ=$(printf "%.6f" $(echo "$line" | cut -d " " -f 2 | tr , .))
			AZINT=${AZ%.*}
			AZROT=$((AZINT+AZMAX/2-AZCENTER))
			[ $AZROT -ge 360 ] && AZROT=$((AZROT-360))
			[ $AZROT -lt 0 ] && AZROT=$((360+AZROT))
			[ $AZROT -gt 180 ] && AZROT=0
			[ $AZROT -gt $AZMAX ] && AZROT=$AZMAX
			if [ "$AZROT" -ne "$AZOLD" ] ; then
				AZINTVFD=A$(printf '%03d\n' "$AZINT")
				vfd $AZINTVFD
				debug "AZMOTOR: $AZROT/$AZMAX (AZCENTER:$AZCENTER)"
				AZROT=$(printf '%03d\n' "$AZROT")
				./openwebif_remote.sh $AZHOST left left left ${AZROT:0:1} ${AZROT:1:1} ${AZROT:2:1} yellow | grep -v issued >&2
				AZOLD=$AZROT
			fi
			if [ -n "$ELHOST" ] ; then
				EL=$(printf "%.6f" $(echo "$line" | cut -d " " -f 3 | tr , .))
				ELINT=${EL%.*}
				ELROT=$((ELINT+ELMAX/2-ELCENTER))
				[ $ELROT -lt 0 ] && ELROT=0
				[ $ELROT -gt 90 ] && ELROT=90
				[ $ELROT -gt $ELMAX ] && ELROT=$ELMAX
				if [ "$ELROT" -ne "$ELOLD" ] ; then
					ELINTVFD=E$(printf '%03d\n' "$ELINT")
					vfd $ELINTVFD
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

start() {
	if [ -e /proc/$(<$PIDFILE)/status ] ; then
		echo "Already running."
	else
		echo -n "Starting $SCRIPTNAME: "
		start-stop-daemon -S -b -m -p $PIDFILE $SCRIPTDIR/$SCRIPTNAME daemon
		echo "Done."
	fi
}

stop() {
	echo -n "Stopping $SCRIPTNAME: "
	killtree $(<$PIDFILE) 2> /dev/null
	echo "Done."
}

shopt -s extglob
case "$1" in
	start)
		start
		;;
	stop)
		if [ -e /proc/$(<$PIDFILE)/status ] ; then
			stop
		else
			echo "Not running."
		fi
		;;
	restart)
		[ -e /proc/$(<$PIDFILE)/status ] && stop
		start
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
		if [ -e /proc/$(<$PIDFILE)/status ] ; then
			echo "Already running."
		else
			echo $$ > $PIDFILE
			init_conf
			# First parameter overrides Azimuth center from configuration file - usable for portable operation
			[ -n "$1" ] && AZCENTER=$1
			init_motors
			listen > /dev/null
			killtree $$ parent 2> /dev/null
		fi
		;;
	daemon)
		init_conf
		init_motors
		while [ $(listen) = "0" ] ; do sleep 0.5 ; done
		killtree $$ parent 2> /dev/null
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
