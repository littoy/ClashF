#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)
cd "`pwd`"
echo $base
chmod +x "$base/clash"
ulimit -n 65535
/usr/bin/osascript -e "do shell script \"ulimit -n 65535 ; $base/clash -d $base >> $base/clash.log 2>&1 &\" with administrator privileges"
