## Домашнее задание: Работа с mdadm

**Цель:** научиться использовать утилиту для управления программными RAID-массивами в Linux.

---

### Задание

• Добавьте в виртуальную машину несколько дисков

• Соберите RAID-0/1/5/10 на выбор

• Сломайте и почините RAID

• Создайте GPT таблицу, пять разделов и смонтируйте их в системе.

---

### Формат сдачи

- скрипт для создания рейда
- отчет по командам для починки RAID и созданию разделов

---

## Предварительный шаг: Добавление дисков в виртуальную машину

### Среда выполнения
- **Хост-ОС:** Windows
- **Терминал:** MINGW64 (Git Bash)
- **Гипервизор:** Oracle VirtualBox
- **Гостевая ОС:** Ubuntu 24.04 Server / Desktop

### Цель
Добавить 5 дополнительных дисков по 1 ГБ каждый в виртуальную машину для последующего создания RAID-массива.

### Выполнение

#### 1. Создание дисков через VirtualBox CLI (из MINGW64)

```bash
cd /c/VirtualBoxVMs/otus

for i in {1..5}; do
    VBoxManage createmedium disk --filename "disk$i.vdi" --size 1024 --format VDI --variant Standard
done
```

**Результат создания дисков:**
```
Medium created. UUID: 116451d8-320b-4532-b241-90485256a612
Medium created. UUID: 2c5cbaea-ad16-41c0-b154-bd6d40b96c6e
Medium created. UUID: 5b7ca336-c997-4cae-a4f0-47287191b57f
Medium created. UUID: 852ddb61-ef41-4330-8b04-1cfb10c4d970
Medium created. UUID: b61f88da-68c6-445f-9a60-0cad98975ec5
```

#### 2. Проверка созданных дисков

```bash
$ ls -la disk*.vdi
-rw------- 1 Elvira None 10240 Apr 16 20:30 disk1.vdi
-rw------- 1 Elvira None 10240 Apr 16 20:30 disk2.vdi
-rw------- 1 Elvira None 10240 Apr 16 20:30 disk3.vdi
-rw------- 1 Elvira None 10240 Apr 16 20:30 disk4.vdi
-rw------- 1 Elvira None 10240 Apr 16 20:30 disk5.vdi
```

#### 3. Увеличение количества портов SATA контроллера

По умолчанию SATA контроллер имеет 1 порт (занят системным диском). Увеличиваем до 6 портов:

```bash
VBoxManage controlvm "otus" poweroff
VBoxManage storagectl "otus" --name "SATA" --portcount 6
```

**Проверка изменений:**
```bash
$ VBoxManage showvminfo "otus" | grep "SATA"
#1: 'SATA', Type: IntelAhci, Instance: 0, Ports: 6 (max 30), Bootable
```

#### 4. Подключение дисков к виртуальной машине

```bash
VBoxManage storageattach "otus" --storagectl "SATA" --port 1 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/disk1.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 2 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/disk2.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 3 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/disk3.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 4 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/disk4.vdi"
VBoxManage storageattach "otus" --storagectl "SATA" --port 5 --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/disk5.vdi"
```

#### 5. Запуск виртуальной машины

```bash
VBoxManage startvm "otus"
```

#### 6. Проверка подключенных дисков внутри ВМ

```bash
elv@otus:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0   10G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0  1.8G  0 part /boot
└─sda3                      8:3    0  8.2G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0  8.2G  0 lvm  /
sdb                         8:16   0    1G  0 disk
sdc                         8:32   0    1G  0 disk
sdd                         8:48   0    1G  0 disk
sde                         8:64   0    1G  0 disk
sdf                         8:80   0    1G  0 disk
sr0                        11:0    1 1024M  0 rom
```

```bash
elv@otus:~$ sudo fdisk -l | grep "Disk /dev/sd"
Disk /dev/sda: 10 GiB, 10737418240 bytes, 20971520 sectors
Disk /dev/sdb: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdc: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdd: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sde: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdf: 1 GiB, 1073741824 bytes, 2097152 sectors
```

### Результат предварительного шага

✅ **Успешно добавлено 5 дисков:** `/dev/sdb`, `/dev/sdc`, `/dev/sdd`, `/dev/sde`, `/dev/sdf`  
✅ **Размер каждого диска:** 1 ГБ  
✅ **Диски готовы к созданию RAID-массива**

### Примечания

- Для выполнения команд использовался **MINGW64 (Git Bash)** на хосте Windows
- Диски созданы в формате VDI
- Порт 0 SATA контроллера занят системным диском (`/dev/sda`)
- Диски подключены к портам 1-5 SATA контроллера

---

## Шаг 2: Создание RAID-массива (RAID-10)

### Среда выполнения
- **Хост-ОС:** Windows
- **Терминал:** MINGW64 (Git Bash) для управления VirtualBox
- **Гостевая ОС:** Ubuntu 24.04 (ВМ "otus")
- **Утилита:** mdadm

### Цель
Создать программный RAID-10 массив из 5 дисков (4 активных + 1 hot spare) с помощью утилиты mdadm.

### Выполнение

#### 2.1 Проверка подключенных дисков

Перед созданием RAID убеждаемся, что все 5 дисков видны в системе:

```bash
elv@otus:~$ sudo fdisk -l | grep "Disk /dev/sd"
Disk /dev/sda: 10 GiB, 10737418240 bytes, 20971520 sectors
Disk /dev/sdb: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdc: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdd: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sde: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk /dev/sdf: 1 GiB, 1073741824 bytes, 2097152 sectors
```

#### 2.2 Очистка суперблоков (подготовка дисков)

Очищаем возможные остатки RAID-суперблоков на дисках:

```bash
elv@otus:~$ sudo mdadm --zero-superblock --force /dev/sdb
mdadm: Unrecognised md component device - /dev/sdb
elv@otus:~$ sudo mdadm --zero-superblock --force /dev/sdc
mdadm: Unrecognised md component device - /dev/sdc
elv@otus:~$ sudo mdadm --zero-superblock --force /dev/sdd
mdadm: Unrecognised md component device - /dev/sdd
elv@otus:~$ sudo mdadm --zero-superblock --force /dev/sde
mdadm: Unrecognised md component device - /dev/sde
elv@otus:~$ sudo mdadm --zero-superblock --force /dev/sdf
mdadm: Unrecognised md component device - /dev/sdf
```

> **Примечание:** Сообщение `Unrecognised md component device` является нормальным для новых/чистых дисков и означает, что суперблок отсутствует.

#### 2.3 Создание RAID-10 массива

Создаём RAID-10 с 4 активными дисками и 1 запасным (hot spare):

```bash
elv@otus:~$ sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 -x 1 /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 1046528K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```

**Параметры команды:**
| Параметр | Значение | Описание |
|----------|----------|----------|
| `--create` | - | Создание нового RAID-массива |
| `--verbose` | - | Подробный вывод информации |
| `/dev/md0` | - | Имя создаваемого RAID-устройства |
| `-l 10` | RAID-10 | Уровень RAID |
| `-n 4` | 4 | Количество активных дисков |
| `-x 1` | 1 | Количество запасных (hot spare) дисков |

#### 2.4 Проверка статуса RAID

**Просмотр состояния через /proc/mdstat:**

```bash
elv@otus:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear]
md0 : active raid10 sdf[4](S) sde[3] sdd[2] sdc[1] sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

**Детальная информация о RAID:**

```bash
elv@otus:~$ sudo mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Apr 16 19:29:41 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Thu Apr 16 19:29:51 2026
             State : clean
    Active Devices : 4
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus:0  (local to host otus)
              UUID : 0bc90584:766105e0:2a029c41:f86d9160
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

       4       8       80        -      spare   /dev/sdf
```

**Анализ вывода:**
- `State: clean` — массив в чистом состоянии, синхронизация завершена
- `Active Devices: 4` — 4 активных диска
- `Spare Devices: 1` — 1 запасной диск (`/dev/sdf`)
- `[UUUU]` — все 4 диска работают (U = up/active)
- `(S)` — маркер spare-диска

#### 2.5 Сохранение конфигурации RAID

Чтобы RAID автоматически собирался при загрузке системы:

```bash
elv@otus:~$ sudo mkdir -p /etc/mdadm
elv@otus:~$ sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
ARRAY /dev/md0 metadata=1.2 spares=1 UUID=0bc90584:766105e0:2a029c41:f86d9160
```

Обновляем образ initramfs для загрузки с поддержкой RAID:

```bash
elv@otus:~$ sudo update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.11-061911-generic
```

### Результат шага 2

✅ **RAID-10 успешно создан** из 4 дисков (`/dev/sdb`, `/dev/sdc`, `/dev/sdd`, `/dev/sde`)  
✅ **Hot spare диск** `/dev/sdf` добавлен в массив  
✅ **Конфигурация сохранена** в `/etc/mdadm/mdadm.conf`  
✅ **Initramfs обновлён** для автоматической сборки RAID при загрузке  

### Использованные команды

| Команда | Назначение |
|---------|------------|
| `mdadm --zero-superblock` | Очистка суперблоков на дисках |
| `mdadm --create` | Создание RAID-массива |
| `cat /proc/mdstat` | Просмотр статуса RAID |
| `mdadm --detail` | Детальная информация о RAID |
| `mdadm --detail --scan` | Сканирование и вывод конфигурации RAID |
| `update-initramfs -u` | Обновление образа начальной загрузки |

---

## Шаг 3: Создание файловой системы, монтирование RAID и тестирование

### Цель
Создать файловую систему на RAID-массиве, смонтировать его и проверить работоспособность.

### Выполнение

#### 3.1 Создание файловой системы ext4

```bash
elv@otus:~$ sudo mkfs.ext4 /dev/md0
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 523264 4k blocks and 130816 inodes
Filesystem UUID: 76153dd0-c32b-475d-8ab3-51944782e886
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done
```

#### 3.2 Создание точки монтирования

```bash
elv@otus:~$ sudo mkdir -p /mnt/raid
```

#### 3.3 Монтирование RAID

```bash
elv@otus:~$ sudo mount /dev/md0 /mnt/raid
```

#### 3.4 Проверка монтирования

```bash
elv@otus:~$ df -h /mnt/raid
Filesystem      Size  Used Avail Use% Mounted on
/dev/md0        2.0G   24K  1.9G   1% /mnt/raid
```

#### 3.5 Создание тестового файла

```bash
elv@otus:~$ echo "RAID-10 test" | sudo tee /mnt/raid/test.txt
RAID-10 test
```

#### 3.6 Проверка содержимого тестового файла

```bash
elv@otus:~$ cat /mnt/raid/test.txt
RAID-10 test
```

#### 3.7 Проверка прав доступа

```bash
elv@otus:~$ ls -la /mnt/raid/
total 28
drwxr-xr-x 3 root root  4096 Apr 16 19:35 .
drwxr-xr-x 3 root root  4096 Apr 16 19:35 ..
drwx------ 2 root root 16384 Apr 16 19:35 lost+found
-rw-r--r-- 1 root root    13 Apr 16 19:35 test.txt
```

### Результат шага 3

✅ **Файловая система ext4 создана** на устройстве `/dev/md0`  
✅ **RAID смонтирован** в `/mnt/raid`  
✅ **Тестовый файл успешно записан и прочитан**  
✅ **RAID готов к использованию**

---

## Скрипт для создания рейда

По результатам выполнения шагов 2 и 3 был создан скрипт `create_raid.sh`:

```bash
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

# Создание файловой системы
echo "Создание файловой системы ext4..."
sudo mkfs.ext4 -F /dev/md0

# Монтирование RAID
echo "Монтирование RAID..."
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid

# Проверка статуса
echo "Статус RAID:"
cat /proc/mdstat

echo "=== Готово ==="
```

---

## Отчёт по командам для починки RAID и созданию разделов

### 1. Поломка RAID (имитация отказа диска)

#### Текущее состояние RAID до поломки

```bash
elv@otus:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear]
md0 : active raid10 sdf[4](S) sde[3] sdd[2] sdc[1] sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

**Анализ:** RAID-10 в состоянии `active`, все 4 активных диска работают (`[UUUU]`), диск `sdf` находится в режиме hot spare (`(S)`).

#### Имитация отказа диска /dev/sdc

```bash
elv@otus:~$ sudo mdadm /dev/md0 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0
```

#### Состояние RAID после поломки

```bash
elv@otus:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear]
md0 : active raid10 sdf[4] sde[3] sdd[2] sdc[1](F) sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

**Анализ:** Диск `/dev/sdc` помечен как faulty `(F)`, но массив продолжает работать в штатном режиме.

#### Детальная информация о RAID после поломки

```bash
elv@otus:~$ sudo mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Apr 16 19:29:41 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Thu Apr 16 19:57:54 2026
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus:0  (local to host otus)
              UUID : 0bc90584:766105e0:2a029c41:f86d9160
            Events : 36

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       4       8       80        1      active sync set-B   /dev/sdf
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

       1       8       32        -      faulty   /dev/sdc
```

**Анализ:** 
- `State: clean` — массив в чистом состоянии
- `Active Devices: 4` — 4 активных устройства
- `Failed Devices: 1` — 1 сбойное устройство (`/dev/sdc`)
- `Spare Devices: 0` — запасных дисков нет (hot spare `sdf` был автоматически задействован)

#### Проверка доступности данных

```bash
elv@otus:~$ cat /mnt/raid/test.txt
RAID-10 test
```

**Результат:** Данные остались доступны, несмотря на отказ диска. RAID-10 успешно обеспечивает отказоустойчивость.

---

### 2. Починка RAID (восстановление после отказа)

#### Удаление сломанного диска из массива

```bash
elv@otus:~$ sudo mdadm /dev/md0 --remove /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md0
```

#### Добавление диска обратно в массив

```bash
elv@otus:~$ sudo mdadm /dev/md0 --add /dev/sdc
mdadm: added /dev/sdc
```

#### Проверка статуса RAID после добавления диска

```bash
elv@otus:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear]
md0 : active raid10 sdc[5](S) sdf[4] sde[3] sdd[2] sdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

**Анализ:** Диск `/dev/sdc` добавлен как spare `(S)` — запасной. Восстановление прошло успешно.

#### Детальная информация о RAID после восстановления

```bash
elv@otus:~$ sudo mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Apr 16 19:29:41 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Thu Apr 16 20:02:09 2026
             State : clean
    Active Devices : 4
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus:0  (local to host otus)
              UUID : 0bc90584:766105e0:2a029c41:f86d9160
            Events : 38

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       4       8       80        1      active sync set-B   /dev/sdf
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

       5       8       32        -      spare   /dev/sdc
```

**Анализ:**
- `State: clean` — массив в чистом состоянии
- `Active Devices: 4` — 4 активных устройства
- `Working Devices: 5` — 5 работающих устройств
- `Failed Devices: 0` — сбойных устройств нет
- `Spare Devices: 1` — 1 запасной диск (`/dev/sdc`)

#### Проверка доступности данных после восстановления

```bash
elv@otus:~$ cat /mnt/raid/test.txt
RAID-10 test
```

**Результат:** Данные остались доступны, RAID полностью восстановлен.

---

### 3. Создание GPT таблицы и пяти разделов

#### Создание GPT таблицы на RAID

Перед созданием GPT таблицы необходимо размонтировать RAID:

```bash
elv@otus:~$ sudo umount /mnt/raid
elv@otus:~$ sudo parted -s /dev/md0 mklabel gpt
```

#### Проверка пустой GPT таблицы

```bash
elv@otus:~$ sudo parted /dev/md0 print
Model: Linux Software RAID Array (md)
Disk /dev/md0: 2143MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start  End  Size  File system  Name  Flags
```

#### Создание пяти разделов (по 20% каждый)

```bash
elv@otus:~$ sudo parted /dev/md0 mkpart primary ext4 0% 20%
Information: You may need to update /etc/fstab.

elv@otus:~$ sudo parted /dev/md0 mkpart primary ext4 20% 40%
Information: You may need to update /etc/fstab.

elv@otus:~$ sudo parted /dev/md0 mkpart primary ext4 40% 60%
Information: You may need to update /etc/fstab.

elv@otus:~$ sudo parted /dev/md0 mkpart primary ext4 60% 80%
Information: You may need to update /etc/fstab.

elv@otus:~$ sudo parted /dev/md0 mkpart primary ext4 80% 100%
Information: You may need to update /etc/fstab.
```

#### Проверка созданных разделов

```bash
elv@otus:~$ sudo parted /dev/md0 print
Model: Linux Software RAID Array (md)
Disk /dev/md0: 2143MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size   File system  Name     Flags
 1      1049kB  429MB   428MB               primary
 2      429MB   858MB   429MB               primary
 3      858MB   1286MB  428MB               primary
 4      1286MB  1714MB  429MB               primary
 5      1714MB  2142MB  428MB               primary
```

#### Создание файловых систем ext4 на разделах

```bash
elv@otus:~$ for i in $(seq 1 5); do sudo mkfs.ext4 -F /dev/md0p$i; done
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 3036bc6e-cf4d-4ed8-96ee-636acc133635
Superblock backups stored on blocks: 32768, 98304
Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104704 4k blocks and 104704 inodes
Filesystem UUID: f789fa93-e0ed-4891-a3ae-025e5469a654
Superblock backups stored on blocks: 32768, 98304
Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 54e93177-28a7-4f65-8ce1-75aecbc2bc74
Superblock backups stored on blocks: 32768, 98304
Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104704 4k blocks and 104704 inodes
Filesystem UUID: 38fbf79f-6946-4876-abc1-ee804bf40fc4
Superblock backups stored on blocks: 32768, 98304
Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 51f7d4d2-55b0-4def-84dc-53bcc4d6bd15
Superblock backups stored on blocks: 32768, 98304
Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

#### Создание точек монтирования и монтирование разделов

```bash
elv@otus:~$ sudo mkdir -p /raid/part{1,2,3,4,5}
elv@otus:~$ for i in $(seq 1 5); do sudo mount /dev/md0p$i /raid/part$i; done
```

#### Проверка монтирования разделов

```bash
elv@otus:~$ df -h | grep raid
/dev/md0p1                         366M   24K  338M   1% /raid/part1
/dev/md0p2                         367M   24K  339M   1% /raid/part2
/dev/md0p3                         366M   24K  338M   1% /raid/part3
/dev/md0p4                         367M   24K  339M   1% /raid/part4
/dev/md0p5                         366M   24K  338M   1% /raid/part5
```

**Результат:** 5 разделов успешно созданы, на каждом создана файловая система ext4, разделы смонтированы в директории `/raid/part1` – `/raid/part5`.

