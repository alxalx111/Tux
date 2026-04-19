## Домашнее задание: Практические навыки работы с ZFS

**Цель:** научиться самостоятельно устанавливать ZFS, настраивать пулы, изучить основные возможности ZFS.

---

### Задание

1. **Определить алгоритм с наилучшим сжатием:**
   - определить, какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4)
   - создать 4 файловых системы, на каждой применить свой алгоритм сжатия
   - для сжатия использовать текстовый файл

2. **Определить настройки пула:**
   - с помощью команды zfs import собрать pool ZFS
   - командами zfs определить настройки: размер хранилища, тип pool, значение recordsize, какое сжатие используется, какая контрольная сумма используется

3. **Работа со снапшотами:**
   - скопировать файл из удаленной директории
   - восстановить файл локально (zfs receive)
   - найти зашифрованное сообщение в файле secret_message

---

### Формат сдачи

- ссылка на Git-репозиторий
- README.md с описанием выполненных шагов, списком команд zfs/zpool и их выводом
- bash-скрипт для конфигурации сервера

---

## Выполнение задания

### Среда выполнения

- **Гипервизор:** Oracle VirtualBox
- **Гостевая ОС:** Ubuntu 24.04
- **Ядро:** 6.8.0-107-generic
- **Диски:** 8 дополнительных дисков по 512 МБ
- **Пользователь:** elv (с правами sudo)

---

### Шаг 1: Установка ZFS

#### 1.1 Добавление дисков в виртуальную машину (из MINGW64 на хосте)

```bash
cd /c/VirtualBoxVMs/otus
VBoxManage controlvm "otus" poweroff
VBoxManage storagectl "otus" --name "SATA" --portcount 15

for i in {1..8}; do
    VBoxManage createmedium disk --filename "zfs_disk$i.vdi" --size 512 --format VDI --variant Standard
done

for i in {1..8}; do
    VBoxManage storageattach "otus" --storagectl "SATA" --port $((9+i)) --device 0 --type hdd --medium "C:/VirtualBoxVMs/otus/zfs_disk$i.vdi"
done

VBoxManage startvm "otus"
```

#### 1.2 Установка ZFS в ВМ

```bash
sudo apt update
sudo apt install -y zfsutils-linux
sudo modprobe zfs
```

#### 1.3 Проверка модуля ZFS

```bash
elv@otus:~$ lsmod | grep zfs
zfs                  6602752  6
spl                   180224  1 zfs
```

#### 1.4 Просмотр дисков

```bash
elv@otus:~$ lsblk | grep -E "sd[k-r]"
sdk                         8:160  0  512M  0 disk
sdl                         8:176  0  512M  0 disk
sdm                         8:192  0  512M  0 disk
sdn                         8:208  0  512M  0 disk
sdo                         8:224  0  512M  0 disk
sdp                         8:240  0  512M  0 disk
sdq                        65:0    0  512M  0 disk
sdr                        65:16   0  512M  0 disk
```

---

### Шаг 2: Создание ZFS пулов и настройка сжатия

#### 2.1 Создание 4 пулов в режиме mirror (RAID-1)

```bash
sudo zpool create otus1 mirror /dev/sdk /dev/sdl
sudo zpool create otus2 mirror /dev/sdm /dev/sdn
sudo zpool create otus3 mirror /dev/sdo /dev/sdp
sudo zpool create otus4 mirror /dev/sdq /dev/sdr
```

#### 2.2 Просмотр информации о пулах

```bash
elv@otus:~$ sudo zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M   111K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M   111K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   111K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M   111K   480M        -         -     0%     0%  1.00x    ONLINE  -
```

#### 2.3 Настройка алгоритмов сжатия

```bash
sudo zfs set compression=lzjb otus1
sudo zfs set compression=lz4 otus2
sudo zfs set compression=gzip-9 otus3
sudo zfs set compression=zle otus4
```

#### 2.4 Проверка применения алгоритмов

```bash
elv@otus:~$ sudo zfs get compression otus1 otus2 otus3 otus4
NAME   PROPERTY     VALUE           SOURCE
otus1  compression  lzjb            local
otus2  compression  lz4             local
otus3  compression  gzip-9          local
otus4  compression  zle             local
```

#### 2.5 Повторная проверка пулов

```bash
elv@otus:~$ sudo zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M   123K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M   123K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   168K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M   140K   480M        -         -     0%     0%  1.00x    ONLINE  -
```

---

### Шаг 3: Тестирование алгоритмов сжатия

#### 3.1 Скачивание тестового файла во все пулы

```bash
sudo wget -P /otus1 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus2 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus3 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus4 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
```

#### 3.2 Проверка размера файлов

```bash
elv@otus:~$ ls -l /otus1/*.log /otus2/*.log /otus3/*.log /otus4/*.log
-rw-r--r-- 1 root root 41227642 Apr  2 07:31 /otus1/pg2600.converter.log
-rw-r--r-- 1 root root 41227642 Apr  2 07:31 /otus2/pg2600.converter.log
-rw-r--r-- 1 root root 41227642 Apr  2 07:31 /otus3/pg2600.converter.log
-rw-r--r-- 1 root root 41227642 Apr  2 07:31 /otus4/pg2600.converter.log
```

#### 3.3 Проверка использования места

```bash
elv@otus:~$ sudo zfs list
NAME    USED  AVAIL  REFER  MOUNTPOINT
otus1  21.7M   330M  21.6M  /otus1
otus2  17.7M   334M  17.6M  /otus2
otus3  10.9M   341M  10.7M  /otus3
otus4  39.5M   313M  39.4M  /otus4
```

#### 3.4 Проверка коэффициента сжатия

```bash
elv@otus:~$ sudo zfs get compressratio | grep otus
otus1  compressratio  1.82x  -
otus2  compressratio  2.23x  -
otus3  compressratio  3.66x  -
otus4  compressratio  1.00x  -
```

#### Выводы по алгоритмам сжатия

| Пул | Алгоритм | Исходный размер | Фактическое использование | Коэффициент сжатия |
|-----|----------|-----------------|---------------------------|--------------------|
| otus1 | lzjb | 39.32 MB | 21.7 MB | **1.82x** |
| otus2 | lz4 | 39.32 MB | 17.7 MB | **2.23x** |
| otus3 | gzip-9 | 39.32 MB | 10.9 MB | **3.66x** |
| otus4 | zle | 39.32 MB | 39.5 MB | **1.00x** |

**Заключение:**
- **Лучший алгоритм сжатия:** `gzip-9` (коэффициент 3.66x)
- **Худший:** `zle` (сжатие отсутствует)
- **Баланс скорость/сжатие:** `lz4` (2.23x)

---

### Шаг 4: Определение настроек пула (импорт готового пула)

#### 4.1 Скачивание и распаковка архива

```bash
cd /home/elv
wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
tar -xzvf archive.tar.gz
```

**Результат:**
```
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

#### 4.2 Проверка возможности импорта пула

```bash
elv@otus:~$ sudo zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 config:
        otus                             ONLINE
          mirror-0                       ONLINE
            /home/elv/zpoolexport/filea  ONLINE
            /home/elv/zpoolexport/fileb  ONLINE
```

#### 4.3 Импорт пула

```bash
sudo zpool import -d zpoolexport/ otus
```

#### 4.4 Проверка статуса

```bash
elv@otus:~$ sudo zpool status
  pool: otus
 state: ONLINE
config:
        NAME                             STATE     READ WRITE CKSUM
        otus                             ONLINE       0     0     0
          mirror-0                       ONLINE       0     0     0
            /home/elv/zpoolexport/filea  ONLINE       0     0     0
            /home/elv/zpoolexport/fileb  ONLINE       0     0     0
```

#### 4.5 Определение настроек пула

**Размер хранилища:**
```bash
elv@otus:~$ sudo zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
```

**Тип пула (readonly):**
```bash
elv@otus:~$ sudo zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default
```

**Значение recordsize:**
```bash
elv@otus:~$ sudo zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
```

**Тип сжатия:**
```bash
elv@otus:~$ sudo zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local
```

**Тип контрольной суммы:**
```bash
elv@otus:~$ sudo zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```

#### Сводная таблица настроек пула

| Параметр | Значение |
|----------|----------|
| Размер хранилища (доступно) | 350 MB |
| Тип пула | read/write (off) |
| recordsize | 128 KB |
| Сжатие | zle |
| Контрольная сумма | sha256 |
| Тип pool | mirror (RAID-1) |

---

### Шаг 5: Работа со снапшотами

#### 5.1 Скачивание файла со снапшотом

```bash
cd /home/elv
wget -O otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'
```

**Результат:** Файл `otus_task2.file` размером 5.18 MB скачан.

#### 5.2 Восстановление файловой системы из снапшота

```bash
sudo zfs receive otus/test@today < otus_task2.file
```

#### 5.3 Поиск файла secret_message

```bash
elv@otus:~$ sudo find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
```

#### 5.4 Просмотр содержимого secret_message

```bash
elv@otus:~$ sudo cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/
```

**Результат:** В файле содержится ссылка на курс OTUS.

---

## Итоговый bash-скрипт

Файл `zfs_setup.sh`:

```bash
#!/bin/bash

# Домашнее задание: Практические навыки работы с ZFS
# Установка и настройка ZFS, создание пулов, тестирование сжатия

set -e

echo "========================================="
echo "   Домашнее задание: Работа с ZFS"
echo "========================================="

# 1. Установка ZFS
echo ""
echo "=== 1. Установка ZFS ==="
sudo apt update
sudo apt install -y zfsutils-linux
sudo modprobe zfs

# 2. Создание ZFS пулов
echo ""
echo "=== 2. Создание ZFS пулов ==="
sudo zpool create otus1 mirror /dev/sdk /dev/sdl
sudo zpool create otus2 mirror /dev/sdm /dev/sdn
sudo zpool create otus3 mirror /dev/sdo /dev/sdp
sudo zpool create otus4 mirror /dev/sdq /dev/sdr

# 3. Настройка алгоритмов сжатия
echo ""
echo "=== 3. Настройка алгоритмов сжатия ==="
sudo zfs set compression=lzjb otus1
sudo zfs set compression=lz4 otus2
sudo zfs set compression=gzip-9 otus3
sudo zfs set compression=zle otus4

# 4. Проверка настроек
echo ""
echo "=== 4. Проверка настроек сжатия ==="
sudo zfs get compression otus1 otus2 otus3 otus4

# 5. Скачивание тестового файла
echo ""
echo "=== 5. Скачивание тестового файла ==="
sudo wget -P /otus1 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus2 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus3 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
sudo wget -P /otus4 https://gutenberg.org/cache/epub/2600/pg2600.converter.log

# 6. Проверка степени сжатия
echo ""
echo "=== 6. Проверка степени сжатия ==="
sudo zfs list
sudo zfs get compressratio | grep otus

echo ""
echo "========================================="
echo "=== Результаты сжатия ==="
echo "========================================="
echo "otus1 (lzjb):     1.82x"
echo "otus2 (lz4):      2.23x"
echo "otus3 (gzip-9):   3.66x (лучший)"
echo "otus4 (zle):      1.00x"

echo ""
echo "✅ ZFS настроен и готов к работе!"
```

