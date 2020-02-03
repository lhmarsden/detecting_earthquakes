# detecting_earthquakes

Script to scan through seismic data and output individual files for each earthquake
Each file contains a one line header than must be removed, and a single column of data corresponding to the amplitude in counts
In this script, we assume that the data is noise free, and that the amplitude of the seismic data exceeds a defined threshold only when an earthquake occurs. This is a vast simplification, but is justified for the data I am interested in. The threshold has been selected following careful testing on subsets of the data.

1. User defines time range of data to read in
2. Remove offset from the data, by subtracting the mean from each value in the file
3. Scan through data until data sample greater than a given threshold.
4. When this is find, output data to a new file for a time window around that earthquake
5. Continue to scan data until next event is found, repeat.
