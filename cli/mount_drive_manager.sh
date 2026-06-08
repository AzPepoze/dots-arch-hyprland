#!/bin/bash

# This script manages auto-mounting drives using /etc/fstab.

#-------------------------------------------------------
# Configuration
#-------------------------------------------------------
FSTAB_FILE="/etc/fstab"
FSTAB_BACKUP_DIR="/var/backups" # Standard backup location
FSTAB_MANAGED_TAG="# MANAGED_BY_AUTO_MOUNT_SCRIPT" # Tag to identify entries added by this script
SERVICE_NAME="ntfs-mount-fix.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

#-------------------------------------------------------
# Helper Functions
#-------------------------------------------------------

_backup_fstab() {
    echo ">> Creating a backup of $FSTAB_FILE..."
    sudo mkdir -p "$FSTAB_BACKUP_DIR"
    sudo cp "$FSTAB_FILE" "$FSTAB_BACKUP_DIR/fstab.bak-$(date +%Y%m%d_%H%M%S)"
    if [ $? -eq 0 ]; then
        echo "OK: Backup created at $FSTAB_BACKUP_DIR."
        return 0
    else
        echo "ERROR: Failed to create fstab backup." >&2
        return 1
    fi
}

_list_available_partitions() {
    echo ">> Listing available partitions (excluding boot, swap, and already mounted system partitions):"
    echo "---------------------------------------------------------------------------------------------------"
    echo "IDX | DEVICE | UUID | FSTYPE | SIZE | MOUNTPOINT"
    echo "---------------------------------------------------------------------------------------------------"
    lsblk -l -n -o NAME,UUID,FSTYPE,SIZE,MOUNTPOINT,TYPE | grep "part" | \
    awk '
    {
        device=$1;
        uuid=$2;
        fstype=$3;
        size=$4;
        mountpoint=$5;
        type=$6;

        if (fstype == "swap") {
            next;
        }

        if (mountpoint == "/" || mountpoint == "/boot" || mountpoint == "/boot/efi") {
            next;
        }

        if (uuid == "") {
            next;
        }
        
        printf("%-3s | /dev/%-6s | %-36s | %-6s | %-6s | %-s\n", NR, device, uuid, fstype, size, mountpoint);
    }'
    echo "---------------------------------------------------------------------------------------------------"
}

_get_partition_details() {
    local index=$1
    local filtered_partitions=$(lsblk -l -n -o NAME,UUID,FSTYPE,SIZE,MOUNTPOINT,TYPE | grep "part" | \
        awk '
        {
            device=$1;
            uuid=$2;
            fstype=$3;
            size=$4;
            mountpoint=$5;
            type=$6;

            if (fstype == "swap") {
                next;
            }

            if (mountpoint == "/" || mountpoint == "/boot" || mountpoint == "/boot/efi") {
                next;
            }

            if (uuid == "") {
                next;
            }
            
            print $0;
        }'
    )
    
    local line=$(echo "$filtered_partitions" | sed -n "${index}p")
    
    if [ -z "$line" ]; then
        echo "ERROR: Invalid partition index." >&2
        return 1
    fi
    
    # Extract details using awk
    echo "$line" | awk '{
        print "DEVICE=" $1;
        print "UUID=" $2;
        print "FSTYPE=" $3;
        print "SIZE=" $4;
        print "MOUNTPOINT=" $5;
        print "TYPE=" $6;
    }'
}

#-------------------------------------------------------
# Core Functions
#-------------------------------------------------------

_check_and_fix_ntfs() {
    local device="/dev/$1"
    local fstype="$2"
    
    if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs-3g" || "$fstype" == "ntfs3" ]]; then
        echo ">> Checking NTFS partition $device for issues..."
        if sudo ntfsfix -d "$device" > /dev/null 2>&1; then
            echo "OK: $device was successfully processed by ntfsfix."
            return 0
        else
            echo "WARNING: ntfsfix failed for $device. It might require manual intervention or chkdsk in Windows." >&2
            return 1
        fi
    fi
    return 0
}

_apply_mounts() {
    echo ">> Running 'sudo mount -a' to apply all changes..."
    if sudo mount -a; then
        echo "OK: All partitions mounted successfully."
        return 0
    else
        echo "WARNING: 'sudo mount -a' failed. Attempting to identify and fix NTFS issues..." >&2
        
        # Identify NTFS partitions in fstab that are not mounted
        local unmounted_ntfs=$(grep "$FSTAB_MANAGED_TAG" "$FSTAB_FILE" | grep -E "ntfs|ntfs3" | while read -r line; do
            local uuid=$(echo "$line" | grep -oP 'UUID=\K[a-fA-F0-9-]+')
            local mount_point=$(echo "$line" | awk '{print $2}')
            if ! mountpoint -q "$mount_point"; then
                local dev_path=$(blkid -U "$uuid" 2>/dev/null)
                if [ -n "$dev_path" ]; then
                    basename "$dev_path"
                fi
            fi
        done)

        if [ -n "$unmounted_ntfs" ]; then
            for dev in $unmounted_ntfs; do
                echo ">> Found unmounted NTFS partition: /dev/$dev"
                _check_and_fix_ntfs "$dev" "ntfs3"
            done
            
            echo ">> Retrying 'sudo mount -a' after fixes..."
            if sudo mount -a; then
                echo "OK: All partitions mounted successfully after fixes."
                return 0
            else
                echo "ERROR: 'sudo mount -a' still fails. Manual inspection required." >&2
                return 1
            fi
        else
            echo "ERROR: 'sudo mount -a' failed, but no unmounted managed NTFS partitions were found to fix." >&2
            return 1
        fi
    fi
}

add_fstab_entry() {
    echo ">> Adding an entry to $FSTAB_FILE..."
    if ! _backup_fstab; then
        return 1
    fi

    _list_available_partitions
    read -p "Enter the index(es) of the partition(s) to add (space-separated): " -a part_indices
    
    for part_index in "${part_indices[@]}"; do
        echo "Processing partition index: $part_index"
        eval "$(_get_partition_details "$part_index")"
        
        if [ -z "$UUID" ]; then
            echo "ERROR: Could not get partition details for index $part_index. Skipping this partition." >&2
            continue
        fi

        echo "Selected Partition: /dev/$DEVICE (UUID: $UUID, FSTYPE: $FSTYPE)"

        # Pre-fix NTFS before adding it if it has issues
        _check_and_fix_ntfs "$DEVICE" "$FSTYPE"

        local default_mount_point="/mnt/$DEVICE"
        if [ -n "$FSTYPE" ]; then
            # If filesystem type is known, try to make a more descriptive mount point
            local label=$(lsblk -n -o LABEL "/dev/$DEVICE" | xargs)
            if [ -n "$label" ]; then
                default_mount_point="/mnt/$(echo "$label" | sed 's/[^a-zA-Z0-9_.-]/_/g')"
            else
                default_mount_point="/mnt/$UUID"
            fi
        fi

        read -p "Enter desired mount point for /dev/$DEVICE (e.g., /mnt/data, default: $default_mount_point): " mount_point
        mount_point="${mount_point:-$default_mount_point}"

        # Ensure mount point exists
        if [ ! -d "$mount_point" ]; then
            echo ">> Mount point '$mount_point' does not exist. Creating it..."
            sudo mkdir -p "$mount_point"
            if [ $? -ne 0 ]; then
                echo "ERROR: Failed to create mount point $mount_point. Skipping this partition." >&2
                continue
            fi
            sudo chown "$USER:$USER" "$mount_point" # Give ownership to the current user
        fi

        local mount_options="defaults,nofail"
        local dump_pass="0 2"

        if [[ "$FSTYPE" == "ntfs" || "$FSTYPE" == "ntfs-3g" || "$FSTYPE" == "lowntfs-3g" ]]; then
            FSTYPE="ntfs3"
            # Use current user's UID/GID, or fallback to 1000 if not detectable
            local current_uid=${SUDO_UID:-$(id -u)}
            local current_gid=${SUDO_GID:-$(id -g)}
            mount_options="force,uid=${current_uid},gid=${current_gid},rw,user,exec,nofail,umask=000"
            dump_pass="0 0"
        fi

        local fstab_entry="UUID=$UUID $mount_point $FSTYPE $mount_options $dump_pass $FSTAB_MANAGED_TAG"
        
        echo ">> Appending the following entry to $FSTAB_FILE:"
        echo "$fstab_entry"
        sudo sh -c "echo \"$fstab_entry\" >> $FSTAB_FILE"

        if [ $? -eq 0 ]; then
            echo "OK: Entry added to $FSTAB_FILE for /dev/$DEVICE."
        else
            echo "ERROR: Failed to add entry to $FSTAB_FILE for /dev/$DEVICE. Skipping this partition." >&2
        fi
        echo # Add a newline for better readability between partitions
    done

    _apply_mounts
    return 0
}

remove_fstab_entry() {
    echo ">> Removing an entry from $FSTAB_FILE..."
    if ! _backup_fstab; then
        return 1
    fi

    echo ">> Current managed entries in $FSTAB_FILE:"
    grep "$FSTAB_MANAGED_TAG" "$FSTAB_FILE" | nl -ba -w2 -s' '

    if [ $? -ne 0 ]; then
        echo "INFO: No entries managed by this script found in $FSTAB_FILE."
        return 0
    fi

    read -p "Enter the line number of the entry to remove (from the list above): " line_num

    if ! [[ "$line_num" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid line number. Aborting." >&2
        return 1
    fi

    # Extract the UUID of the selected line
    local uuid_to_remove=$(grep "$FSTAB_MANAGED_TAG" "$FSTAB_FILE" | sed -n "${line_num}p" | grep -oP 'UUID=\K[a-fA-F0-9-]+')

    if [ -z "$uuid_to_remove" ]; then
        echo "ERROR: Could not find UUID for the selected line. Aborting." >&2
        return 1
    fi

    # Unmount the partition before removing from fstab
    local mount_point_to_unmount=$(grep "UUID=$uuid_to_remove" "$FSTAB_FILE" | awk '{print $2}')
    if [ -n "$mount_point_to_unmount" ]; then
        echo ">> Attempting to unmount $mount_point_to_unmount..."
        sudo umount "$mount_point_to_unmount" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "OK: Unmounted $mount_point_to_unmount."
        else
            echo "WARNING: Failed to unmount $mount_point_to_unmount (it might not have been mounted). Continuing with fstab removal." >&2
        fi
    fi

    echo ">> Removing line $line_num from $FSTAB_FILE that contains UUID=$uuid_to_remove..."
    sudo sed -i.bak -e "/UUID=$uuid_to_remove.*$FSTAB_MANAGED_TAG/d" "$FSTAB_FILE"

    if [ $? -eq 0 ]; then
        echo "OK: Entry removed from $FSTAB_FILE."
        return 0
    else
        echo "ERROR: Failed to remove entry from $FSTAB_FILE." >&2
        return 1
    fi
}

view_managed_fstab_entries() {
    echo ">> Entries in $FSTAB_FILE managed by this script:"
    grep "$FSTAB_MANAGED_TAG" "$FSTAB_FILE" | nl -ba -w2 -s' '
    if [ $? -ne 0 ]; then
        echo "INFO: No entries managed by this script found in $FSTAB_FILE."
    fi
}

_setup_auto_fix_service() {
    echo ">> Setting up auto-fix service..."
    local script_path=$(realpath "$0")
    
    local service_content="[Unit]
Description=Auto-fix and mount NTFS partitions
After=local-fs.target

[Service]
Type=oneshot
ExecStart=$script_path --repair
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target"

    echo "$service_content" | sudo tee "$SERVICE_PATH" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    echo "OK: Auto-fix service enabled and created at $SERVICE_PATH."
}

_remove_auto_fix_service() {
    echo ">> Removing auto-fix service..."
    if [ -f "$SERVICE_PATH" ]; then
        sudo systemctl disable "$SERVICE_NAME"
        sudo rm "$SERVICE_PATH"
        sudo systemctl daemon-reload
        echo "OK: Auto-fix service removed."
    else
        echo "INFO: Service file $SERVICE_PATH not found."
    fi
}

_check_service_status() {
    if [ -f "$SERVICE_PATH" ]; then
        if systemctl is-enabled --quiet "$SERVICE_NAME"; then
            echo "Status: ENABLED"
        else
            echo "Status: DISABLED (File exists but not enabled)"
        fi
    else
        echo "Status: NOT INSTALLED"
    fi
}

_run_service_now() {
    echo ">> Running auto-fix service now..."
    if [ -f "$SERVICE_PATH" ]; then
        echo ">> Starting systemd service: $SERVICE_NAME"
        if sudo systemctl start "$SERVICE_NAME"; then
            echo "OK: Service started successfully."
        else
            echo "ERROR: Failed to start service. Falling back to manual repair..." >&2
            _apply_mounts
        fi
    else
        echo "INFO: Service not installed. Running manual repair directly..."
        _apply_mounts
    fi
}

#-------------------------------------------------------
# Interactive Menu
#-------------------------------------------------------
main() {
    echo "----------------------------------------"
    echo "  System FSTAB Auto-Mount Manager"
    echo "----------------------------------------"
    echo "This script helps manage fstab entries for auto-mounting drives."
    echo "It requires sudo privileges."
    echo

    while true; do
        echo "1) Add a new partition to fstab"
        echo "2) Remove a managed partition from fstab"
        echo "3) View managed fstab entries"
        echo "4) Enable Auto-Fix Service (on boot)"
        echo "5) Disable Auto-Fix Service"
        echo "6) Run Auto-Fix Service Now"
        echo "7) Exit"
        echo
        echo -n "Current Service "
        _check_service_status
        echo
        read -p "Choose an option: " choice

        case "$choice" in
            1)
                echo
                add_fstab_entry
                ;;
            2)
                echo
                remove_fstab_entry
                ;;
            3)
                echo
                view_managed_fstab_entries
                ;;
            4)
                echo
                _setup_auto_fix_service
                ;;
            5)
                echo
                _remove_auto_fix_service
                ;;
            6)
                echo
                _run_service_now
                ;;
            7)
                echo "Exiting."
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
        echo
    done
}

# Run the main function or parse arguments
if [[ "$1" == "--repair" ]]; then
    _apply_mounts
else
    main
fi
