# the script takes a CSV table "array.csv", parses all its colums into spearate strings, converts them to arrays
# takes a difference between the two last columns and outputs a new file with that difference

#/usr/bin/bash

# downloading the file
wget -q -O array.csv https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-LX0117EN-SkillsNetwork/labs/M3/L2/arrays_table.csv 

n_col=$(head -1 array.csv | tr ',' ' ' | wc -w) # counting columns
echo -n "The table has $n_col columns "

# parsing counted columns into separate arrays
for (( i=0; i<=(($n_col-1)); i++ )); do # do as many times as there are columns
    titled_column=$(cut -d ',' -f$(($i+1)) array.csv) # cutting out columns 
    column_n="column$i" # dynamically generating a variable for each column
    declare "$column_n=$titled_column" # assigning this variable to a column
    IFS=$'\n' read -r -d '' -a col$i <<< "${!column_n}" # reading a string into array (delimiter is a new line)
done

len=$(echo "${column0[@]}" | grep -c $'\n') #counting lines
echo "and $len lines, the first of which is a header line."

# new array that is a difference between the last column and that before
for (( i=1; i<=(($len-1)); i++ )); do # i=0 of every array is a title
    diff[$i]=$(( col$(( $n_col-1 ))[$i]-col$(( $n_col-2 ))[$i] )) # populating a difference array 
done

# titling the difference array
diff[0]=$(echo "column_$n_col: difference")

# compiling the output file: first the lines, then stacking them in columns
for (( i=0; i<=(($len-1)); i++ )); do
    for (( j=0; j<=(($n_col-1)); j++ )); do
    temp="col$j"
    eval "echo -n \"\${$temp[$i]}, \" ">> output.csv # ${col$j[$i]} would not have worked, neither ${!temp[$i]} because Bash doesn't support two dymanic variables
                                                    # instead, before execution eval expands all variables, and escape characters (\) preclude literal interpretation
    done # the use of eval is ok here because the input is sanitized, otherwise it introduces safety risks
    echo ${diff[i]} >> output.csv
done
