#!/bin/bash
#
# FrankenSaT - "Frankenstein" Satellite Tracker
# https://github.com/BranoSundancer/FrankenSaT
# Version: 1.8
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
	[ -n "$VFDDEV" ] && echo "$1" >"$VFDDEV" && echo "$1" >"$VFDFILE"
}

update_conf() {
	sed -ri "s/^($2=)(.+)$/\1$3/" "$1"
}

init_conf() {
	[ ! -e "$CONFFILE" ] && [ -e "$CONFFILE.dist" ] && cp -va "$CONFFILE.dist" "$CONFFILE"
	[ "$1" = "override" ] || [ ! -e "$CONFRUNFILE" ] && cp -a "$CONFFILE" "$CONFRUNFILE"
	. "$CONFRUNFILE"
}

init_vfd() {
	# check if VFDDEV really exists and launch override subprocess
	vfd FSAT
	[ -n "$VFDDEV" ] && [ -e "$VFDDEV" ] && while sleep 0.5 ; do cat <$VFDFILE >$VFDDEV ; done &
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
		vfd EFST
		debug -n "Waiting for Elevation motor OpenWebif availability: "
		while ! ./openwebif_remote.sh $ELHOST powerstate | grep -q instandby.*false ; do debug -n . ; sleep 1 ; done
		debug "Ready."
		vfd EINI
		debug -n "Initializing Elevation motor: "
		./openwebif_remote.sh $ELHOST $ELINIT | grep -v issued
		debug "Done."
	fi
}

listen() {
	# start rotctld listener
	vfd LIST
	debug -n "Waiting for connection: "
	#export AZHOST AZCENTER AZMAX ELHOST ELCENTER ELMAX # VFDDEV PARENT
	nc -l -p 4533 -e $0 interpret
	echo $?
}

interpret() {
	# rotctl interpreter
	trap init_conf USR1
	init_conf
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
			# Dummy functonality, in fact we can't stop motors
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
	killtree $(<$PIDFILE) 2>/dev/null
	echo "Done."
}

http_response() {
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
	HTTP_CODE=302
	case ${URI[0]} in
		restart)
			./frankensat.sh restart >/dev/null 2>&1
			http_response
			;;
		reboot)
			[ -n "$ELHOST" ] && ./openwebif_remote.sh $ELHOST reboot >/dev/null 2>&1
			./openwebif_remote.sh localhost reboot >/dev/null 2>&1
			http_response
			;;
		shutdown)
			[ -n "$ELHOST" ] && ./openwebif_remote.sh $ELHOST shutdown >/dev/null 2>&1
			./openwebif_remote.sh localhost shutdown >/dev/null 2>&1
			http_response
			;;
		conf)
			update_conf "$CONFRUNFILE" "${URI[1]}" "${URI[2]}"
			INTERPRET=$(grep -l '/bin/bash$' $(grep -l '^interpret$' /proc/*/cmdline 2>/dev/null) 2>/dev/null | cut -d/ -f 3)
			[ -n "$INTERPRET" ] && kill -USR1 $INTERPRET
			http_response
			;;
		"")
			HTTP_CODE=200
			http_response
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
  background: #8f8;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 40px;
}
</style>
</head>
<body>
<center>
Current AZCENTER:
EOF
			echo "$AZCENTER&deg;"
			cat <<'EOF'
<br><br>
<div id="compass">
EOF
			for i in 90 113 135 158 180 203 225 248 270 293 315 338 0 23 45 68 ; do
				echo "<div class=\"point\"><a href=\"/conf/AZCENTER/$i\"><div>$i&deg;</div></a></div>"
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
  <div class="center-point">SET</div>
</div>
<br>
[<a href="/restart">Restart service</a>] [<a href="/reboot">Reboot device(s)</a>] [<a href="/shutdown">Shutdown device(s)</a>]
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
			HTTP_CODE=404
			http_response
			;;
	esac
	echo "$REMOTE_ADDR - - [$(date +'%d/%b/%Y:%H:%M:%S %z')] \"$REQUEST\" $HTTP_CODE 0" >>$HTTPLOGFILE
else
	# interactive or daemon
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
			if [ -e /proc/$(<$PIDFILE)/status ] ; then
				echo "Already running."
			else
				echo $$ >$PIDFILE
				init_conf override
				init_vfd
				# First parameter overrides Azimuth center from configuration file - usable for portable operation
				[ -n "$1" ] && update_conf "$CONFRUNFILE" AZCENTER "$1"
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
		*)
			echo "Usage: $SCRIPTNAME {start|stop|install|uninstall|<nnn>}"
			echo "       start: start service in background"
			echo "       stop: stop service in background"
			echo "       install: install service for autostart"
			echo "       uninstall: uninstall service for autostart"
			echo "       nnn: override Azimuth center and run once in foreground"
			;;
	esac
fi
shopt -u extglob
exit 0
