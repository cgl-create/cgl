#!/bin/bash

clear
read -p "CGL+ LabZ | Installing UmbrelOS Via Docker | For A Fresh Installation Only | Do You Wish To Continue? (y/n): " choice

case "$choice" in
    [yY][eE][sS]|[yY])
        clear
        echo "CGL+ LabZ | Downloading UmbrelOS Via Docker Engine"

        # Remove conflicting old packages
        sudo apt remove -y $(dpkg --get-selections docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc 2>/dev/null | cut -f1)

        # Add Docker's official GPG key:
        sudo apt update
        sudo apt install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

        # Install Docker Engine
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Add current user to docker group (Requires logout/login to take effect)
        sudo usermod -aG docker $USER

        # Run Umbrel container
        sudo docker run -d --name umbrel \
          --pid=host \
          --privileged \
          -p 80:80 -p 443:443 -p 2000:2000 \
          -v "$HOME/umbrel-data:/data" \
          -v "/var/run/docker.sock:/var/run/docker.sock" \
          --stop-timeout 60 \
          dockurr/umbrel
        ;;

    [nN][oO]|[nN])
        echo "CGL+ LabZ | Install Aborted"
        exit 0
        ;;

    *)
        echo "CGL+ LabZ | Invalid Input | Cancelling"
        exit 1
        ;;
esac
