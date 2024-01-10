# the script requires installed mailutils (https://linuxsimply.com/bash-scripting-tutorial/basics/examples/send-email/)

#!/usr/bin/bash

# changing to chosen working directory so that all relative paths work correctly
# do the same in the script you run and in the cron command line (write cd /path && ./script.sh)
cd /home/str/shifts_script/actual_script

# running the script
./shiftupdate_funct_4modifnames.sh

recepient="xxx@email.com"
subject="$(head -1 to_email.txt)"
body="$(cat to_email.txt)"
curr_xls="$(pwd)/$(tail -2 to_email.txt | head -1 | cut -d ':' -f2)"
old_xls="$(pwd)/$(tail -1 to_email.txt | cut -d ':' -f2)"

# emailing only if an event occurs: mismatch in array length, a shift change or a new schedule is added
# appending the XLSX files before and after change
if [[ "$subject" = "Shift change!" ]] || [[ "$subject" = "Data extraction error!" ]] || [[ "$subject" = "A new schedule was added!" ]]
then
	cat to_email.txt | mailx -s "$subject" -A "$curr_xls" -A "$old_xls" "$recepient"
fi





