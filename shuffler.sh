#!/bin/bash

# Shuffler
# Video shuffler sourcing youtube/twitch/local sources
# Useful for xscreensaver or local playback
# tsunamibear <thissideofrandom@gmail.com>
#
#~ Options:
#~   hH		Print usage and exit
#~   gettitles	Anywhere in arg this will print titles/descriptions and exit
#~ 
#~   #		Arg one as number of seconds to play before moving to next clip
#~
#~ Notes:
#~   If a clip is shorter than the duration (Default: 300s)
#~   The duration will be set to the length of that clip for playback
#~   This results in the clip being played from start to finish

# VARS
dur=${1:-300}
_DIR="${HOME}/.config/shuffler"
_PPNAME=$(ps -o command= $PPID)

# PLAYLIST CHECK
if [ -f ${_DIR}/playlist ]; then
   mapfile -t videos < ${_DIR}/playlist && echo "Loaded ${#videos[@]} videos from ${_DIR}/playlist"
else
   echo "Couldn't find playlist under ${_DIR}"
   echo "Create the play list and run again"
   exit
fi

# HELP FUNCTION
print_help() {
   echo "Usage: ${FULL_NAME} [#] [hH] [printstring]"
   sed -ne 's/^#~//p' ${0}
}

# CLEANUP FUNCTION
cleanup() {
   echo "Closing $(jobs -p)"
   kill $(jobs -p) 2>/dev/null
   exit
}
trap cleanup INT TERM

# PRINT TITLES AND EXIT
if [[ $@ =~ gettitles ]]; then
   for i in ${!videos[@]}; do

      # Regular file
      if [ -f ${videos[$i]} ]; then
         echo "File name"
	 echo ${videos[$i]}
	 echo
      # Titles for web. Tested with youtube/twitch
      else
	 # Grab twitch stream description
	 if [[ ${videos[$i]} =~ twitch ]]; then
            echo "Description for ${videos[$i]}"
	    youtube-dl --get-description ${videos[$i]}
	 # Youtube video title
         else
            echo "Title of ${videos[$i]}"
	    youtube-dl --get-title ${videos[$i]} 2>/dev/null || echo "Error retrieving..."
         fi

	 echo
      fi

   done   
   exit
elif [[ ${@} =~ [hH] ]] || [[ ! ${dur} =~ ^[0-9]+$ ]]; then
   print_help
   exit
fi 

# GET TIME IN SECONDS FUNCTION
gettime () {
   # Start of function
   echo -n "Getting time(seconds) of ${videos[$1]} - "
   
   # Get regular file time
   if [ -f ${videos[$1]} ]; then
      titles[$1]=${videos[$1]##*/}
      times[$1]=$(date -ud "1970/01/01 $(ffprobe -i ${videos[$1]} -show_entries format=duration -v quiet -of csv="p=0" -sexagesimal)" +%s)
   # Catch twitch stream, time will alway equal duration
   elif [[ ${videos[$1]} =~ twitch ]]; then
      titles[$1]=$(youtube-dl --get-description ${videos[$1]})
     
      # If stream offline return an error to skip trying to play.
      # This should also allow us to check later if it comes online 
      if [ $? -gt 0 ]; then
         echo 
         return 1
      # Otherwise we set the time of the video to duration since we will always stream for max time
      else
         times[$1]=${dur}
	 echo "LIVE"
	 echo
       fi

      return
   # Catch any others, only tested with youtube links
   else
      mapfile -t results <<<$(youtube-dl --get-title --get-duration ${videos[$1]})
      titles[$1]=${results[0]}
      times[$1]=$(date -ud "1970/01/01 ${results[1]}" +%s)
   fi
   
   # Return time for stdout
   echo "${times[$1]}s" 
   echo
}

# PLAY VIDEO FUNCTION
playvid () {
   # Draw to xscreensaver window if run from xscreensaver
   if [[ ${_PPNAME} =~ xscreensaver ]]; then
      mpv --osc=no --no-stop-screensaver --wid=${XSCREENSAVER_WINDOW} --really-quiet --mute=yes --start=${starttime:-0} --length=${dur} ${videos[$1]} &
   # Generic play command
   else
      mpv --osc=no --really-quiet --mute=yes --no-border --geometry=961x526+959+554 --start=${starttime:-0} --length=${dur} ${videos[$1]} &
   fi
}

# TEMPORARY SETTING FOR DEMO WINDOW
if [[ ${_PPNAME} == xscreensaver-demo ]]; then
   # The xscreensaver demo window passes custom args overwriting duration
   dur=10
fi

# MAIN
while :; do
   # Generate random index for video to play
   vindex=$((RANDOM%${#videos[@]}))
  
   # Get time if we don't have it for next video
   if [ -z "${times[$vindex]}" ]; then gettime $vindex || continue; fi

   # Wait for any background videos to finish before playing next
   wait

   # Check if duration is longer than video and adjust accordingly
   if [[ ${times[$vindex]} -lt ${dur} ]]; then
      echo "Adjusting duration for shorter video length - ${times[$vindex]}s" 
      oldur=${dur}
      dur=${times[$vindex]}
      starttime=$((RANDOM%((${times[$vindex]}+1)-(${dur}))))
   else
      # Set random start time based on duration
      starttime=$((RANDOM%((${times[$vindex]}+1)-${dur})))
   fi

   # Start up video by index. Background so we can get the next video ready to play
   echo "Video/Stream [${vindex}] - ${videos[$vindex]}"
   echo "Title: ${titles[$vindex]}"
   echo "Playing ${dur}s starting at ${starttime} out of ${times[$vindex]}s"
   echo
   playvid ${vindex}; 

   # Reset duration if it was changed for a short video
   if [[ ${oldur} -gt 0 ]]; then
      echo "Setting duration back to ${oldur}s"
      echo
      dur=${oldur}
      unset oldur
   fi
done
