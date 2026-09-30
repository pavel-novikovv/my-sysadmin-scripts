#!/bin/bash
set -euo pipefail

readonly LAB_DIR=/mnt/raid-lab
readonly DISK_MB=512
readonly RAID_DEV=/dev/md0
readonly RAID_MOUNT=/mnt/raid
readonly MDADM_CONF=/etc/mdadm/mdadm.conf
readonly VG_NAME=vg_data
readonly LV_NAME=lv_logs
readonly LV_SIZE=200M
readonly LV_MOUNT=/mnt/logs

fail() {
    echo "storage: $1" >&2
    exit 1
}

(( EUID == 0 )) || fail "запустите через sudo"

for cmd in mdadm losetup pvs pvcreate vgcreate vgchange lvcreate mkfs.ext4 mountpoint udevadm; do
    command -v "$cmd" >/dev/null 2>&1 || fail "не найдена команда $cmd, установите пакеты mdadm и lvm2"
done

attach() {
    local image="$LAB_DIR/$1"
    local device
    [[ -f "$image" ]] || dd if=/dev/zero of="$image" bs=1M count="$DISK_MB" status=none
    device=$(losetup -j "$image" | cut -d: -f1 | head -n 1)
    [[ -n "$device" ]] || device=$(losetup -fP --show "$image")
    echo "$device"
}

mount_once() {
    mountpoint -q "$2" || mount "$1" "$2"
}

setup_raid() {
    if mdadm --detail "$RAID_DEV" >/dev/null 2>&1; then
        return
    fi
    if mdadm --examine "$1" >/dev/null 2>&1; then
        mdadm --assemble "$RAID_DEV" "$1" "$2"
        return
    fi
    mdadm --create "$RAID_DEV" --run --level=1 --raid-devices=2 "$1" "$2"
    mkfs.ext4 -q "$RAID_DEV"
    grep -q "^ARRAY $RAID_DEV " "$MDADM_CONF" 2>/dev/null || mdadm --detail --brief "$RAID_DEV" >> "$MDADM_CONF"
}

setup_lvm() {
    if pvs "$1" >/dev/null 2>&1; then
        vgchange -ay "$VG_NAME" >/dev/null
        return
    fi
    pvcreate -q "$1"
    vgcreate -q "$VG_NAME" "$1"
    lvcreate -q -y -L "$LV_SIZE" -n "$LV_NAME" "$VG_NAME"
    mkfs.ext4 -q "/dev/$VG_NAME/$LV_NAME"
}

mkdir -p "$LAB_DIR" "$RAID_MOUNT" "$LV_MOUNT"

loop1=$(attach disk1.img)
loop2=$(attach disk2.img)
loop3=$(attach disk3.img)
udevadm settle

setup_raid "$loop1" "$loop2"
mount_once "$RAID_DEV" "$RAID_MOUNT"

setup_lvm "$loop3"
mount_once "/dev/$VG_NAME/$LV_NAME" "$LV_MOUNT"

echo "storage: RAID 1 $RAID_DEV ($loop1 + $loop2) смонтирован в $RAID_MOUNT"
echo "storage: LVM /dev/$VG_NAME/$LV_NAME ($loop3) смонтирован в $LV_MOUNT"
