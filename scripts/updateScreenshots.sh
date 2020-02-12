#!/usr/bin/env bash

if ( [[ $(grep NC_TEST_SERVER_BASEURL ~/.gradle/gradle.properties   | grep -v "#" -c) -gt 0 ]] ); then
    echo "This will not use server in docker. Please comment in .gradle/gradle.properties. Aborting!"
    exit 1
fi

## emulator
if ( [[ $(emulator -list-avds | grep uiComparison -c) -eq 0 ]] ); then
    avdmanager delete avd -n uiComparison
    (sleep 5; echo "no") | avdmanager create avd -n uiComparison -c 100M -k "system-images;android-27;google_apis;x86" --abi "google_apis/x86"
fi

emulator -avd uiComparison -no-snapshot -gpu swiftshader_indirect -no-window -no-audio -skin 500x833 -writable-system 1>/dev/null &
PID=$(echo $!)

## server
docker run --name=uiComparison nextcloudci/server 1>/dev/null &
sleep 5
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' uiComparison)

if [[ $IP = "" ]]; then
    echo "no server"
    exit 1
fi

# set server to ip address
scripts/wait_for_emulator.sh
adb root
adb remount
adb shell "sed -i '/server/d' /system/etc/hosts"
adb shell "echo \"$IP server\" >> /system/etc/hosts"

## run on server
scripts/wait_for_server.sh ${IP}

## update all screenshots
./gradlew executeScreenshotTests -Precord

## update screenshots in a class
#./gradlew executeScreenshotTests \
#-Precord \
#-Pandroid.testInstrumentationRunnerArguments.class=\
#com.owncloud.android.ui.dialog.SyncFileNotEnoughSpaceDialogFragmentTest

## update single screenshot within a class
#./gradlew executeScreenshotTests \
#-Precord \
#-Pandroid.testInstrumentationRunnerArguments.class=\
#com.owncloud.android.ui.dialog.SyncFileNotEnoughSpaceDialogFragmentTest#showNotEnoughSpaceDialogForFile

# tidy up
kill $PID
docker stop uiComparison
docker rm uiComparison
