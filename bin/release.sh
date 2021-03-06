#!/usr/bin/env bash
cd `dirname $0`/..

APP=`sds -rp productName`
VERSION=`sds -rp version`
VVERSION=v$VERSION
USER=`sds -rp author`
DMG=$APP-$VERSION.dmg

echo 'creating release ...'
github-release release -s $GH_TOKEN -u $USER -r $APP -t $VVERSION -n $VVERSION --pre-release
echo 'uploading dmg ...'
github-release upload  -s $GH_TOKEN -u $USER -r $APP -t $VVERSION -n $DMG -f $DMG

