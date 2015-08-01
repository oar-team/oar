oaraccounting
-------------

This command permits to update the :ref:`database-accounting-anchor` table for jobs ended since the
last launch.

Option ``--reinitialize`` removes everything in the :ref:`database-accounting-anchor` table and
switches the "accounted" field of the table :ref:`database-jobs-anchor` into "NO". So when you will
launch the oaraccounting_ command again, it will take the whole jobs.

Option ``--delete_before`` removes records from the :ref:`database-accounting-anchor` table that are
older than the amount of time specified. So if the table becomes too big you
can shrink old data; for example::

    oaraccounting --delete_before 2678400

(Remove everything older than 31 days)
