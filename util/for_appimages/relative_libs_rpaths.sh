#!/bin/bash

for file in ./*
do
  OUT=$(objdump -p $file | grep -E 'RUNPATH|RPATH')
  if [ -n "$OUT" ]; then
	patchelf --set-rpath '$ORIGIN' $file
  fi
done
