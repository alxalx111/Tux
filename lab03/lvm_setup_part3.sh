#!/bin/bash

# Домашнее задание: Работа с LVM (часть 3)
# Запускать после перезагрузки в новый корень

set -e

echo "========================================="
echo "=== Шаг 2: Выделение тома под /var в mirror ==="
echo "========================================="

# Удаление временной VG
echo "Очистка временных томов..."
lvremove -f /dev/vg_root/lv_root
vgremove -f vg_root
pvremove -f /dev/sdg

# Создание mirror для /var
echo "Создание mirror для /var на /dev/sdg, /dev/sdh..."
pvcreate /dev/sdg /dev/sdh
vgcreate vg_var /dev/sdg /dev/sdh
lvcreate -L 950M -m1 -n lv_var vg_var
mkfs.ext4 /dev/vg_var/lv_var
mount /dev/vg_var/lv_var /mnt
cp -aR /var/* /mnt/
mkdir /tmp/oldvar && mv /var/* /tmp/oldvar 2>/dev/null
umount /mnt
mount /dev/vg_var/lv_var /var

# Добавление в fstab
echo "$(blkid | grep var: | awk '{print $2}') /var ext4 defaults 0 0" >> /etc/fstab

echo ""
echo "========================================="
echo "=== Шаг 3: Выделение тома под /home ==="
echo "========================================="

# Создание тома для /home
echo "Создание тома для /home на /dev/sdi, /dev/sdj..."
pvcreate /dev/sdi /dev/sdj
vgcreate vg_home /dev/sdi /dev/sdj
lvcreate -n lv_home -L 1.5G vg_home
mkfs.xfs /dev/vg_home/lv_home
mount /dev/vg_home/lv_home /mnt
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/vg_home/lv_home /home

# Добавление в fstab
echo "$(blkid | grep home: | awk '{print $2}') /home xfs defaults 0 0" >> /etc/fstab

echo ""
echo "========================================="
echo "=== Шаг 4: Работа со снапшотами ==="
echo "========================================="

# Создание тестовых файлов
echo "Создание тестовых файлов в /home..."
touch /home/file{1..20}

# Создание снапшота
echo "Создание снапшота home_snap..."
lvcreate -L 100M -s -n home_snap /dev/vg_home/lv_home

# Удаление части файлов
echo "Удаление файлов 11-20..."
rm -f /home/file{11..20}

# Восстановление из снапшота
echo "Восстановление из снапшота..."
umount /home
lvconvert --merge /dev/vg_home/home_snap
mount /dev/vg_home/lv_home /home

# Проверка восстановления
echo "Проверка восстановленных файлов:"
ls -la /home/ | head -25

echo ""
echo "========================================="
echo "=== Результат ==="
echo "========================================="
df -h | grep -E "ubuntu--vg|vg_var|vg_home"

echo ""
echo "✅ Домашнее задание выполнено!"
echo "  - Корневой раздел уменьшен до 8G"
echo "  - /var в mirror (RAID-1)"
echo "  - /home на отдельном томе с xfs"
echo "  - Снапшот создан и восстановлен"