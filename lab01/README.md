# Домашнее задание: Обновление ядра системы
**Курс:** Администратор Linux. Professional  
**Занятие:** 1. Обновление ядра системы

## Цель работы
Научиться обновлять ядро в ОС Linux до последней стабильной версии из mainline-репозитория Ubuntu.

## Выполнение задания

### 1. Проверка текущей версии ядра

До начала обновления проверяем текущую версию ядра:

```bash
elv@otus:~$ uname -r
6.8.0-107-generic
```

### 2. Создание директории и загрузка пакетов

Создаём директорию для загрузки пакетов ядра:

```bash
elv@otus:~$ mkdir kernel && cd kernel
```

Загружаем 4 необходимых пакета для архитектуры amd64 из mainline-репозитория (версия 6.19.11):

```bash
wget https://kernel.ubuntu.com/mainline/v6.19.11/amd64/linux-headers-6.19.11-061911_6.19.11-061911.202604021147_all.deb
wget https://kernel.ubuntu.com/mainline/v6.19.11/amd64/linux-headers-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
wget https://kernel.ubuntu.com/mainline/v6.19.11/amd64/linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
wget https://kernel.ubuntu.com/mainline/v6.19.11/amd64/linux-modules-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
```

Проверяем, что все файлы успешно скачались:

```bash
elv@otus:~/kernel$ ls -la *.deb
-rw-rw-r-- 1 elv elv  14637002 Apr  2 14:33 linux-headers-6.19.11-061911_6.19.11-061911.202604021147_all.deb
-rw-rw-r-- 1 elv elv   4027214 Apr  2 14:32 linux-headers-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
-rw-rw-r-- 1 elv elv  17008832 Apr  2 14:32 linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
-rw-rw-r-- 1 elv elv 167178432 Apr  2 14:32 linux-modules-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
```

### 3. Проблема при стандартной установке

При попытке установки стандартным методом `dpkg -i` возникает ошибка в pre-installation скрипте:

```bash
elv@otus:~/kernel$ sudo dpkg -i --force-depends linux-*.deb
...
Preparing to unpack linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb ...
run-parts: missing operand
Try `run-parts --help' for more information.
dpkg: error processing archive linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb (--install):
 new linux-image-unsigned-6.19.11-061911-generic package pre-installation script subprocess returned error exit status 1
...
Errors were encountered while processing:
 linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb
```

**Причина ошибки:** В pre-installation скриптах пакетов mainline-репозитория Ubuntu присутствует баг — вызов `run-parts` без необходимого аргумента, что приводит к ошибке выполнения.

### 4. Альтернативный метод установки (обход бага)

В связи с ошибкой в стандартном методе, используем ручную распаковку пакетов через `dpkg-deb -x`:

```bash
# Распаковка образа ядра
elv@otus:~/kernel$ sudo dpkg-deb -x linux-image-unsigned-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb /

# Распаковка модулей ядра
elv@otus:~/kernel$ sudo dpkg-deb -x linux-modules-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb /

# Распаковка заголовочных файлов
elv@otus:~/kernel$ sudo dpkg-deb -x linux-headers-6.19.11-061911-generic_6.19.11-061911.202604021147_amd64.deb /
elv@otus:~/kernel$ sudo dpkg-deb -x linux-headers-6.19.11-061911_6.19.11-061911.202604021147_all.deb /
```

### 5. Создание initramfs

Генерируем образ начальной загрузки для нового ядра:

```bash
elv@otus:~/kernel$ sudo update-initramfs -c -k 6.19.11-061911-generic
update-initramfs: Generating /boot/initrd.img-6.19.11-061911-generic
```

### 6. Обновление конфигурации загрузчика

Обновляем GRUB для добавления нового ядра в меню загрузки:

```bash
elv@otus:~/kernel$ sudo update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.11-061911-generic
Found initrd image: /boot/initrd.img-6.19.11-061911-generic
Found linux image: /boot/vmlinuz-6.8.0-107-generic
Found initrd image: /boot/initrd.img-6.8.0-107-generic
Found linux image: /boot/vmlinuz-6.8.0-106-generic
Found initrd image: /boot/initrd.img-6.8.0-106-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
```

### 7. Перезагрузка системы

```bash
elv@otus:~/kernel$ sudo reboot
```

### 8. Проверка результата

После перезагрузки проверяем версию ядра:

```bash
elv@otus:~$ uname -r
6.19.11-061911-generic
```

## Результат выполнения задания

✅ **Ядро успешно обновлено** с версии `6.8.0-107-generic` до `6.19.11-061911-generic`

## Выявленные проблемы и их решение

| Проблема | Решение |
|----------|---------|
| Ошибка `run-parts: missing operand` в pre-installation скриптах пакетов mainline-репозитория | Использование `dpkg-deb -x` для ручной распаковки пакетов в обход скриптов |
| Зависимость от `linux-main-modules-zfs` | Проигнорирована, так как пакет не влияет на базовую работу ядра |

## Примечания

1. Методическое пособие предлагало установку через `sudo dpkg -i *.deb`, однако из-за бага в пакетах mainline-репозитория этот способ не сработал.
2. Ручная распаковка через `dpkg-deb -x` является корректным альтернативным методом установки ядра.
3. Новая версия ядра `6.19.11-061911-generic` является последней стабильной версией на момент выполнения работы (апрель 2026 г.).

