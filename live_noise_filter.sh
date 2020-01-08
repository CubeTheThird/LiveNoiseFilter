#!/bin/bash

which sox > /dev/null 2>&1 || (echo "SoX not found. Please install Sound eXchange to proceed." && exit)

time=5

workDir=$(mktemp -d)

noiseFile="noise.wav"

#record noise sample
record()
{
	read -p "Recording background noise. Keep quiet for $time seconds. Press Enter to start."
	sleep 0.5
	parecord -d $input $noiseFile &
	PID=$!
	sleep $time
	kill $PID
	echo "Playing back noise sample"
	paplay $noiseFile
}

quit()
{	
	cd -
	rm -rf "$workdir"
	sudo modprobe -r snd_aloop
	exit
}

cd $workDir
trap quit SIGINT

#detect if aloop module is loaded
#allow the user to load the module here
	if [ $(lsmod | grep -c snd_aloop) -eq 0 ]; then
		echo "ALOOP module is not loaded."
		read -p "Attempt to load the module?[y/n]" yn
	    case $yn in
	        [Yy]* ) sudo modprobe snd_aloop;;
	        [Nn]* ) exit;;
	        * ) echo "Please answer yes or no.";;
	    esac
	fi

#get list of input and output devices (with details)
	inputs=$(pactl list short sources | grep -E -v '(monitor|aloop)')
	outputs=$(pactl list short sinks | grep aloop)

#abort if devices aren't available
	if [ $(echo "$inputs" | wc -l) -lt 1 ]; then
		echo "No input devices detected. Aborting"
		exit
	fi

	if [ $(echo "$outputs" | wc -l) -lt 1 ]; then
		echo "No output devices detected. Aborting"
		exit
	fi

inputIndex=0
#allow user selection when multiple devices are available
	if [ $(echo "$inputs" | wc -l) -gt 1 ]; then
		echo "Multiple input devices detected. Select from this list:"
		echo "$inputs" | awk -F '\\s' '{print NR-1," ",$2}'
		read -p "Enter an index:" inputIndex
		exit
	fi
	inputs=$(echo "$inputs" | awk -v idx=$inputIndex '{if (NR-1 == idx) print}')

outputIndex=0
#allow user selection when multiple devices are available
	if [ $(echo "$outputs" | wc -l) -gt 1 ]; then
		echo "Multiple output devices detected. Select from this list:"
		echo "$outputs" | awk -F '\\s' '{print NR-1," ",$2}'
		read -p "Enter an index:" outputIndex
		exit
	fi
	outputs=$(echo "$outputs" | awk -v idx=$outputIndex '{if (NR-1 == idx) print}')

#load device names
	input=$(echo "$inputs" | awk -F '\\s' '{print $2}')
	output=$(echo "$outputs" | awk -F '\\s' '{print $2}')


#get input device specs
	format=$(echo "$inputs" | awk -F '\\s' '{print $4}')
	#number type
	tmp=$(echo $format | grep -o "^[fus]")
	case $tmp in
		f ) inputEncoding="floating-point";;
		s ) inputEncoding="signed-integer";;
		u ) inputEncoding="unsigned-integer";;
	esac
	#bit count
	inputBits=$(echo $format | grep -o "[0-9]*")
	#endianness
	tmp=$(echo $format | grep -o "[bl]e$")
	case $tmp in
		be ) inputEndian="-B";;
		le ) inputEndian="-L";;
	esac
	#channels
	inputChannels=$(echo "$inputs" | awk -F '\\s' '{print $5}' | grep -o "[0-9]*")
	#bitrate
	inputBitrate=$(echo "$inputs" | awk -F '\\s' '{print $6}' | grep -o "[0-9]*")


#get output device specs
	format=$(echo "$outputs" | awk -F '\\s' '{print $4}')
	#number type
	tmp=$(echo $format | grep -o "^[fus]")
	case $tmp in
		f ) outputEncoding="floating-point";;
		s ) outputEncoding="signed-integer";;
		u ) outputEncoding="unsigned-integer";;
	esac
	#bit count
	outputBits=$(echo $format | grep -o "[0-9]*")
	#endianness
	tmp=$(echo $format | grep -o "[bl]e$")
	case $tmp in
		be ) outputEndian="-B";;
		le ) outputEndian="-L";;
	esac
	#channels
	outputChannels=$(echo "$outputs" | awk -F '\\s' '{print $5}' | grep -o "[0-9]*")
	#bitrate
	outputBitrate=$(echo "$outputs" | awk -F '\\s' '{print $6}' | grep -o "[0-9]*")


#record noise sample
record
while true; do
    read -p "Do you wish to re-record the noise sample?[y/n]" yn
    case $yn in
        [Yy]* ) record;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

#create noise profile
sox $noiseFile -n noiseprof noise.prof

echo "Sending output to loopback device."
echo "Change recording port to <Loopback Analog Stereo Monitor> in PulseAudio to apply."
echo "Ctrl+C to terminate."

#filter audio from $input to $output
pacat -r -d $input --latency=1msec | sox -b $inputBits -e $inputEncoding -c $inputChannels -r $inputBitrate $inputEndian -t raw - -b $outputBits -e $outputEncoding -c $outputChannels -r $outputBitrate $outputEndian -t raw - noisered noise.prof 0.2 | pacat -p -d $output --latency=1msec