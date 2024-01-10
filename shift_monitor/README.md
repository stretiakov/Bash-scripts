**Shift monitor script**

The script shiftupdate_funct_4modifnames.sh monitors and logs the changes in a Google Docs shift schedule spreadsheet, which is formatted in the way shown in XLS_backup_backup_1101_Tue_09_01_2024_1704796201.xlsx. If changes are detected or a new chedule is added, or there is a data extraction error, it sends a notification to an email given in shift_change.sh. The script is run hourly by cron.

**How it works: **
- The primary script for data extraction and comparison is shiftupdate_funct_4modifnames.sh. When run, it returns to_email.txt file, which is then checked by the secondary shift_change.sh for triggers that lead to an email notification being sent.
- When first started, the primary shiftupdate_funct_4modifnames.sh script downloads the .xlsx and the corresponding .csv files, which are formated as shown in this folder.
- It proceeds to changing the CSV delimiter from a comma to a pipe ("|") as some cells may have a comma in the contents, which will intefere with parsing the spreadsheet into a series of arrays.
- Checking if there are .csv or .xlsx files in the folder that are older than 7 days, and if so, it deletes them to prevent data build-up.
- Appending the date part of the filename to backup.log, from where it can be pulled to reconstruct the filenames of .csv and .xls files from any of the previous script runs.
- Making sure that backup.log is no longer than 500 lines to prevent data build-up.
- Using backup.log to reconstruct the name of a .csv file from the previous run (needed to detect the changes). Therefore, the script will only work correctly on the second time it is started.
- Defining a funtion that extracts three arays: day of the month, day of the week and shift schedule. It checks if they are of equal lenghth, otherwise a data extraction error is returned and emailed. The day-of-the-month array serves as an index array that stores names of other arrays, thus making the script insensitive to positional exchanges within the spreadsheet.
- Running the above defined function in the for-loop for the current spreadsheet and the version from the previous run.
- Checking if the length of an array containing month names has increased compared to the previous run, if so, returning a notification to to_email.txt that a schedule for a new month was added and which.
- Checking the changes in the shift arrays from the current and the previous runs. Return a notification to to_email.txt when there is a change, on what date, and what change exactly was made.

**How to run the script:**
  - In order to run, the script requires csvkit (https://csvkit.readthedocs.io) and mailutils (see installation instructions at https://linuxsimply.com/bash-scripting-tutorial/basics/examples/send-email/).
  - shift_change.sh needs to be run. It contains the command for starting the primary shiftupdate_funct_4modifnames.sh as well as it checks its output in to_email.txt and sends an email if necessary.
