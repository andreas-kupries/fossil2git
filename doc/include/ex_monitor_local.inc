
With all preparatory work finally done we can go and start the
monitoring. Note however that [vset PROJECT] does not fully do
everything by itself.

[para] It assumes that it will be called from a cron job, i.e. that
all the timing-related things are handled by the system, as is the
prevention of multiple parallel notification runs, and where log files
will be located.

[para] As we have full access to the master fossil repository file of
the project the only [vset PROJECT] command we need in the core job
script is [cmd {note deliver}], i.e.

[example {
    fx note deliver -R /path/to/the/fossil/repository/file
}]

[para] Getting new content and configuration changes, as is required
for remote operation is not needed in this case.
