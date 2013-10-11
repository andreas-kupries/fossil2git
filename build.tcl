#!/bin/sh
# -*- tcl -*- \
exec ./kettle -f "$0" "${1+$@}"
#kettle tcl
#
kettle tclapp bin/do-mirror
kettle tclapp bin/list
kettle tclapp bin/setup-export
kettle tclapp bin/setup-import
#
kettle tclapp bin/watch-add
kettle tclapp bin/watch-config-get
kettle tclapp bin/watch-config-set
kettle tclapp bin/watch-config-unset
kettle tclapp bin/watch-destroy
kettle tclapp bin/watch-do
kettle tclapp bin/watch-dump
kettle tclapp bin/watch-expire
kettle tclapp bin/watch-final
kettle tclapp bin/watch-init
kettle tclapp bin/watch-list
kettle tclapp bin/watch-remove
kettle tclapp bin/watch-rss
kettle tclapp bin/watch-setup
kettle tclapp bin/watch-unsee
