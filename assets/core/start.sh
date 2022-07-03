#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)
confdir="$1"
cd "$base"
echo $base
# chmod +x "$base/clash-macos"
#limit=`launchctl limit|grep 'maxfiles'|awk '{print $2}'`
#launchctl limit maxfiles 200000 600000 ;
/usr/bin/osascript -e "do shell script \"$base/clash-macos -d $confdir >> $confdir/clash.log 2>&1 &\" with administrator privileges"
