#!/bin/bash

IMAGE_NAME="${1:-zero2w-nixos-k6.6.5.img}"
IMAGE_PATH="./result/sd-image/$IMAGE_NAME"
WIRELESS_ENV_PATH="wireless.env"
MOUNT_DIR="/tmp/sd-image"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo privileges."
    exit 1
fi

read -p "Enter SSID for the provisioning network: " ssid
read -s -p "Enter password for the provisioning network: " password
echo 

echo "PROVISION_SSID=\"$ssid\"" > ${WIRELESS_ENV_PATH}
echo "PROVISION_PASS=\"$password\"" >> ${WIRELESS_ENV_PATH}

echo "SSID and password have been saved to ${WIRELESS_ENV_PATH}"

LOOP_DEVICE=$(losetup -Pf --show "$IMAGE_PATH")
if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to create loop device."
    exit 1
fi

mkdir -p "$MOUNT_DIR"

if ! mount "${LOOP_DEVICE}p2" "$MOUNT_DIR"; then
    echo "Failed to mount the first partition of $LOOP_DEVICE"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

if ! cp "$WIRELESS_ENV_PATH" "$MOUNT_DIR/boot/"; then
    echo "Failed to copy $WIRELESS_ENV_PATH to $MOUNT_DIR/boot/"
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEVICE"

echo "wireless.env copied successfully to $IMAGE_PATH"
