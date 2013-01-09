#!/usr/bin/awk -f

/>/ {s+=1; printf ">SEQ_%08d\n",s }
!/>/ { print }

