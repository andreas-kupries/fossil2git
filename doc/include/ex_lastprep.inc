
Now that we have configured all the big obvious things needed for the
generation and distribution of the notifications we have one last
thing to do:

[example {
    fx note mark-notified --all -R /path/to/the/fossil/repository/file
}]

This tells [vset PROJECT] that we do not wish to generate and send
notification mails for everything which is already in the timeline of
the project at this moment.

This is [emph {especially important}] when setting up the
notifications for a project which has already run for some time.

The project's developers and ticket submitters will most emphatically
not wish to receive a deluge of emails for changes which have already
been done in the past.
