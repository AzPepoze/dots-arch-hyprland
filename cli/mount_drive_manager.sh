#!/bin/bash

# This script manages auto-mounting drives using /etc/fstab.

#-------------------------------------------------------
# Configuration
#-------------------------------------------------------
FSTAB_FILE="/etc/fstab"
FSTAB_BACKUP_DIR="/var/backups" # Standard backup location
FSTAB_MANAGED_TAG="# MANAGED_BY_AUTO_MOUNT_SCRIPT" # Tag to identify entries added by this script

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

        local fstab_entry="UUID=$UUID $mount_point $FSTYPE defaults,nofail 0 2 $FSTAB_MANAGED_TAG"
        
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

    echo ">> Running 'sudo mount -a' to apply all changes..."
    sudo mount -a
    if [ $? -eq 0 ]; then
        echo "OK: All partitions mounted successfully."
    else
        echo "WARNING: 'sudo mount -a' failed. Check your fstab entries for errors." >&2
    fi
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
        echo "4) Exit"
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

# Run the main function
main
