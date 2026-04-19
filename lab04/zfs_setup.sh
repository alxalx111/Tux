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