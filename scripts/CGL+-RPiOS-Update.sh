clear
sudo killall -9 dpkg apt apt-get
clear
echo "CGL+ LabZ | Debian Trixie For RPi Update Sequence Intiated"
echo ""
echo "Please Enable Sudo Access"
echo "Please Enter You Password"
echo ""
sudo echo"Update Script Required Sudo Authentication Succesful"
clear
echo "CGL+ LabZ | Updating Your RPiOS"
echo ""
echo "Updating Package Index"
echo ""
sudo apt-get update -y
echo ""
echo "Installing Neowofetch"
echo ""
sudo apt install neowofetch -y
echo ""
echo "Running Neowofetch | System Get Details"
echo ""
neowofetch
echo ""
echo "Making Upgrades..."
echo ""
sudo apt upgrade -y
echo ""
echo "Installing Curl"
echo ""
sudo apt-get install curl
echo ""
echo "Installing SpeedTest CLi"
echo ""
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo os=debian dist=bookworm bash
sudo apt-get install speedtest -y
echo ""
echo "Finnished!"
clear
neowofetch
speedtest
echo ""
echo "CGL+ LabZ | Your RPiOS Is Now Updated"
