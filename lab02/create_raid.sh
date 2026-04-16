#!/bin/bash

# Скрипт для создания RAID-10 массива
# Домашнее задание: работа с mdadm

echo "=== Создание RAID-10 массива ==="

# Очистка суперблоков
echo "Очистка суперблоков..."
sudo mdadm --zero-superblock --force /dev/sdb
sudo mdadm --zero-superblock --force /dev/sdc
sudo mdadm --zero-superblock --force /dev/sdd
sudo mdadm --zero-superblock --force /dev/sde
sudo mdadm --zero-superblock --force /dev/sdf

# Создание RAID-10 (4 активных диска + 1 hot spare)
echo "Создание RAID-10 массива..."
sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 -x 1 /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf

# Сохранение конфигурации
echo "Сохранение конфигурации RAID..."
sudo mkdir -p /etc/mdadm
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u

# Проверка статуса
echo "Статус RAID:"
cat /proc/mdstat

echo "=== Готово ==="