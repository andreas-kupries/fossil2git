#!/bin/sh
# -*- tcl -*- \
exec kettle -f "$0" "${1+$@}"
# For kettle sources, documentation, etc. see
# - http://core.tcl.tk/akupries/kettle
# - http://chiselapp.com/user/andreas_kupries/repository/Kettle

# New general tool (Fossil eXtended)
kettle tclapp fx
kettle tclapp cron_lock
kettle tcl

## One-way mirroring of fossil repositories to git
#kettle tclapp bin/do-mirror
#kettle tclapp bin/list
#kettle tclapp bin/setup-export
#kettle tclapp bin/setup-import
