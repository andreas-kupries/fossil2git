
Support scripts to watch a set of fossil repositories for ticket
changes and send notification mails.

To set up a watcher go through the following steps:

  *  Get a local checkout of this repository.

     Note: The watcher state is stored in the sqlite3 database
     "$HOME/.fossil.watch". This is a fixed location.

  *  Initialize the system by running

     ```
     fossil2git/bin/watch-init
     ```

  *  Use

     ```
     fossil2git/bin/watch-config-get
     ```

     and

     ```
     fossil2git/bin/watch-config-set <key> <value>
     ```

     to inspect and change the default configuration. Especially the
     keys related to access to the local mail system.


  *  For each fossil repository to watch run:

     ```
     fossil2git/bin/watch-setup <fossil-repository-url> <from-address>
     fossil2git/bin/watch-add   <fossil-repository-url> <to-address>
     ```

     The chosen sender email currently cannot be changed through the
     scripts, only through direct access to the state database and SQL
     commands.

     The system supports multiple receiver addresses, simply repeat
     'watch-add' as needed.

  *  To actually perform the watching periodically run

     ```
     fossil2git/bin/watch-do
     fossil2git/bin/watch-expire
     ```

     to detect changes and send mail, and to expire outdated ticket
     change artifacts. The latter can be left out, if you are fine
     with possible unlimited growth of the state database.

     A cron job is likely the best for that.

     For convenience use the bash-script

     ```
     fossil2git/bin/watch-cron
     ```

     It not only runs the above commands, but also prevents concurrent
     execution if a run takes longer than the interval between runs.
     The lock file used for this is "$HOME/.fossil.watch.lock".

     It further logs their output into the file "$HOME/.fossil.watch.log".
     This file is always appended to. It is the user's responsibility
     to use 'logrotate' or similar tools to keep its growth in check.


     Remember also that cron is notoriously fiddly with regard to the
     environment variables provided to the jobs.

     Make sure that:

     - Your PATH provides access to a Tcl installation providing all
       the required packages.

       Which are Tcl 8.5, http, tls, tdom, mime, and smtp.
       The last two can be found in tcllib.
