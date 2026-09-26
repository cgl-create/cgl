#!/bin/sh
set -eu
clear
sudo killall -9 dpkg apt apt-get 2>/dev/null || true
clear
echo 'CGL+ LabZ | Debian Trixie For RPi Update Sequence Initiated'
echo ''
echo 'Please Enable Sudo Access'
echo 'Please Enter Your Password'
echo ''
sudo -v
echo 'Update Script Required Sudo Authentication Successful'
clear
echo 'CGL+ LabZ | Updating Your RPiOS'
echo ''
echo 'Updating Package Index'
echo ''
sudo apt-get update -y
echo ''
echo 'Installing Neowofetch'
echo ''
sudo apt-get install neowofetch -y
echo ''
echo 'Running Neowofetch | System Get Details'
echo ''
command -v neowofetch >/dev/null 2>&1 && neowofetch || true
echo ''
echo 'Making Upgrades...'
echo ''
sudo apt-get upgrade -y
echo ''
echo 'Installing Curl'
echo ''
sudo apt-get install curl -y
echo ''
echo 'Installing SpeedTest CLI'
echo ''
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo os=debian dist=bookworm bash
sudo apt-get install speedtest -y
echo ''
echo 'Finished!'
clear
command -v neowofetch >/dev/null 2>&1 && neowofetch || true
command -v speedtest >/dev/null 2>&1 && speedtest || true
echo ''
echo 'CGL+ LabZ | Your RPiOS Is Now Updated'
