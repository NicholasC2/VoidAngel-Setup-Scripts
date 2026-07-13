#!/bin/bash

BASE_DIR="$HOME"

setupDocker() {
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        echo "Docker or Docker Compose plugin not found. Installing..."

        sudo pacman -Sy --noconfirm

        sudo pacman -S --noconfirm \
            docker \
            docker-compose

        sudo systemctl enable --now docker

        echo "Docker and Docker Compose installed successfully."
    else
        echo "Docker and Docker Compose are already installed and functional."
    fi
}

setupWings() {
    local dir="/usr/share/va-wings"

    run_install() {
        sudo mkdir -p "$dir"
        cd "$dir" || exit

        cat << EOF | sudo tee "./docker-compose.yml" > /dev/null
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

        sudo docker compose pull
        sudo docker compose up -d
    }

    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        read -p "Wings already exists. [U]pdate or [R]einstall? " action

        case "$action" in
            [Uu]*)
                echo "Updating..."
                run_install
                ;;
            [Rr]*)
                echo "Reinstalling..."
                cd "$dir"
                sudo docker compose down
                cd ..
                sudo rm -rf "$dir"
                run_install
                ;;
            *)
                echo "Skipping."
                ;;
        esac
    else
        echo "Installing wings in $dir..."
        run_install
    fi
}

setupPanel() {
    local dir="/usr/share/va-panel"

    run_install() {
        sudo mkdir -p "$dir"
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

        cat << EOF | sudo tee "./docker-compose.yml" > /dev/null
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

        sudo docker compose pull
        sudo docker compose up -d
    }

    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        read -p "Panel already exists. [U]pdate or [R]einstall? " action

        case "$action" in
            [Uu]*)
                echo "Updating..."
                run_install
                ;;
            [Rr]*)
                echo "Reinstalling..."
                cd "$dir"
                sudo docker compose down
                cd ..
                sudo rm -rf "$dir"
                run_install
                ;;
            *)
                echo "Skipping."
                ;;
        esac
    else
        echo "Installing panel in $dir..."
        run_install
    fi
}


echo "--- VoidAngel Pelican Setup ---"
echo "v0.3 (Arch/pacman)"

setupDocker

read -p "Install type (panel|wings): " INSTALL_TYPE

case "$INSTALL_TYPE" in
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