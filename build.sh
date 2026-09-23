#!/bin/sh
set -eu
make clean package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1
