#!/bin/bash

# Домашнее задание: Работа с LVM (часть 2)
# Запускать после перезагрузки во временный корень

set -e

echo "=== Шаг 1 (продолжение): Удаление старого LV и создание нового ==="

# Удаление старого LV и создание нового на 8G
lvchange -an /dev/ubuntu-vg/ubuntu-lv
lvremove -f /dev/ubuntu-vg/ubuntu-lv
lvcreate -n ubuntu-lv -L 8G /dev/ubuntu-vg
mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mount /dev/ubuntu-vg/ubuntu-lv /mnt

# Копирование данных обратно
echo "Копирование данных обратно на новый том..."
rsync -avxHAX --progress / /mnt/

# Настройка загрузки с нового корня
for i in /proc/ /sys/ /dev/ /run/ /boot/; do
    mount --bind $i /mnt/$i
done

chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg
chroot /mnt/ update-initramfs -u

echo "Перезагрузка в новый корневой том..."
reboot