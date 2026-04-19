#!/bin/bash

# Домашнее задание: Работа с LVM
# Уменьшение / до 8G, создание mirror для /var, тома для /home, снапшоты

set -e

echo "========================================="
echo "   Домашнее задание: Работа с LVM"
echo "========================================="

# ============================================
# Шаг 1: Уменьшение тома / до 8G
# ============================================

echo ""
echo "=== Шаг 1: Уменьшение тома / до 8G ==="

# Создание временного корня на /dev/sdg
echo "Создание временного корневого раздела..."
pvcreate /dev/sdg
vgcreate vg_root /dev/sdg
lvcreate -n lv_root -l +100%FREE vg_root
mkfs.ext4 /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt

# Копирование данных
echo "Копирование данных на временный том..."
rsync -avxHAX --progress / /mnt/

# Настройка загрузки с временного корня
echo "Настройка загрузки..."
for i in /proc/ /sys/ /dev/ /run/ /boot/; do
    mount --bind $i /mnt/$i
done

chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg
chroot /mnt/ update-initramfs -u

echo "Перезагрузка в временный корень..."
reboot