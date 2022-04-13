#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)
cd "$base"

/usr/bin/osascript -e 'do shell script "killall clash" with administrator privileges'
