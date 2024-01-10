#!/usr/bin/bash

# select place
select place in casablanca amsterdam kiev
do
  # silently downloading the weather report
  wrep=$(curl -s wttr.in/$place)
  break # without "break" it will be stuck in the select loop
done

# exctracting string with temperatures
tps=$(echo $wrep | grep -oP '\S+\s+\xC2\xB0C' | cut -d ' ' -f1 | sed 's/\(([^)]*)\)//g')
# the page code is searched through for a regular expression '\S+\s+\xC2\xB0C', where xC2\xB0C is a centrigrade symbol 
# -o outputs the matching part of the line and -P (Perl-compatible) allows for enhanced regexps
# then the space-separated centrigrade symbol is cut off
# and a grouping construct \(([^)]*)\) is applied to eliminiate (substitute for nothing, globally) the parentheses 
# and all therein, \( and \) are literally opening and closing parentheses, 
# [^)] = ALL BUT a closing parantheses, * - zero or unlimited number of times
# see more @ https://regex101.com/

#converting the string to array
IFS=$'\n' read -r -d '' -a temps <<< "$tps"

echo "Current temperature is ${temps[0]} degrees"
echo "Tomorrow at noon will be ${temps[2]} degrees"
