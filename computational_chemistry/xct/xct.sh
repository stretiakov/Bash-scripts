#!/usr/bin/bash

export LOG_FILE=$1
export WORKDIR=$PWD

# checking what kind of jobs were done
# check whether the signle-point has not crashed
checkSP=`grep -c 'Normal termination of Gaussian' ${LOG_FILE}` 

# check whether geometry optimization converged
checkopt=`grep -c ' Optimized Parameters' ${LOG_FILE}` 

# check whether the frequency calculation was conducted
checkfreq=`grep -c 'correction to Enthalpy' ${LOG_FILE}` 

# check whether the NMR shielding tensor calculation was conducted
checknmr=`grep -c 'Magnetic shielding tensor' ${LOG_FILE}` 

# check whether NBO was launched 
checknbo=`grep -c 'N A T U R A L' ${LOG_FILE}`

filename=`echo ${LOG_FILE} | awk -F . '{print $1}'`

# showing the .log-file name as well as the options requsted in the .inp file
echo '  ##  '${LOG_FILE}'  ##  '
echo ' - FROM INPUT: - '
echo 'requested: '`head -n 1 ${filename}.inp | grep -Eoi 'NMR|NBO|opt|freq|EPR'`
echo 'functional/basisset: '`head -n 1 ${filename}.inp | tr " " "\n" | grep '/' | tr -d "#" | tr "/" " "`

# showing results of the calculation from the .log-file
# returning point group
echo ' - RESULTS: - '
if grep -c 'point group' ${LOG_FILE} > 1 ; then 
	echo -n 'point_group = '
	grep 'point group' ${LOG_FILE} | tail -n 1 | awk '{print $4}'
else
echo 'point group not defined'
fi

# check the status of a single point calculation
if [ ${checkSP} -ge 1 ]; then
	if [ ${checkopt} == 0 ]; then
		echo 'Single point calculation successful'
		echo -n 'E_elec= '
		# print the last instance of SCF Done
		grep 'SCF Done' ${LOG_FILE} | tail -n 1 | awk '{print $5}' 
	fi
fi

# if optimization was requested, return the status and electronic energy
if [ ${checkopt} -ge 1 ]
then
	echo 'Optimization successful'
	echo -n 'E_elec= '
	# print the last instance of SCF Done
	grep 'SCF Done' ${LOG_FILE} | tail -n 1 | awk '{print $5}'	
	fi

# if a frequency calculation was requested, return enthalpy and Gibbs free energy correction (along with the respective Gibbs free energy)
if [ ${checkfreq} == 1 ]; then
	if [ ${checkopt} == 0 ]; then
		echo -n 'E_elec= '
		grep -B 10 -m 1 'NROrb' ${LOG_FILE} | grep 'SCF D' | awk '{print $5}' # find the last step of optimization, print 10 lines above, within that, find sentence containing 'SCF D', print the 5th part of that sentence.
        fi
	echo -n 'Thermal_corr_Gibbs= '
	grep 'Gibbs Free Energy=' ${LOG_FILE} | tail -n 1 | awk '{print $7}' #print the last instance of SCF Done
	echo -n 'Enthalpy= ' 
        grep 'thermal Enth' ${LOG_FILE} | awk '{print $7}' # Only zero or one instance of thermal Enth will ever be in a *.log file.
	echo -n 'Gibbs_free= ' 
	grep 'thermal Free En' ${LOG_FILE} | awk '{print $8}' # Only zero or one instance of Free En will ever be in a *.log file.
	echo -n 'Lowest_frequency= ' 
	grep -m 1 'Frequencies' ${LOG_FILE} | awk '{print $3}' 
fi

# return the results of NMR calculation for
if [ ${checknmr} == 1 ]; then
	echo 'NMR calculations successful'
	# grep -q checks if a pattern exists in a file
	if grep -q 'Si   Isotropic' ${LOG_FILE}; then
		echo -n 'Absolute Si shift= '
		grep 'Si   Isotropic' ${LOG_FILE} | awk '{print $5}'
	elif grep -q 'P    Isotropic' ${LOG_FILE}; then
		echo -n 'Absolute P shift= '
		grep 'P    Isotropic' ${LOG_FILE} | awk '{print $5}'
	fi

	# checking if a J-coupling calculation was requested in the input file
	# and if so, return the constants
	if grep -q 'readatoms' ${filename}.inp; then

		# identify which atoms were requested in the input file, echo those and make an array out of the list
		atomsreq=`grep 'atoms=' ${filename}.inp | awk -F = '{print $2}' | tr "," " " | sort -r `
		echo "J-coupling output:"
		echo "requested atoms: $atomsreq"
 		IFS=" " read -r -d '' -a atomsreq_arr <<< "$atomsreq" 

		# find the line numbers in the .log file (grep -n) where J-coupling table starts and ends
		# it starts after the line containing 'Total nuclear spin-spin coupling J'
		start_table=$(( $(grep -n 'Total nuclear spin-spin coupling J' ${LOG_FILE} | cut -d ':' -f1) + 1 ))

		# it ends on a line before the first instance (grep -m 1) of 'End of Minotr'
		end_table=$(( $(tail -n +$start_table ${LOG_FILE} | grep -nm 1 'End of Minotr' | cut -d ':' -f1) + start_table - 2 ))

		# sectioning the coupling table out and storing it in a .tmpjdata file
		awk "NR >= $start_table && NR <= $end_table" ${LOG_FILE} > $filename.tmpjdata

		# finding lines where colum numbers are given and making them into an array
		index_lines=$(grep -n '^        ' "$filename.tmpjdata" | cut -d ':' -f1)
	        IFS=$'\n' read -r -d '' -a index_lines_arr <<< "$index_lines"	
		n_index_lines=${#index_lines_arr[@]}

		# sectioning the coupling table into subtables that don't have column numbers, removing spaces at the beginning of each line
	        # in sed regex, s/ is for "substitute", "^ \+" is for one or more spaces at the beginning of the line, 
		# "[0-9]\+" is for one or more digits, then comes another space and /g is for "global"
		# and inverting the line order (tac is the opposite of cat)
		# using < with wc -l because otherwise it also returns a file name	
		end_sect=$(wc -l < $filename.tmpjdata)
		for (( i=$(( $n_index_lines - 1 )); i >= 0; i-- )); do
			start_sect=$(( ${index_lines_arr[$i]} + 1 )) 
			awk "NR >= $start_sect && NR <= $end_sect" $filename.tmpjdata | sed 's/^ \+[0-9]\+ / /g' | tac > "table_sect_$i.tmpjdata"
			end_sect=$(( ${index_lines_arr[$i]} - 1))
		done	

		# merging all inverted subtables into one
  		# declaring an empty file first
		echo -n > inv_restored_table.tmpjdata
		for (( i = 0; i <= $(( $n_index_lines - 1 )); i++ )); do
			paste -d ' ' inv_restored_table.tmpjdata table_sect_$i.tmpjdata > temp.tmpjdata
			mv temp.tmpjdata inv_restored_table.tmpjdata 
		done

		# restoring the original line order
		tac inv_restored_table.tmpjdata > restored_table.tmpjdata

		# sectioning the coupling table into arrays
		n_lines=$(wc -l < restored_table.tmpjdata)
		for (( i=0; i <= $(( $n_lines - 1 )); i++ )); do
			line=$(head -$(( $i + 1 )) restored_table.tmpjdata | tail -1)
			IFS=" " read -r -d '' -a line_$i <<< "$line" 
		done

		# generating non-degenerate binary combinations from the list of atoms in $atomsreq_arr
		declare -a J_list
		n_atoms=${#atomsreq_arr[@]}  
		for (( i = 0; i <= $(( $n_atoms - 1 )); i++ )); do
			for (( j = $(( $i + 1 )); j <= $(( $n_atoms - 1 )); j++ )); do
			combo=$( echo "${atomsreq_arr[$i]}:${atomsreq_arr[$j]}" )
			J_list+=($combo)
			done
		done

		# outputting requested coupling constants
		for item in ${J_list[@]}; do
			atom_1=$( echo $item | cut -d ":" -f1 )
			col=$(( $atom_1 - 1 ))
			atom_2=$( echo $item | cut -d ":" -f2 )
			lin=$(( $atom_2 - 1 ))
			echo -n "J($atom_1,$atom_2) = "			
			declare -n nameref="line_$lin"
			echo "${nameref[$col]} Hz"
		done	      

echo "end of J-coupling output"
rm *.tmpjdata

	fi
fi

# checks if NBO calculation was successful 
if [ ${checknbo} -ge 1 ]; then
	echo 'NBO calculations successful'
fi

echo "*** Analysis complete ***" 



