#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)

/usr/bin/osascript -e 'do shell script "killall clash" with administrator privileges'
