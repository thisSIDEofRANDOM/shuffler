#!/bin/bash

# Shuffler
# Video shuffler sourcing youtube/twitch/local sources
# Useful for xscreensaver or local playback
# tsunamibear <thissideofrandom@gmail.com>


# VARS
dur=${1:-300}
_DIR="${HOME}/.config/shuffler"
_PPNAME=$(ps -o command= $PPID)

# PLAYLIST CHECK
if [ -f ${_DIR}/playlist ]; then
   mapfile -t videos < ${_DIR}/playlist
else
   echo "Couldn't find playlist under ${_DIR}"
   echo "Create the play list and run again"
   exit
fi

# CLEANUP FUNCTION
cleanup() {
    echo "Closing ${child}"
    kill ${child} 2>/dev/null
    exit
}
trap cleanup TERM EXIT

# HELPER FUNCTION
if [[ $@ =~ -gettitles ]]; then
   for i in ${!videos[@]}; do echo "Title of ${videos[$i]}"; youtube-dl --get-title ${videos[$i]} || break; echo; done
   exit
fi

# GET TIME IN SECONDS FUNCTION
gettime () {
   echo -n "Getting time(seconds) of ${videos[$1]} - "
   mapfile -t results <<<$(youtube-dl --get-title --get-duration ${videos[$1]})
   titles[$1]=${results[0]}
   times[$1]=$(date -ud "1970/01/01 ${results[1]}" +%s)
   echo "${times[$1]}" 
   echo
}

# PLAY VIDEO FUNCTION
playvid () {
   if [[ ${_PPNAME} =~ xscreensaver ]]; then
      mpv --osc=no --no-stop-screensaver --wid=${XSCREENSAVER_WINDOW} --really-quiet --mute=yes --start=${starttime:-0} --length=$dur ${videos[$1]} &
   else
      mpv --osc=no --really-quiet --mute=yes --no-border --geometry=961x526+959+554 --start=${starttime:-0} --length=${dur} ${videos[$1]} &
   fi
}

# TEMPORARY SETTING FOR DEMO WINDOW
if [[ ${_PPNAME} == xscreensaver-demo ]]; then
   dur=10
fi

# MAIN
while :; do
   # Generate random index for video to play
   vindex=$((RANDOM%${#videos[@]}))
  
   # Get time if we don't have it for next video
   if [ -z "${times[$vindex]}" ]; then gettime $vindex || break; fi
   # Set random start time based on duration
   starttime=$((RANDOM%(${times[$vindex]}-$dur)))

   # Wait for any background videos to finish before playing next
   wait	

   # Start up video by index. Background so we can get the next video ready to play
   echo "Playing video ${vindex} - ${videos[$vindex]}"
   echo "Title: ${titles[$vindex]}"
   echo "${dur}(seconds) starting at ${starttime} out of ${times[$vindex]}"
   echo
   playvid ${vindex}; child=$!
done
