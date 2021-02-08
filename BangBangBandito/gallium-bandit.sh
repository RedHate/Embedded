#!/bin/bash

BACKUPDIR=$PWD/bangbangbandito

if [ "$1" = "yoink" ]; then

	if [ ! -e "$BACKUPDIR" ]; then
		mkdir $BACKUPDIR
	fi

	BANDIT_LIST=`cat gallium-bandit.list`
	for d in $BANDIT_LIST; do
		if [ ! -f "$d" ]; then
			mkdir $BACKUPDIR/"$d"
		else
			cp -Rp "$d" $BACKUPDIR/"$d"
		fi
	done

fi

if [ "$1" = "install" ]; then

	BANDIT_LIST=`cat gallium-bandit.list`
	for d in $BANDIT_LIST; do
		if [ ! -f "$d" ]; then
			mkdir "$d"
		else
			cp -Rp $BACKUPDIR/"$d" "$d"
		fi
	done

fi

if [ "$1" = "" ]; then
	echo "Usage: $0 <option>"
	echo "    options: yoink / install"
fi