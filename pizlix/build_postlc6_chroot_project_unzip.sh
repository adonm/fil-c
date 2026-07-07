#!/bin/bash
set -e
set -x
rm -rf unzip60
tar -xf unzip60.tar.gz
cd unzip60
make -f unix/Makefile generic CC=cc
make -f unix/Makefile install PREFIX=/usr
cd ..
rm -rf unzip60
