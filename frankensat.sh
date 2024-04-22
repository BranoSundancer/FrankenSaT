#!/bin/bash
#
# FrankenSaT - "Frankenstein" Satellite Tracker
# https://github.com/BranoSundancer/FrankenSaT
# Version: 2.0
#
# Author: Branislav Vartik
#
# See LICENSE for licensing information.
#
### BEGIN INIT INFO
# Provides: frankensat
# Default-Start:  2345
# Default-Stop:   016
# Short-Description: FrankenSaT
# Description: "Frankenstein" Satellite Tracker
### END INIT INFO

SCRIPTREAL=$(realpath ${BASH_SOURCE[0]})
SCRIPTDIR="$( cd "$( dirname "$SCRIPTREAL" )" && pwd )"
cd $SCRIPTDIR
SCRIPTNAME="${SCRIPTREAL##*/}"
BASENAME="${SCRIPTNAME%.*}"
CONFFILE="$BASENAME.conf"
CONFRUNFILE="/var/run/$CONFFILE"
PIDFILE="/var/run/$BASENAME.pid"
VFDFILE="/var/run/$BASENAME.vfd"
HTTPLOGFILE="$BASENAME.log"
[ -z $PARENT ] && PARENT="$(ps -o comm= $PPID)"
OPENWEBIFAPI=/api/
declare -A OPENWEBIFREMOTEKEYS=([1]=2 [2]=3 [3]=4 [4]=5 [5]=6 [6]=7 [7]=8 [8]=9 [9]=10 [0]=11 [menu]=139 [ok]=352 [exit]=174 [up]=103 [down]=108 [left]=105 [right]=106 [red]=398 [green]=399 [yellow]=400 [blue]=401)

killtree() {
	for child in $(pgrep -P $1) ; do
		killtree $child
	done
	[ -z "$2" ] && kill $1
}

debug() {
	# display only if not headless
	if [ -z $HEADLESS ] ; then
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
	[ -n "$VFDDEV" ] && echo "$1" >"$VFDDEV" && echo "$1" >"$VFDFILE"
}

update_confrun() {
	if grep -q "^$1=" "$CONFRUNFILE" ; then
		sed -ri "s/^($1=)(.+)$/\1$2/" "$CONFRUNFILE"
	else
		echo "$1=$2" >> "$CONFRUNFILE"
	fi
}

set_pos() {
	AZ=$(printf "%.6f" $(echo "$1" | tr , .))
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
		openwebif azhost left left left ${AZROT:0:1} ${AZROT:1:1} ${AZROT:2:1} yellow | grep -v issued >&2
		AZOLD=$AZROT
		update_confrun AZOLD "$AZOLD"
	fi
	if [ -n "$ELHOST" ] ; then
		EL=$(printf "%.6f" $(echo "$2" | tr , .))
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
			openwebif elhost left left left ${ELROT:0:1} ${ELROT:1:1} ${ELROT:2:1} yellow | grep -v issued >&2
			ELOLD=$ELROT
			update_confrun ELOLD "$ELOLD"
		fi
	fi
}

openwebif() {
	local REMOTEHOST="$AZHOST"
	local REMOTEPORT="$AZPORT"
	local COMMAND=
	if [ "$1" = "elhost" ] ; then
		REMOTEHOST="$ELHOST"
		REMOTEPORT="$ELPORT"
	fi
	shift
	for cmd in $* ; do
		echo -n "openwebif: $cmd "
		COMMAND=
		if [ ${OPENWEBIFREMOTEKEYS[$cmd]} ] ; then
			COMMAND="remotecontrol?command=${OPENWEBIFREMOTEKEYS[$cmd]}"
		else
			case $cmd in
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
		fi
		if [ -n "$COMMAND" ] ; then
			echo -e "GET $OPENWEBIFAPI$COMMAND HTTP/1.0\r\n\r" | nc -w 2 $REMOTEHOST $REMOTEPORT 2>/dev/null | grep -m 1 -A 99 '^[[:space:]]*$' | sed -r "s/(^.*\{|\}.*$)//g" | sed -r "s/, /\n/g" | grep -vE '"result": true|^[[:space:]]*$'
			# workaround for slower API after OK
			[ "$cmd" = "ok" ] && sleep 0.5
		fi
	done
}

init_conf() {
	[ "$PARENT" = "init" ] || [ "$PARENT" = "inetd" ] && HEADLESS=1
	[ ! -e "$CONFFILE" ] && [ -e "$CONFFILE.dist" ] && debug $(cp -vf "$CONFFILE.dist" "$CONFFILE")
	if [ "$1" = "override" ] || [ ! -e "$CONFRUNFILE" ] ; then
		cp -f "$CONFFILE" "$CONFRUNFILE"
		update_confrun AZOLD -1
		update_confrun ELOLD -1
	fi
	. "$CONFRUNFILE"
	AZPORT="${AZPORT:-80}"
	ELPORT="${ELPORT:-80}"
}

init_vfd() {
	# check if VFDDEV really exists and launch override subprocess
	vfd FSAT
	[ -n "$VFDDEV" ] && [ -e "$VFDDEV" ] && while sleep 0.5 ; do cat <$VFDFILE >$VFDDEV ; done &
}

init_motors() {
	debug -n "Waiting for Azimuth motor OpenWebif availability: "
	while ! openwebif azhost powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
	debug "Ready."
	vfd INIT
	debug -n "Initializing Azimuth motor: "
	openwebif azhost $AZINIT | grep -v issued
	debug "Done."
	if [ -n "$ELHOST" ] ; then
		vfd EFST
		debug -n "Waiting for Elevation motor OpenWebif availability: "
		while ! openwebif elhost powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
		debug "Ready."
		vfd EINI
		debug -n "Initializing Elevation motor: "
		openwebif elhost $ELINIT | grep -v issued
		debug "Done."
	fi
}

listen() {
	# start rotctld listener
	vfd LIST
	debug -n "Waiting for connection: "
	nc -l -p 4533 -e $0 interpret
	echo $?
}

interpret() {
	# rotctl interpreter
	trap init_conf USR1
	AZ=0.000000
	EL=0.000000
	vfd CONN
	debug "Connected."
	while read line ; do
		line=$(echo "$line" | tr -d '\r')
		debug "RECV: $line"
		cmd=$(echo "$line" | cut -d " " -f 1)
		case $cmd in
		p|get_pos)
			# send "$AZ\n$EL"
			# FIXME: Probably must be both lines send in single packet, otherwise gpredict decodes it as ERROR
			# workaround " " according to https://adventurist.me/posts/0136
			send " "
			[ -n "$ELHOST" ] && grep -q "^$AZINTVFD\$" $VFDFILE && vfd $ELINTVFD || vfd $AZINTVFD
			;;
		P|set_pos)
			send "RPRT 0"
			set_pos $(echo "$line" | cut -d " " -f 2) $(echo "$line" | cut -d " " -f 3)
			;;
		S|stop)
			# Dummy functonality, in fact we can't stop motors
			send "RPRT 0"
			vfd STOP
			;;
		q)
#			send "RPRT 0"
			vfd QUIT
			sleep 0.5
			exit
			;;
		*)
			debug "UNIMPLEMENTED"
			send "RPRT 0"
			;;
		esac
	done
	vfd DISC
	debug "Disconnected."
	sleep 0.5
}

start() {
	if [ -e "$PIDFILE" ] && [ -e "/proc/$(<$PIDFILE)/status" ] ; then
		echo "Already running."
	else
		echo -n "Starting $SCRIPTNAME: "
		start-stop-daemon -S -b -m -p $PIDFILE $SCRIPTDIR/$SCRIPTNAME daemon
		echo "Done."
	fi
}

stop() {
	echo -n "Stopping $SCRIPTNAME: "
	killtree $(<$PIDFILE) 2>/dev/null
	echo "Done."
}

http_response() {
	HTTP_CODE="$1"
	echo "HTTP/1.0 $HTTP_CODE ${HTTP_RESPONSE[$HTTP_CODE]}"
	if [ $HTTP_CODE = 302 ] ; then
		echo "Location: /"
	fi
	echo "Connection: close"
	if [[ $HTTP_CODE != 2* ]] ; then
		echo
		echo "${HTTP_RESPONSE[$HTTP_CODE]}"
	fi
}

shopt -s extglob
if [ "$PARENT" = "inetd" ] || [ "$1" = "inetd" ] ; then
	# inetd is our HTTP listener, install with:
	# echo "8080 stream tcp nowait root /home/root/frankensat.sh" >> /etc/inetd.conf ; /etc/init.d/inetd.busybox restart
	# for port 80 you need to reconfigure OpenWebif port and static IP or DHCP reservation (OpenWebif still listens on localhost, so you need to be specific with the listening IP), then install with this:
	# init 4 ; echo "$(ip -f inet -o addr show | sed -n '2p' | cut -d\  -f 7 | cut -d/ -f 1 | sed -r "s/(.+)/\1:/")80 stream tcp nowait root /home/root/frankensat.sh" >> /etc/inetd.conf ; /etc/init.d/inetd.busybox restart ; echo "config.OpenWebif.port=81" >> /etc/enigma2/settings ; init 3
	init_conf
	declare -a HTTP_RESPONSE=([200]="OK" [302]="Found" [404]="Not Found")
	line=foo
	while [ "$line" != "" ] ; do
		read -r line
		line=${line%%$'\r'}
		[ "$REQUEST" = "" ] && REQUEST=$line
	done
	REQUEST_URI=$(echo "$REQUEST" | cut -d " " -f 2)
	REMOTE_ADDR=$(netstat -tenp 2>/dev/null | sed -nr "s/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +([0-9\.]+):.+ $$\/.+$/\1/p")
	URI=(${REQUEST_URI//\// })
	case ${URI[0]} in
		service)
			./frankensat.sh ${URI[1]} "${URI[2]}" "${URI[3]}" >/dev/null 2>&1
			http_response 302
			;;
		arduino)
			# API for VosWorx Satellite Tracker (SatTrack)
			# Video: https://youtu.be/uEpd_ZVcOg4
			# Web: https://www.vosworx.com/2019/04/27/satellite-tracker-sattrack/
			# App Store: https://apps.apple.com/us/app/satellite-tracker/id1438679383
			if [ "${URI[1]}" = "rotor" ] && [ "${URI[2]}" = "azelplr" ] ; then
				http_response 200
				echo "Content-Type: text/plain; charset=utf-8"
				echo
				set_pos "${URI[3]}" "${URI[4]}"
			else
				http_response 404
			fi
			;;
		"")
			http_response 200
			cat <<'EOF'
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html>
<head>
<title>FrankenSaT</title>
<link id="favicon" rel="shortcut icon" type="image/png" href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAAsTAAALEwEAmpwYAAAB40lEQVR4nJ2SP4gaQRjFv8ul1GJFdnd03XHBXf824lpIClNeEW0sorEQbKNWio2oaGNAspCUIaaxSBVIdwjXpkqR4hRSBMRCDCFFMIkc4n5hlktybO6Uy+tmhvfjDe8B/JWPENIHgCP4D/k1Tfva7/d3giC8uy0kpqrqZj6fYz6fx0qlYgqC8P42kId+vx+z2SxOJhPsdDpYKBTQ6/WeX76LAHBvH+AIAF5JkoTVahUHgwGOx2OklJoAoIbD4c/lcnkjSdLTQ5CXhBBst9uYyWTQMAxTluUfy+USmVqt1pZS+uwgxOFw7CilqOs6rlYrvKpSqbQFgEeHIA9UVd3azeysaRoCQHEfAERR/Dibzf4xRyIRZj4FgLvXGgkhn3Rd34RCoQsWf71e/zEnk0kcDoemoihLWZbfXFsxx3E/6/W6Zer1ephIJHA6nVqxfT4fplIpHI1GWCwWTVEU2dju2BknsVjMbDQaFiQYDO54nrdiO53OL6wdwzCw2WxirVZDt9t9bk/yOJ1OYzQaNVmSeDzOzPcB4BgAnng8HmsnbGy5XA673S66XK6zqwBWzzcA+MBx3AXP899t7VhjYxtZLBa/G3l+UxkJNnHbnbUTRVEwEAgw89sbG9kjBnkBAK8vvwa/AGUo9+F30wGPAAAAAElFTkSuQmCC">
<link rel="apple-touch-icon" type="image/png" href="data:image/png;base64,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">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
</head>
<style>
body { font-size: 30px; }
a { text-decoration: none; color: red; }
a:hover { text-decoration: underline; }
#compass {
  position: relative;
  width: 700px;
  height: 700px;
  /* the radius of .item (half height or width) */
  margin: 60px;
}
#compass .point {
  width: 120px;
  height: 120px;
  line-height: 120px;
  text-align: center;
  border-radius: 100%;
  position: absolute;
  background: #8f8;
  font-size: 40px;
}
#compass .inner-compass {
  position: absolute;
  width: 350px;
  height: 350px;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
#compass .inner-compass .point {
  background: #ccc;
}
#compass .center-point {
  width: 140px;
  height: 140px;
  line-height: 140px;
  text-align: center;
  border-radius: 50%;
  position: absolute;
  background: #f88;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 40px;
}
</style>
</head>
<body>
<center>
Current AZCENTER:<br>
<br>
<div id="compass">
EOF
			for i in 90 113 135 158 180 203 225 248 270 293 315 338 0 23 45 68 ; do
				echo "<div class=\"point\"><a href=\"/service/conf/AZCENTER/$i\"><div>$i&deg;</div></a></div>"
			done
			cat <<'EOF'
  <div class="inner-compass">
    <div class="point">E</div>
    <div class="point">SE</div>
    <div class="point">S</div>
    <div class="point">SW</div>
    <div class="point">W</div>
    <div class="point">NW</div>
    <div class="point">N</div>
    <div class="point">NE</div>
  </div>
  <div class="center-point">
EOF
			echo "$AZCENTER&deg;"
			cat <<'EOF'
  </div>
  <!-- <div class="center-point" style="font-size: 120px;">&#129517;</div> -->
</div>
<br>
[<a href="/service/restart">Restart service</a>] [<a href="/service/reboot">Reboot device(s)</a>] [<a href="/service/shutdown">Shutdown device(s)</a>]
</center>
<script type="text/javascript">
<!--
function calcCircle(a) {
  for (var i = 0; i < a.length; i++) {
    var container = a[i].parentElement,
      width = container.offsetWidth,
      height = container.offsetHeight,
      radius = width / 2,
      step = (2 * Math.PI) / a.length;

    var x = width / 2 + radius * Math.cos(step * i) - a[i].offsetWidth / 2;
    var y = height / 2 + radius * Math.sin(step * i) - a[i].offsetHeight / 2;

    a[i].style.left = x + 'px';
    a[i].style.top = y + 'px';
  }
}
calcCircle(document.querySelectorAll('#compass > .point'));
calcCircle(document.querySelectorAll('#compass > .inner-compass > .point'));
// Source: https://stackoverflow.com/questions/40426442/how-to-align-html-table-cells-as-circle/40427480#40427480
-->
</script>
</body>
</html>
EOF
			;;
		*)
			http_response 404
			;;
	esac
	echo "$REMOTE_ADDR - - [$(date +'%d/%b/%Y:%H:%M:%S %z')] \"$REQUEST\" $HTTP_CODE 0" >>$HTTPLOGFILE
else
	# interactive or daemon
	init_conf
	case "$1" in
		start)
			start
			;;
		stop)
			if [ -e "$PIDFILE" ] && [ -e "/proc/$(<$PIDFILE)/status" ] ; then
				stop
			else
				echo "Not running."
			fi
			;;
		restart)
			[ -e "$PIDFILE" ] && [ -e "/proc/$(<$PIDFILE)/status" ] && stop
			sleep 0.5
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
			if [ -e "$PIDFILE" ] && [ -e "/proc/$(<$PIDFILE)/status" ] ; then
				echo "Already running."
			else
				echo $$ >$PIDFILE
				init_conf override
				init_vfd
				# Override Azimuth center in running config - usable for portable operation
				update_confrun AZCENTER "$1"
				init_motors
				listen >/dev/null
				killtree $$ parent 2>/dev/null
			fi
			;;
		daemon)
			init_conf override
			init_vfd
			init_motors
			while [ "$(listen)" = "0" ] ; do sleep 0.5 ; done
			killtree $$ parent 2>/dev/null
			;;
		interpret)
			interpret
			;;
		reboot)
			[ -n "$ELHOST" ] && openwebif elhost reboot
			openwebif azhost reboot >/dev/null 2>&1
			;;
		shutdown)
			[ -n "$ELHOST" ] && openwebif elhost shutdown
			openwebif azhost shutdown >/dev/null 2>&1
			;;
		conf)
			update_confrun "$2" "$3"
			INTERPRET=$(grep -l '/bin/bash$' /dev/null $(grep -l '^interpret$' /proc/*/cmdline 2>/dev/null) 2>/dev/null | cut -d/ -f 3 | head -n 1)
			[ -n "$INTERPRET" ] && kill -USR1 $INTERPRET
			;;
		remote)
			shift
			openwebif $*
			;;
		*)
			echo "Usage: $SCRIPTNAME <command> [<parameter1> ...]"
			echo
			echo "Commands:"
			echo "  start: start service in background"
			echo "  stop: stop service in background"
			echo "  restart: restart service in background"
			echo "  reboot: reboot device(s)"
			echo "  shutdown: shutdown device(s)"
			echo "  install: install service for autostart"
			echo "  uninstall: uninstall service for autostart"
			echo "  nnn: override Azimuth center and run once in foreground"
			echo "  conf: update running config, example:"
			echo "        $SCRIPTNAME conf AZCENTER 123"
			echo "  openwebif: access to OpenWebif API (remote keypress and power), examples:"
			echo "          $SCRIPTNAME openwebif azhost red exit up 0 ok menu"
			echo "          $SCRIPTNAME openwebif elhost shutdown"
			;;
	esac
fi
shopt -u extglob
exit 0
