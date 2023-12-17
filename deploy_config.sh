#! /bin/bash
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
            exit 1
        fi
        ;;
    *)
        echo "Error: Invalid environment or check_env.sh script not found."
        exit 1
        ;;
esac

read -p "Enter the target IP for the system to be updated: " target_ip
echo

# Copy age secrets files to working directory so nix can build them
echo "Creating /run/zero2w-build-secrets build placeholders..."
sudo mkdir -p /run/zero2w-build-secrets
sudo cp ./secrets/*.age /run/zero2w-build-secrets/
echo

echo "Deploying config with deploy-rs..."
deploy --hostname=${target_ip} --ssh-opts="-i""./private/admin" --magic-rollback=true --confirm-timeout=30
echo

echo "Cleaning up temporary build secrets..."
rm /run/zero2w-build-secrets -rf
