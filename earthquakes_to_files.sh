#!/bin/bash

# Script to scan through seismic data and output individual files for each earthquake 
# Each file contains a one line header than must be removed, and a single column of data corresponding to the amplitude in counts# In this script, we assume that the data is noise free, and that the amplitude of the seismic data exceeds a defined threshold only when an earthquake occurs. 
# This is a vast simplification, but is justified for the data I am interested in. 
# The threshold has been selected following careful testing on subsets of the data.

# 1. User defines time range of data to read in
# 2. Remove offset from the data, by subtracting the mean from each value in the file
# 3. Scan through data until data point greater than a given threshold.
# 4. When this is find, output data to a new file for a time window around that earthquake
# 5. Continue to scan data until next event is found, repeat.

# Set minimum threshold for the amplitude to constitute as an event (unit = counts) and the period of time to extract from file for that event (seconds)
# Background maximum generally between 150 and 200 above mean. Setting threshold as 4 times the average of this (175 * 4 = 700)
threshold=700
eventperiod=20 # seconds
eventnoofrows="$(($eventperiod * 100))" # Sample frequency is 100Hz, so 20 seconds is 2000 rows of data

# Asking user to define the data to read
echo -n "Start date? (mm/dd/yyyy) > "
read start_date
echo -n "End date? (mm/dd/yyyy) > "
read end_date
echo -n "Seismic station? (ARA2, POND or RETU) > "
read station

# Defining variables needed for names of files
startdayofyear="$(date -ud"$start_date" +%j)"
enddayofyear="$(date -ud"$end_date" +%j)"
startyear="$(date -ud"$start_date" +%Y)"
endyear="$(date -ud"$end_date" +%Y)"
# Days since Unix epoch, 1/1/1970
days1970tostart="$(echo $(($(date +%s -ud$start_date)/86400)))"
days1970toend="$(echo $(($(date +%s -ud$end_date)/86400)))"

# Defining data to be read, which component of each seismometer?
if [ "$station" ==  "ARA2" ]; then 
component="SHZ"
elif [ "$station" ==  "POND" ]; then
echo -n "Component? (HHZ, HHE, HHN) > "
read component
elif [ "$station" ==  "RETU" ]; then 
component="SHZ"
else exit 1
fi

# Creating list of days to be scanned, saving to file. Will loop over this later. 
seq "$days1970tostart" 1 "$days1970toend" > dayrangetmp.txt

# Creating file that lists hours 00 to 23, saving to file to loop over later.
# If less only one day is requested by the user, asking what range of hours they would like to scan.
if [ "$start_date" ==  "$end_date" ]; then
echo -n "Start hour? (hh, 00 to 23) > "
read start_hour
echo -n "End hour? (hh, 00 to 23) > "
read end_hour
seq -w "$start_hour" 1 "$end_hour" > hourlist.txt
else
seq -w 00 1 23 > hourlist.txt
fi

#--------------loop on each day----------------------------------------------

while read day; do

    # Storing temporal information for that day as variables, to be used when reading in files
    epochdaybeg="$(($day * 86400))"
    year="$(date -ud @$epochdaybeg +%Y)"
    month="$(date -ud @$epochdaybeg +%m)"
    dayinmonth="$(date -ud @$epochdaybeg +%d)"

    #--------------loop on each hour----------------------------------------------

    while read hour; do

	# If files exists
	if [ -f /nfs/a136/SeismicData/Tungurahua/"$station"/"$component"/"$year"/"$month"/"$dayinmonth"/EC."$station"."$component".D."$year"."$month"."$dayinmonth"."$hour".ascii ] ; then

	    # Creating temporary file, "fullhour.ascii", to includes data for that hour
	    cp /nfs/a136/SeismicData/Tungurahua/"$station"/"$component"/"$year"/"$month"/"$dayinmonth"/EC."$station"."$component".D."$year"."$month"."$dayinmonth"."$hour".ascii fullhour.ascii

	    # '1d' Removes first line of input file (header)
	    sed '1d' /nfs/a136/SeismicData/Tungurahua/"$station"/"$component"/"$year"/"$month"/"$dayinmonth"/EC."$station"."$component".D."$year"."$month"."$dayinmonth"."$hour".ascii > tmp.ascii

	    # Computing mean value of all rows in file
	    var="$(awk '{ total += $1 } END { print total/NR }' tmp.ascii)"
	    # Storing mean as an integer, rounding to the nearest value as int automatically rounds down.
	    mean="$(echo $var | awk '{print int($1+0.5)}')"
	    # Subtracting mean from each value in data, so it is centred around 0.
	    awk -v mean="$mean" '{print ($1 - mean)}' tmp.ascii > meansub.ascii
	    mv meansub.ascii tmp.ascii

	    replace_next_value() {
		# Flag first occurence with value over threshold and store the row number as a variable
		# We need to check also that the input is a number to skip the Nans
		eventrow="$(awk '{print NR " " $1}' tmp.ascii | awk -v threshold=$threshold '$2 ~ /^[0-9]+$/ && $2 > threshold {print $1; exit}')"
		[ -z "$eventrow" ] && return 1 # No more rows to replace
		startrow="$(($eventrow - 200))"
		secondsintohour="$(($startrow / 100))" # Number of seconds that have ellapsed in the hour leading up to the flagged value, used to computed minute
		minutes="$(($secondsintohour / 60))"
		seconds="$(($secondsintohour - ($minutes * 60)))" # Seconds into the minute 
		endrow="$(($startrow + $eventnoofrows - 1))"
		# Output range of rows to a new file, encompassing one earthquake. File name corresponds to the event start time.
		sed -n -e "$startrow,$endrow p" -e "$endrow q" tmp.ascii > event."$station"."$component"."$year"."$month"."$dayinmonth"."$hour"."$minutes"."$seconds".ascii
		echo -e "event."$station"."$component"."$year"."$month"."$dayinmonth"."$hour"."$minutes"."$seconds".ascii"
		# Replace rows with Nan value, so that they aren't flagged again in the next iteration.
		sed -i "${startrow},${endrow}s/.*/Nan/" tmp.ascii
		return 0
	    }

	    # Call the function until it returns 1, meaning that all the data has been scanned. If 0, event has been flagged.
	    while replace_next_value ; do continue; done

	else echo -e "\nEC."$station"."$component".D."$year"."$month"."$dayinmonth"."$hour".ascii does not exist. Moving on to next hour."
	fi

    done < hourlist.txt

    #loop on each hour END-------------------------------------------

done < dayrangetmp.txt

#loop on each day END-------------------------------------------

# Removing temporary files
rm tmp.txt hourlist.txt dayrangetmp.txt
