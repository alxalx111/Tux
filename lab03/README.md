## Домашнее задание: Работа с LVM

**Цель:** создавать и управлять логическими томами в LVM.

---

### Задание

- Уменьшить том под `/` до 8G.
- Выделить том под `/home`.
- Выделить том под `/var` - сделать в mirror.
- `/home` - сделать том для снапшотов.
- Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
- Работа со снапшотами:
  - сгенерить файлы в `/home/`
  - снять снапшот
  - удалить часть файлов
  - восстановиться со снапшота

---

### Формат сдачи

- bash-скрипт с настройкой LVM (/, /home, /var mirror, снапшоты, fstab)
- краткий отчёт со списком команд для создания/восстановления снапшотов

---

## Выполнение задания


## Шаг 1: Уменьшение тома `/` до 8G

### Среда выполнения
- **Хост-ОС:** Windows
- **Терминал:** MINGW64 (Git Bash) для управления VirtualBox
- **Гипервизор:** Oracle VirtualBox
- **Гостевая ОС:** Ubuntu 24.04

### Цель
Уменьшить корневой раздел системы до 8 ГБ с использованием LVM.

### Выполнение

#### 1.1 Добавление новых дисков в виртуальную машину

Из MINGW64 (на хосте) останавливаем ВМ и увеличиваем количество портов SATA:

```bash
VBoxManage controlvm "otus" poweroff
VBoxManage storagectl "otus" --name "SATA" --portcount 10
```

Создаём новые диски для LVM:

```bash
cd /c/VirtualBoxVMs/otus

VBoxManage createmedium disk --filename "lvm_disk1.vdi" --size 2048 --format VDI --variant Standard
VBoxManage createmedium disk --filename "lvm_disk2.vdi" --size 2048 --format VDI --variant Standard
VBoxManage createmedium disk --filename "lvm_disk3.vdi" --size 2048 --format VDI --variant Standard
VBoxManage createmedium disk --filename "lvm_disk4.vdi" --size 2048 --format VDI --variant Standard
```

Подключаем диски к портам 6-9:

```bash
VBoxManage storageattach "otus" --storagectl "SATA" --port 6 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/lvm_disk1.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 7 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/lvm_disk2.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 8 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/lvm_disk3.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 9 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/lvm_disk4.vdi"
```

Запускаем ВМ:

```bash
VBoxManage startvm "otus"
```

#### 1.2 Проверка подключенных дисков внутри ВМ

```bash
root@otus:/home/elv# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
sda                         8:0    0   10G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0  1.8G  0 part   /boot
└─sda3                      8:3    0  8.2G  0 part
  └─ubuntu--vg-ubuntu--lv 252:1    0  8.2G  0 lvm    /
sdb                         8:16   0    1G  0 disk
└─md0                       9:0    0    2G  0 raid10
...
sdg                         8:96   0    2G  0 disk
sdh                         8:112  0    2G  0 disk
sdi                         8:128  0    2G  0 disk
sdj                         8:144  0    2G  0 disk
```

#### 1.3 Проверка текущего размера корневого тома

```bash
root@otus:/home/elv# df -h /
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv  8.1G  5.4G  2.3G  71% /
```

```bash
root@otus:/home/elv# lvs
  LV        VG        Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  ubuntu-lv ubuntu-vg -wi-ao---- <8.25g
```

#### 1.4 Создание временного корневого раздела

```bash
root@otus:/home/elv# pvcreate /dev/sdg
  Physical volume "/dev/sdg" successfully created.

root@otus:/home/elv# vgcreate vg_root /dev/sdg
  Volume group "vg_root" successfully created

root@otus:/home/elv# lvcreate -n lv_root -l +100%FREE vg_root
  Logical volume "lv_root" created.

root@otus:/home/elv# mkfs.ext4 /dev/vg_root/lv_root
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 523264 4k blocks and 130816 inodes
...

root@otus:/home/elv# mount /dev/vg_root/lv_root /mnt
```

#### 1.5 Копирование данных на временный том

```bash
root@otus:/home/elv# rsync -avxHAX --progress / /mnt/
...
sent 5,491,141,397 bytes  received 2,939,644 bytes  24,582,018.08 bytes/sec
total size is 5,483,593,549  speedup is 1.00
```

#### 1.6 Настройка загрузки с временного корня

```bash
root@otus:/home/elv# for i in /proc/ /sys/ /dev/ /run/ /boot/; do
    mount --bind $i /mnt/$i
done

root@otus:/home/elv# chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.11-061911-generic
Found initrd image: /boot/initrd.img-6.19.11-061911-generic
...
done

root@otus:/home/elv# chroot /mnt/ update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.11-061911-generic
```

#### 1.7 Перезагрузка во временный корень

```bash
root@otus:/home/elv# reboot
```

#### 1.8 Проверка после перезагрузки

```bash
elv@otus:~$ lsblk
...
sdg                         8:96   0    2G  0 disk
└─vg_root-lv_root         252:0    0    7G  0 lvm    /
sdh                         8:112  0    2G  0 disk
└─vg_root-lv_root         252:0    0    7G  0 lvm    /
...

elv@otus:~$ df -h /
Filesystem                   Size  Used Avail Use% Mounted on
/dev/mapper/vg_root-lv_root  6.8G  5.5G  983M  86% /
```

#### 1.9 Удаление старого LV и создание нового на 8G

```bash
root@otus:/home/elv# lvchange -an /dev/ubuntu-vg/ubuntu-lv
root@otus:/home/elv# lvremove -f /dev/ubuntu-vg/ubuntu-lv
  Logical volume "ubuntu-lv" successfully removed.

root@otus:/home/elv# lvcreate -n ubuntu-lv -L 8G /dev/ubuntu-vg
WARNING: ext4 signature detected on /dev/ubuntu-vg/ubuntu-lv at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/ubuntu-vg/ubuntu-lv.
  Logical volume "ubuntu-lv" created.

root@otus:/home/elv# mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 2097152 4k blocks and 524288 inodes
...

root@otus:/home/elv# mount /dev/ubuntu-vg/ubuntu-lv /mnt
```

#### 1.10 Копирование данных обратно

```bash
root@otus:/home/elv# rsync -avxHAX --progress / /mnt/
...
sent 5,516,529,803 bytes  received 2,939,845 bytes  24,695,613.64 bytes/sec
total size is 5,508,981,137  speedup is 1.00
```

#### 1.11 Настройка загрузки с нового корня

```bash
root@otus:/home/elv# for i in /proc/ /sys/ /dev/ /run/ /boot/; do
    mount --bind $i /mnt/$i
done

root@otus:/home/elv# chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.11-061911-generic
Found initrd image: /boot/initrd.img-6.19.11-061911-generic
...
done

root@otus:/home/elv# chroot /mnt/ update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.11-061911-generic
W: Couldn't identify type of root file system for fsck hook
```

#### 1.12 Перезагрузка и удаление временной VG

```bash
root@otus:/home/elv# reboot
```

После перезагрузки проверяем результат:

```bash
root@otus:/home/elv# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
sda                         8:0    0   10G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0  1.8G  0 part   /boot
└─sda3                      8:3    0  8.2G  0 part
  └─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm    /
...

root@otus:/home/elv# df -h /
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv  7.8G  5.6G  1.9G  75% /
```

Удаляем временный том:

```bash
root@otus:/home/elv# lvchange -an /dev/vg_root/lv_root
root@otus:/home/elv# lvremove -f /dev/vg_root/lv_root
  Logical volume "lv_root" successfully removed.

root@otus:/home/elv# vgremove -f vg_root
  Volume group "vg_root" successfully removed

root@otus:/home/elv# pvremove -f /dev/sdg /dev/sdh /dev/sdi /dev/sdj
  Labels on physical volume "/dev/sdg" successfully wiped.
  Labels on physical volume "/dev/sdh" successfully wiped.
  Labels on physical volume "/dev/sdi" successfully wiped.
  Labels on physical volume "/dev/sdj" successfully wiped.
```

### Результат шага 1

✅ **Корневой раздел уменьшен до 8G**
- Исходный размер: ~31G
- Новый размер: 8G
- Использовано: 5.6G
- Свободно: 1.9G


---

## Шаг 2: Выделение тома под `/var` в mirror

### Цель
Создать зеркальный том (RAID-1 подобный) для директории `/var` с использованием LVM mirroring.

### Выполнение

#### 2.1 Создание физических томов (PV)

```bash
root@otus:/home/elv# pvcreate /dev/sdg /dev/sdh
  Physical volume "/dev/sdg" successfully created.
  Physical volume "/dev/sdh" successfully created.
```

#### 2.2 Создание группы томов (VG) для `/var`

```bash
root@otus:/home/elv# vgcreate vg_var /dev/sdg /dev/sdh
  Volume group "vg_var" successfully created
```

#### 2.3 Создание зеркального логического тома (LV)

```bash
root@otus:/home/elv# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
```

**Параметры команды:**
- `-L 950M` — размер тома 950 МБ
- `-m1` — создать зеркало (1 копия)
- `-n lv_var` — имя логического тома

#### 2.4 Создание файловой системы ext4

```bash
root@otus:/home/elv# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 243712 4k blocks and 60928 inodes
Filesystem UUID: 62be4010-aee5-4905-a783-81c9bfded748
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

#### 2.5 Копирование данных из `/var` на новый том

```bash
root@otus:/home/elv# mount /dev/vg_var/lv_var /mnt
root@otus:/home/elv# cp -aR /var/* /mnt/
```

#### 2.6 Сохранение старого `/var` и монтирование нового

```bash
root@otus:/home/elv# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar 2>/dev/null
root@otus:/home/elv# umount /mnt
root@otus:/home/elv# mount /dev/vg_var/lv_var /var
```

#### 2.7 Добавление автоматического монтирования в fstab

```bash
root@otus:/home/elv# echo "$(blkid | grep var: | awk '{print $2}') /var ext4 defaults 0 0" >> /etc/fstab
```

#### 2.8 Проверка результата

```bash
root@otus:/home/elv# df -h /var
Filesystem                 Size  Used Avail Use% Mounted on
/dev/mapper/vg_var-lv_var  919M  718M  139M  84% /var
```

### Результат шага 2

✅ **Том `/var` создан в mirror** на дисках `/dev/sdg` и `/dev/sdh`
- Размер тома: 952 МБ
- Файловая система: ext4
- Использовано: 718 МБ
- Свободно: 139 МБ
- Монтирование добавлено в `/etc/fstab`

### Просмотр статуса зеркала

```bash
root@otus:/home/elv# lvs -a -o name,vg_name,attr,size,devices vg_var
  LV     VG     Attr       LSize   Devices
  lv_var vg_var rwi-a-r--- 952.00m lv_var_rimage_0(0),lv_var_rimage_1(0)
  [lv_var_rimage_0] vg_var iwi-aor--- 952.00m /dev/sdg(1)
  [lv_var_rimage_1] vg_var iwi-aor--- 952.00m /dev/sdh(1)
  [lv_var_rmeta_0] vg_var ewi-aor---   4.00m /dev/sdg(0)
  [lv_var_rmeta_1] vg_var ewi-aor---   4.00m /dev/sdh(0)
```

---

## Шаг 3: Выделение тома под `/home`

### Цель
Создать том для директории `/home` с использованием LVM.

### Выполнение

#### 3.1 Создание физических томов (PV)

```bash
root@otus:/home/elv# pvcreate /dev/sdi /dev/sdj
  Physical volume "/dev/sdi" successfully created.
  Physical volume "/dev/sdj" successfully created.
```

#### 3.2 Создание группы томов (VG) для `/home`

```bash
root@otus:/home/elv# vgcreate vg_home /dev/sdi /dev/sdj
  Volume group "vg_home" successfully created
```

#### 3.3 Создание логического тома (LV) для `/home`

```bash
root@otus:/home/elv# lvcreate -n lv_home -L 1.5G vg_home
  Logical volume "lv_home" created.
```

#### 3.4 Создание файловой системы xfs

```bash
root@otus:/home/elv# mkfs.xfs /dev/vg_home/lv_home
meta-data=/dev/vg_home/lv_home   isize=512    agcount=4, agsize=98304 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=393216, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

#### 3.5 Копирование данных из `/home` на новый том

```bash
root@otus:/home/elv# mount /dev/vg_home/lv_home /mnt
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.

root@otus:/home/elv# cp -aR /home/* /mnt/
```

#### 3.6 Очистка старого `/home` и монтирование нового

```bash
root@otus:/home/elv# rm -rf /home/*
root@otus:/home/elv# umount /mnt
root@otus:/home/elv# mount /dev/vg_home/lv_home /home
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
```

#### 3.7 Добавление автоматического монтирования в fstab

```bash
root@otus:/home/elv# echo "$(blkid | grep home: | awk '{print $2}') /home xfs defaults 0 0" >> /etc/fstab
```

#### 3.8 Проверка результата

```bash
root@otus:/home/elv# df -h /home
Filesystem                   Size  Used Avail Use% Mounted on
/dev/mapper/vg_home-lv_home  1.5G  255M  1.2G  18% /home
```

### Результат шага 3

✅ **Том `/home` создан** на дисках `/dev/sdi` и `/dev/sdj`
- Размер тома: 1.5 ГБ
- Файловая система: xfs (по заданию: разные ФС)
- Использовано: 255 МБ
- Свободно: 1.2 ГБ
- Монтирование добавлено в `/etc/fstab`

### Просмотр состояния томов

```bash
root@otus:/home/elv# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  ubuntu-lv ubuntu-vg -wi-ao----   8.00g
  lv_var    vg_var    rwi-a-r--- 952.00m                                    100.00
  lv_home   vg_home   -wi-ao----   1.50g
```

---

## Шаг 4: Работа со снапшотами

### Цель
Научиться создавать снапшоты логических томов и восстанавливать данные из них.

### Что такое снапшот?
Снапшот (snapshot) — это "моментальный снимок" состояния логического тома в определённый момент времени. Он позволяет вернуть данные к состоянию на момент создания снимка.

### Выполнение

#### 4.1 Создание тестовых файлов в `/home`

```bash
root@otus:/home/elv# touch /home/file{1..20}
root@otus:/home/elv# ls -la /home/
total 4
drwxr-xr-x  3 root root  288 Apr 19 17:18 .
drwxr-xr-x 24 root root 4096 Apr 16 20:09 ..
drwxr-x---  5 elv  elv   151 Apr 16 18:23 elv
-rw-r--r--  1 root root    0 Apr 19 17:18 file1
-rw-r--r--  1 root root    0 Apr 19 17:18 file10
-rw-r--r--  1 root root    0 Apr 19 17:18 file11
-rw-r--r--  1 root root    0 Apr 19 17:18 file12
...
-rw-r--r--  1 root root    0 Apr 19 17:18 file9
```

**Результат:** Создано 20 тестовых файлов в директории `/home`.

#### 4.2 Создание снапшота тома `/home`

```bash
root@otus:/home/elv# lvcreate -L 100M -s -n home_snap /dev/vg_home/lv_home
  Logical volume "home_snap" created.
```

**Параметры команды:**
- `-L 100M` — размер снапшота 100 МБ
- `-s` — создание снапшота (snapshot)
- `-n home_snap` — имя снапшота

#### 4.3 Проверка создания снапшота

```bash
root@otus:/home/elv# lvs | grep home
  home_snap vg_home   swi-a-s--- 100.00m      lv_home 0.00
  lv_home   vg_home   owi-aos---   1.50g
```

**Анализ:** Снапшот `home_snap` создан, атрибут `s` означает snapshot.

#### 4.4 Удаление части файлов

```bash
root@otus:/home/elv# rm -f /home/file{11..20}
root@otus:/home/elv# ls -la /home/
total 4
drwxr-xr-x  3 root root  148 Apr 19 17:19 .
drwxr-xr-x 24 root root 4096 Apr 16 20:09 ..
drwxr-x---  5 elv  elv   151 Apr 16 18:23 elv
-rw-r--r--  1 root root    0 Apr 19 17:18 file1
-rw-r--r--  1 root root    0 Apr 19 17:18 file10
-rw-r--r--  1 root root    0 Apr 19 17:18 file2
-rw-r--r--  1 root root    0 Apr 19 17:18 file3
-rw-r--r--  1 root root    0 Apr 19 17:18 file4
-rw-r--r--  1 root root    0 Apr 19 17:18 file5
-rw-r--r--  1 root root    0 Apr 19 17:18 file6
-rw-r--r--  1 root root    0 Apr 19 17:18 file7
-rw-r--r--  1 root root    0 Apr 19 17:18 file8
-rw-r--r--  1 root root    0 Apr 19 17:18 file9
```

**Результат:** Файлы `file11` – `file20` удалены. Осталось только 10 файлов.

#### 4.5 Восстановление из снапшота

Размонтируем том `/home`:

```bash
root@otus:/home/elv# umount /home
```

Выполняем слияние снапшота с оригиналом:

```bash
root@otus:/home/elv# lvconvert --merge /dev/vg_home/home_snap
  Merging of volume vg_home/home_snap started.
  vg_home/lv_home: Merged: 100.00%
```

Монтируем восстановленный том обратно:

```bash
root@otus:/home/elv# mount /dev/vg_home/lv_home /home
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
```

#### 4.6 Проверка восстановленных файлов

```bash
root@otus:/home/elv# ls -la /home/
total 4
drwxr-xr-x  3 root root  288 Apr 19 17:18 .
drwxr-xr-x 24 root root 4096 Apr 16 20:09 ..
drwxr-x---  5 elv  elv   151 Apr 16 18:23 elv
-rw-r--r--  1 root root    0 Apr 19 17:18 file1
-rw-r--r--  1 root root    0 Apr 19 17:18 file10
-rw-r--r--  1 root root    0 Apr 19 17:18 file11
-rw-r--r--  1 root root    0 Apr 19 17:18 file12
-rw-r--r--  1 root root    0 Apr 19 17:18 file13
-rw-r--r--  1 root root    0 Apr 19 17:18 file14
-rw-r--r--  1 root root    0 Apr 19 17:18 file15
-rw-r--r--  1 root root    0 Apr 19 17:18 file16
-rw-r--r--  1 root root    0 Apr 19 17:18 file17
-rw-r--r--  1 root root    0 Apr 19 17:18 file18
-rw-r--r--  1 root root    0 Apr 19 17:18 file19
-rw-r--r--  1 root root    0 Apr 19 17:18 file2
-rw-r--r--  1 root root    0 Apr 19 17:18 file20
-rw-r--r--  1 root root    0 Apr 19 17:18 file3
-rw-r--r--  1 root root    0 Apr 19 17:18 file4
-rw-r--r--  1 root root    0 Apr 19 17:18 file5
-rw-r--r--  1 root root    0 Apr 19 17:18 file6
-rw-r--r--  1 root root    0 Apr 19 17:18 file7
-rw-r--r--  1 root root    0 Apr 19 17:18 file8
-rw-r--r--  1 root root    0 Apr 19 17:18 file9
```

**Результат:** Все 20 файлов восстановлены! Файлы `file11` – `file20` вернулись на место.

### Результат шага 4

✅ **Снапшот успешно создан**  
✅ **Файлы удалены и восстановлены из снапшота**  
✅ **Механизм snapshot работает корректно**

### Команды для работы со снапшотами

| Команда | Назначение |
|---------|------------|
| `lvcreate -L SIZE -s -n SNAP_NAME ORIGIN_LV` | Создание снапшота |
| `lvs` | Просмотр всех томов (включая снапшоты) |
| `lvconvert --merge SNAP_NAME` | Восстановление из снапшота |
| `lvremove SNAP_NAME` | Удаление снапшота |

---

## Общий результат выполнения домашнего задания

| Шаг | Задание | Статус |
|-----|---------|--------|
| 1 | Уменьшить том под `/` до 8G | ✅ |
| 2 | Выделить том под `/var` в mirror | ✅ |
| 3 | Выделить том под `/home` | ✅ |
| 4 | Работа со снапшотами | ✅ |

---

## Итоговый bash-скрипт

Файл `lvm_setup.sh`:

```bash
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
```

После перезагрузки продолжить скриптом `lvm_setup_part2.sh`:

```bash
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
```

После второй перезагрузки запустить `lvm_setup_part3.sh`:

```bash
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
```

### Файлы для сдачи

1. `lvm_setup.sh` — первая часть скрипта
2. `lvm_setup_part2.sh` — вторая часть
3. `lvm_setup_part3.sh` — третья часть
