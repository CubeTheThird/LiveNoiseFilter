#!/bin/bash

time=5

workDir=$(mktemp -d)

noiseFile="noise.wav"

sinkName="filtered.audio"

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
	pactl unload-module module-null-sink
	exit
}


cd $workDir
trap quit SIGINT

#get list of input devices (with details)
	inputs=$(pactl list short sources | grep -v monitor)

#abort if devices aren't available
	if [ $(echo "$inputs" | wc -l) -lt 1 ]; then
		echo "No input devices detected. Aborting"
		exit
	fi

inputIndex=0
#allow user selection when multiple devices are available
	if [ $(echo "$inputs" | wc -l) -gt 1 ]; then
		echo "Multiple input devices detected. Select from this list:"
		echo "$inputs" | awk -F '\\s' '{print NR-1," ",$2}'
		read -p "Enter an index:" inputIndex
	fi
	inputs=$(echo "$inputs" | awk -v idx=$inputIndex '{if (NR-1 == idx) print}')

#load device names
	input=$(echo "$inputs" | awk -F '\\s' '{print $2}')

#get input device specs
	format=$(echo "$inputs" | awk -F '\\s' '{print $4}')
	echo $format
	#number type
	tmp=$(echo $format | grep -o "^[fus]")
	case $tmp in
		f ) encoding="floating-point";;
		s ) encoding="signed-integer";;
		u ) encoding="unsigned-integer";;
	esac
	#bit count
	bits=$(echo $format | grep -o "[0-9]*")
	#endianness
	tmp=$(echo $format | grep -o "[bl]e$")
	case $tmp in
		be ) endian="-B";;
		le ) endian="-L";;
	esac
	#channels
	channels=$(echo "$inputs" | awk -F '\\s' '{print $5}' | grep -o "[0-9]*")
	#bitrate
	sampleRate=$(echo "$inputs" | awk -F '\\s' '{print $6}' | grep -o "[0-9]*")

#detect if the null sink has already been created, else create one
	if [ $(pactl list short sinks | grep -c $sinkName) -eq 0 ]; then
		echo "Creating new audio sink for output."
		pactl load-module module-null-sink sink_name=$sinkName channels=$channels rate=$sampleRate format=$format sink_properties=device.description="Filtered_Audio_Sink"
	else
		echo "Re-using existing audio sink for output."
	fi

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
pacat -r -d $input --latency=1msec | sox -b $bits -e $encoding -c $channels -r $sampleRate $endian -t raw - -t raw - noisered noise.prof 0.2 | pacat -p -d $sinkName --latency=1msec