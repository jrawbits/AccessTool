This folder will construct the sample data files for the AccessR tool suite.

In order to get the checksums right, you should run this script on your own
toolserver as part of the tool installation, rather than using the files as
they are.  The provided files and checksums will work on most Linux installations,
but you will have problems due to line-end conventions if you use the provided
sample files on a Windows machine without re-running the preparation script.

Use Rscript to run prepare.sample.data.R, then use the standard collectstatic
management function to place the resulting files into the proper location.

You should verify the checksums for each sample file (checksums.txt) and
make sure that the checksum in the tool_configs for each files is identical.
Failure to do so will prevent the sample files from loading.

