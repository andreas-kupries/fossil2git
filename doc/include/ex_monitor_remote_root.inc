
With all the preparatory work finally done we can go and start the
monitoring. Note however that [vset PROJECT] does not fully do
everything by itself.

[para] It assumes that it will be called from a cron job, i.e. that
all the timing-related things are handled by the system, as is the
prevention of multiple parallel notification runs, and where log files
will be located.

[para] As we have no direct access to the master fossil repository
file of the project we not only have to generate and send mail, but
also have to make sure that our local clone is kept up to date, for
both content and relevant configuration, i.e. the areas [term users]
and [term email].

[example {
    R=/path/to/the/fossil/repository/file

    fossil pull              -R $R
    fossil config pull email -R $R
    fossil config pull users -R $R
    fx note deliver -R $R
}]
