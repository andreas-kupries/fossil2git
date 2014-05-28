
With all the preparatory work finally done we can go and start the
mirroring. Note however that [vset PROJECT] does not fully do
everything by itself.

[para] It assumes that it will be called from a cron job, i.e. that
all the timing-related things are handled by the system, as is the
prevention of multiple parallel mirroring runs, and where log files
will be located.

[para] As we have full access to the fossil repository file of the
project the only [vset PROJECT] command we need in the core job script
is [cmd {peer exchange}], i.e.

[example {
    fx peer exchange -R /path/to/the/fossil/repository/file
}]
