#!/bin/bash
# macOS Backup Script

echo "=== macOS Backup Utility ==="
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_dir="backups/backup_$timestamp"
echo "Creating backup directory: $backup_dir"
mkdir -p "$backup_dir"
mkdir -p "$backup_dir/Documents"
echo "Backup simulation completed!" > "$backup_dir/backup_info.txt"
echo "Backup location: $backup_dir"
