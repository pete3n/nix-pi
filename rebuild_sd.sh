#! /usr/bin/env nix-shell
#! nix-shell -i bash -p age
IMAGE_NAME="${1:-zero2w-nixos-k6.6.5.img}"
IMAGE_PATH="./result/sd-image/$IMAGE_NAME"
MOUNT_DIR="./image"
OUTPUT_DIR="./output"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo privileges."
    exit 1
fi

# Copy age secrets files to working directory so nix can build them
echo "Creating /run/zero2w-build-secrets build placeholders..."
mkdir -p /run/zero2w-build-secrets
cp ./secrets/*.age /run/zero2w-build-secrets/
echo

echo "Building SD card image..."
nix build .#images.zero2w
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Error detected in build process, exiting..."
    exit $exit_status
fi
echo

echo "Copying result image..."
mkdir -p $OUTPUT_DIR
cp $IMAGE_PATH $OUTPUT_DIR
echo
chmod +w ${OUTPUT_DIR}/$IMAGE_NAME
echo

echo "Mounting image..."
LOOP_DEVICE=$(losetup -Pf --show "${OUTPUT_DIR}/$IMAGE_NAME")
if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to create loop device."
    exit 1
fi

mkdir -p $MOUNT_DIR
if ! mount "${LOOP_DEVICE}p2" "$MOUNT_DIR"; then
    echo "Failed to mount the second partition of $LOOP_DEVICE"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi
echo

echo "Copying ssh keys..."
if ! cp "./private/zero2w" "$MOUNT_DIR/boot/"; then
    echo "Failed to copy private system SSH key to $MOUNT_DIR/boot/"
    echo "Umounting image..." 
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    rmdir "$MOUNT_DIR"
    exit 1
fi
if ! cp "./private/admin" "$MOUNT_DIR/boot/"; then
    echo "Failed to copy private admin SSH key to $MOUNT_DIR/boot/"
    echo "Unmounting image..."
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    rmdir "$MOUNT_DIR"
    exit 1
fi

echo
echo "Unmounting image..."
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEVICE"
echo

echo "Cleaning up temporary build secrets..."
rm /run/zero2w-build-secrets -rf

echo
echo "Image creation complete"
echo 
echo "You can copy your image with a command similar to:"
echo "sudo dd of=/dev/mmcblk0 if=./output/zero2w-nixos-k6.6.5.img bs=1M status=progress"
echo "CAUTION: Confirm your SD card device is /dev/mmcblk0 before using this command"