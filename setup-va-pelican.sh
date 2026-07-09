#!/bin/bash

BASE_DIR="/usr/share"

setupDocker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is not installed. Installing..."

        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        echo "Docker is installed."
    fi
}

setupWings() {
    local dir="/usr/share/va-wings"
    
    run_install() {
        mkdir -p "$dir/config"
        cd "$dir" || exit

        cat << EOF > "./docker-compose.yml"
services:
  wings:
    image: ghcr.io/pelican-dev/wings:latest
    container_name: wings
    restart: always
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config:/etc/pelican
      - /var/lib/pelican/volumes:/var/lib/pelican/volumes
EOF
        
        docker compose pull
        docker compose up -d
    }

    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        read -p "Wings already exists. [U]pdate or [R]einstall? " action
        case "$action" in
            [Uu]* ) 
                echo "Updating..."
                run_install 
                ;;
            [Rr]* ) 
                echo "Reinstalling..."
                sudo rm -rf "$dir"
                run_install 
                ;;
            * ) echo "Skipping." ;;
        esac
    else
        echo "Installing wings in $dir..."
        mkdir -p "$dir"
        run_install
    fi
}

setupPanel() {
    local dir="/usr/share/va-panel"
    
    run_install() {
        mkdir -p "$dir/config"
        cd "$dir" || exit

        read -p "App URL? " APP_URL
        read -p "Admin email? " ADMIN_EMAIL
        read -p "Use SSL [Y|n]? " USE_SSL

        if [[ "$USE_SSL" =~ [Yy] ]]; then
            port_config="      - 80:80
      - 443:443"
        else
            port_config="      - 80:80"
        fi

        cat << EOF > "./docker-compose.yml"
services:
  panel:
    image: ghcr.io/pelican-dev/panel:latest
    restart: always
    networks:
      - default
    ports:
$port_config
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - pelican-data:/pelican-data
      - pelican-logs:/var/www/html/storage/logs
    environment:
      XDG_DATA_HOME: /pelican-data
      APP_URL: $APP_URL
      ADMIN_EMAIL: $ADMIN_EMAIL

volumes:
  pelican-data:
  pelican-logs:

networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
        
        docker compose pull
        docker compose up -d
    }

    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        read -p "Panel already exists. [U]pdate or [R]einstall? " action
        case "$action" in
            [Uu]* ) 
                echo "Updating..."
                run_install 
                ;;
            [Rr]* ) 
                echo "Reinstalling..."
                sudo rm -rf "$dir"
                run_install 
                ;;
            * ) echo "Skipping." ;;
        esac
    else
        echo "Installing panel in $dir..."
        mkdir -p "$dir"
        run_install
    fi
}

echo "--- VoidAngel Pelican Setup ---"

setupDocker

read -p "Install type (panel|wings): " INSTALL_TYPE

case $INSTALL_TYPE in
    panel)
        setupPanel
        ;;
    wings)
        setupWings
        ;;
    *)
        echo "Invalid selection. Please choose 'panel' or 'wings'."
        exit 1
        ;;
esac