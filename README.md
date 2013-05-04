
Support scripts to maintain a system for mirroring a set of fossil
repositories to one or more git repositiories.

Original code (bash) by Pat Thoyts, hardwired for the main Tcl/Tk
repositories on core.tcl.tk and the github tcltk organization.

Rewritten in Tcl by myself, generalized to arbitrary fossil and git
repositories (urls).

To set up a mirror go thtoigh the following steps:

  *  Get a local checkout of this repository

  *  Choose a suitable location for the 'state' directory.

     The <state> variable in the following commands is a placeholder
     for this directory.

  *  For each fossil repository you wish to mirror run:

     ```
     fossil2git/bin/setup-import <state> <fossil-repository-url>
     ```

     This initializes everything in the state directory for pulling
     the repository, and conversion to a local git repository.

  *  Then for each project in the state and git destination repository
     to mirror to run

     ```
     fossil2git/bin/setup-export <state> <project> <git-repository-url>
     ```

  *  To actuall perform the mirroring you then to regularly run

     ```
     fossil2git/bin/do-mirror <state>
     ```

     A cron job is likely the best for that. Remember however that
     cron is notoriously fiddly with regard to the environment
     variables provided to the jobs.

     Make sure that:

     - Your PATH provides access to fossil, git, awk.

     - A proper USER variable is set, for fossil to pick up.

     - If you have git destination repositories which are accessed
       through "ssh" this has to be in the PATH as well, of course,
       and ssh better have access to an ssh-agent loaded with all the
       necessary keys so that it can run without having to
       interactively ask for passwords and the like.

