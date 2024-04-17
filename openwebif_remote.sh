#!/bin/bash
# OpenWebif Remote
# Author: Branislav Vartik
# Version: 1.1

HOST=$1
API=/api/
shift
for cmd in $* ; do
	echo -n "CMD: $cmd "
	case $cmd in
	[0-9])
		[ $cmd -eq 0 ] && cmd=10
		COMMAND="remotecontrol?command=$((cmd+1))"
		;;
	menu)
		COMMAND="remotecontrol?command=139"
		;;
	ok)
		COMMAND="remotecontrol?command=352"
		;;
	exit)
		COMMAND="remotecontrol?command=174"
		;;
	up)
		COMMAND="remotecontrol?command=103"
		;;
	down)
		COMMAND="remotecontrol?command=108"
		;;
	left)
		COMMAND="remotecontrol?command=105"
		;;
	right)
		COMMAND="remotecontrol?command=106"
		;;
	red)
		COMMAND="remotecontrol?command=398"
		;;
	green)
		COMMAND="remotecontrol?command=399"
		;;
	yellow)
		COMMAND="remotecontrol?command=400"
		;;
	blue)
		COMMAND="remotecontrol?command=401"
		;;
	reboot)
		COMMAND="powerstate?newstate=2"
		;;
	restart)
		COMMAND="powerstate?newstate=3"
		;;
	shutdown)
		COMMAND="powerstate?newstate=1"
		;;
	powerstate)
		COMMAND="powerstate"
		;;
	*)
		echo "UNKNOWN"
		;;
	esac
	if [ -n "$COMMAND" ] ; then
		echo -e "GET $API$COMMAND HTTP/1.0\r\n\r" | nc -w 2 $HOST 80 2> /dev/null | grep -m 1 -A 99 '^[[:space:]]*$' | grep -vE '^(\{|\}| "result": true|[[:space:]]*$)'
# NetCat is twice faster than wget
#	       wget -T 3 -t 1 -qO - "http://$HOST$API$COMMAND" | grep -vE '^(\{|\}| "result": true)'
	fi
done
