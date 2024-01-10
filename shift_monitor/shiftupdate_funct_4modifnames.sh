# the script requires csvkit (https://csvkit.readthedocs.io) 
# to change a CSV delimiter from a default comma 
# in case someone decides to use a comma in a cell;
# to install the package, do: $ sudo pip install csvkit

#!/usr/bin/bash

# changing to chosen working directory so that all relative paths work correctly
# do the same in the script you run and in the cron command line (write cd /path && ./script.sh)
cd /home/str/shifts_script/actual_script

team_member="Serhii (32)"
location="Location 1"

# define date
date_for_name=$(date +%H%m_%a_%d_%m_%Y_%s)
date_in_sec=$(date +%s)
new_filename_commas="CSV_cms_backup_$date_for_name.csv" # CSV to be downloaded
new_filename="CSV_backup_$date_for_name.csv" # CSV with modified delimiters
XLS_filename="XLS_backup_$date_for_name.xlsx" # backup XLSX

echo "Current file: $new_filename"

# define CSV delimiter as a pipe 
# it is a comma by default, which might be a problem if there is another comma in a cell
CSV_delim="|"

# reset the email file
echo -n > to_email.txt

# download backup xls and csv, append date and time to the name
# downloads a file in the format of CSV_cms_backup_1101_Tue_09_01_2024_1704796201.csv in the script folder
wget -q -O $new_filename_commas "https://docs.google.com/spreadsheets/d/GOOGLE_DOC_ID/export?format=csv&id=GOOGLE_DOC_ID&gid=SHEET_ID"
# downloads a file in the format of XLS_backup_backup_1101_Tue_09_01_2024_1704796201.xlsx in the script folder
wget -q -O $XLS_filename "https://docs.google.com/spreadsheets/d/GOOGLE_DOC_ID/export?format=xlsx"

# replacing the delimiter for $CSV_delim
csvformat -D "$CSV_delim" $new_filename_commas > $new_filename    

# appending a core of the name of downloaded file to the log
echo $date_for_name >> backup.log 

# delete backups that are older than a week
for file in $(ls *.csv *.xlsx); do
	when_modified=$(date -r $file +%s)
	if (( $(( date_in_sec-when_modified )) > $(( 60*60*24*7 )) ))
	then
		rm $file
	fi
done

# keeping the length of backup.log to 500 lines maximum
if (( $(wc -l backup.log | cut -d ' ' -f1) > 500 ))
then
	tail -500 backup.log > temp.log
	mv temp.log backup.log
fi

# sourcing the previous backup CSV from the penultimate line of the log
old_filename="CSV_backup_$(tail -2 < backup.log | head -1).csv"
echo "Old file: $old_filename"

# defining a function for data extraction
# its $1 can be "old" or "new" (see the for-loop thereafter)
extracted_data() { 
	# using the first and only anrgument of the function to construct filename and version
	filename=$(echo "$1_filename") # $filename stores another variable name inside, and thus becomes an indirection variable; it needs to be referrred to with an exclamation point (see below)
	ver="$1" # but not $ver, it's just equal to $1

	# take a .csv and exctract date and shift arrays from it
	loc_lines=$(grep -i -n "$location" ${!filename} | cut -d ':' -f1)
	IFS=$'\n' read -r -d '' -a loc_arr <<< "$loc_lines"
	name_lines=$(grep -i -n "$team_member" ${!filename} | cut -d ':' -f1)
	IFS=$'\n' read -r -d '' -a name_arr <<< "$name_lines"

	# the extraction function is anchored on $location (case-insensitive) in the head of every table
	# if it is not higher than 12 lines away from the team member's name,
	# they are assumed to be a part of the shift table

	# declaring the namereference to handle dynamically generated name
	declare -n nameref="${ver}_month_arr"  

	# the number of columns in the shift table, $location and all that follows
	len_loc_arr=${#loc_arr[@]}

	# iterate for every column, the one with $location and after
	for (( i=0; i <= $(( len_loc_arr-1 )); i++ )); do
		# and see if $location has team member's name not more than 12 lines below
		# if so, we've found another shift table
		# the team member's shifts will be parsed into arrays named after a respective month
		# and another (index) array will be created to store the month names
		# to allow for a comparison even if there are drastic document changes
		# and things were moved around	
		if (( $(( name_arr[$i]-loc_arr[$i] )) <= 12 ))
		then 
			month_days_line=$(head -$(( loc_arr[$i]+1 )) ${!filename} | tail -1)
			# echo $month_days_line
			month=$(echo $month_days_line | awk -F"$CSV_delim" '{print $1}')
			IFS=$CSV_delim read -r -d '' -a ${ver}_month_days_arr_$month <<< "$month_days_line"

			weekday_line=$(head -$(( loc_arr[$i] )) ${!filename} | tail -1)
			IFS=$CSV_delim read -r -d '' -a ${ver}_weekday_arr_$month <<< "$weekday_line"

			name_shift_line=$(head -$(( name_arr[$i] )) ${!filename} | tail -1)
			IFS=$CSV_delim read -r -d '' -a ${ver}_name_shift_arr_$month <<< "$name_shift_line"

			nameref+=($month)
			
			# as seen above, one can generate arrays with dynamic names, but bash does not support dynamic names to access info within arrays
			# for such access, namereferencing needs to be done
			# let's make sure these arrays are of equal length to ensure there are no data extraction issues

			declare -n ref_month_days="${ver}_month_days_arr_$month"
			len_month_days=${#ref_month_days[@]}

			declare -n ref_weekday="${ver}_weekday_arr_$month"
			len_weekday=${#ref_weekday[@]}

			declare -n ref_name_shift="${ver}_name_shift_arr_$month" 
			len_name_shift=${#ref_name_shift[@]}

			if [[ $len_month_days != $len_weekday ]] || [[ $len_weekday != $len_name_shift ]] || [[ $len_name_shift != $len_month_days ]]
			then
				echo "Data extraction error!" >> to_email.txt
				echo "Array lenghts are unequal in $month, ${ver} version of the file." >> to_email.txt
			fi
		fi
	done
}

# runnung the extracted_data() function for the current ("new") CSV and the previous ("old") version 
new_or_old=("new" "old")
for version in ${new_or_old[@]}; do 
        extracted_data "$version"
done

# generating an output if a schedule for another month is added
# new schedules are normally added on top of the document
# so their month will show first in the array
n_months_old=${#old_month_arr[@]}
n_months_new=${#new_month_arr[@]}

if [[ $n_months_new > $n_months_old ]]
then
	echo "A new schedule was added!" >> to_email.txt 
	echo "New month: ${new_month_arr[0]}" >> to_email.txt
	echo >> to_email.txt
fi

######################################################################################
################# COMPARING SHIFT ARRAYS FROM OLD AND NEW FILES ######################
######################################################################################

# using ${old_month_arr[@]} for it not to freak out when a schedule for another month is added
for item in ${old_month_arr[@]}; do
declare -n len_ref="new_month_days_arr_$item"
len_month=${#len_ref[@]}

# below comes a bunch of dynamically generated array names
# since bash does not support those, they need to be namereferenced before they can be used in the for-loop

declare -n new_name_shift_arr_ref="new_name_shift_arr_$item"   
declare -n old_name_shift_arr_ref="old_name_shift_arr_$item"  
declare -n new_month_days_arr_ref="new_month_days_arr_$item" 
declare -n new_weekday_arr_ref="new_weekday_arr_$item" 

	# i=0 is a title for all arrays, soo...
	for (( i=1; i <= $(( len_month-1 )); i++ )); do

# need dollar signs before arrays in comparison below, otherwise they'll be taken as literals without comparing the content
		if [[ "${new_name_shift_arr_ref[$i]}" != "${old_name_shift_arr_ref[$i]}"  ]]
		then
			echo "Shift change!" >> to_email.txt
			echo "Your schedule was altered!" >> to_email.txt
			echo -n "Your shift on $item ${new_month_days_arr_ref[$i]} " >> to_email.txt
			echo -n "(${new_weekday_arr_ref[$i]}) " >> to_email.txt
			echo -n "was changed from " >> to_email.txt
			echo -n "${old_name_shift_arr_ref[$i]} to " >> to_email.txt
			echo "${new_name_shift_arr_ref[$i]}." >> to_email.txt
			echo >> to_email.txt
		fi
	done
done

# appending names of XLS files to be emailed
echo "Current file:$XLS_filename" >> to_email.txt
echo "Old file:XLS_backup_$(tail -2 < backup.log | head -1).xlsx" >> to_email.txt


