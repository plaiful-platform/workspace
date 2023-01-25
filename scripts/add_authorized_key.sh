#!/bin/bash

if ! grep -Fxq "$1" /opt/ssh/authorized_keys
then
   echo $1 >> /opt/ssh/authorized_keys
fi