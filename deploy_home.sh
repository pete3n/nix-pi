#!/bin/bash
#

./check_env.sh
exit_status=$?

case $exit_status in
    0)
        echo "Environment setup required. Running set_env.sh..."
        ./set_env.sh
        echo "Restarting the script..."
        exec "$0" "$@"
        ;;
    1)
        NIX="/run/current-system/sw/bin/nix"
        ;;
    2)
        NIX="/nix/var/nix/profiles/default/bin/nix"
        if [ "$(id -u)" -eq 0 ]; then
            echo "This script should not be run as sudo when using Nix without NixOS"
            ./restore_env.sh
            exit 1
        fi
        ;;
    *)
        echo "Error: Invalid environment or check_env.sh script not found."
        ./restore_env.sh
        exit 1
        ;;
esac

provision_ip=$1

echo "Deploying config with deploy-rs..."
deploy .#zero2w.home --hostname=${provision_ip} --ssh-opts="-i""./private/admin" --magic-rollback=true --confirm-timeout=30
exit_status=$?
if [[ exit_status -ne 0 ]]; then
    ./restore_env.sh
    exit 1
fi
echo

./restore_env.sh
