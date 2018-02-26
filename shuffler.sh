#!/bin/bash

# Shuffler
# Video shuffler sourcing youtube/twitch/local sources
# Useful for xscreensaver or local playback
# tsunamibear <thissideofrandom@gmail.com>
#
#~ Options:
#~   hH		Print usage and exit
#~   fullscreen	Toggles fullscreenmode for non screensaver playback
#~   nomute	Turns mute off enabling sound for playback
#~   ontop	Sets MPV to start in 'ontop' mode
#~   gettitles	Anywhere in arg this will print titles/descriptions and exit
#~   twitch	Extracts ONLY twitch videos from playlist
#~ 
#~   #		Arg one as number of seconds to play before moving to next clip
#~
#~ Notes:
#~   If a clip is shorter than the duration (Default: 300s)
#~   The duration will be set to the length of that clip for playback
#~   This results in the clip being played from start to finish
#~
#~   If spun up by XScreensaver, will spawn a watcher function
#~   This function handles freezing video playback when SIGSTOP
#~    is sent to base script by XScreensaver for password entry

# VARS
DUR=${1:-300}
SIZE="--geometry=961x526+959+554"
MUTE="yes"
TOP=""
ERRCOUNT=0; MPVRET=0
_DIR="${HOME}/.config/shuffler"
_PPNAME=$(ps -o comm= ${PPID})

# CLEANUP FUNCTION
cleanup() {
   kill -SIGCONT $(jobs -p) 2> /dev/null
   kill $(jobs -p) 2> /dev/null
   echo
   exit
}
trap cleanup INT TERM 

# HELP FUNCTION
print_help() {
   echo "Usage: ${FULL_NAME} [#] {hH} [gettitles] [nomute] [fullscreen]"
   sed -ne 's/^#~//p' ${0}
}

# RANDOM FUNCTION
rnum() {
   # Generate a 3-Byte unsigned int 0-16777215 (~194 Days)
   od -vAn -N3 -tu < /dev/urandom
}

# CONVERT TO SECONDS FUNCTION
getseconds () {
   local SECONDS=0

   # Step through sexgesimal time stamps multiplying by 60 on the way
   for SEC in ${1//:/ }; do
      # Breaks with a day field, forcing base 10 for leading 0 numbers
      SECONDS=$((( SECONDS *= 60 ) + 10#${SEC} ))
   done

   # Return total
   echo ${SECONDS}
}

# GET TIME IN SECONDS FUNCTION
gettime () {
   # Start of function
   echo -n "Getting status/time(seconds) of ${VIDEOS[${1}]} - "
   
   # Get regular file time in sexagesimal time stamp and convert to seconds
   if [ -f ${VIDEOS[${1}]} ]; then
      TITLES[${1}]=${VIDEOS[${1}]##*/}
      TIMES[${1}]=$(getseconds $(ffprobe -i ${VIDEOS[${1}]} -show_entries format=duration -v quiet -of csv="p=0" -sexagesimal | cut -d. -f1))
   # Catch twitch stream, time will always equal duration
   elif [[ ${VIDEOS[${1}]} =~ twitch ]]; then
	   TITLES[${1}]=$(youtube-dl --socket-timeout 5 --get-description ${VIDEOS[${1}]} 2> /dev/null)
     
      # If stream offline return an error to skip trying to play.
      # This should also allow us to check later if it comes online 
      if [ ${?} -gt 0 ]; then
	 ((ERRCOUNT++))
	 echo "ERROR: Appears offline"
         echo 
         return 1
      # Otherwise we set the time of the video to duration since we will always stream for max time
      else
         TIMES[${1}]=${DUR}
	 echo "LIVE"
	 echo
       fi

      return
   # Handle YouTube playlists
   elif [[ ${VIDEOS[${1}]} =~ playlist ]] && [[ ${VIDEOS[${1}]} =~ youtube ]]; then
      mapfile -t RESULTS <<<$(youtube-dl --playlist-random --socket-timeout 5 --max-downloads 1 --get-title --get-id --get-duration ${VIDEOS[${1}]} 2> /dev/null)
      TITLES[${1}]=${RESULTS[0]}
      YLISTVID[${1}]=${RESULTS[1]}

      # Convert the result returned by --get-duration to seconds
      if [[ -v RESULTS[2] ]] && [[ ${#RESULTS[2]} -le 8 ]]; then
         TIMES[${1}]=$(getseconds ${RESULTS[2]})
      else
	 ((ERRCOUNT++))
	 echo "ERROR: Invalid time format"
	 echo
         unset -v TIMES[${1}] TITLES[${1}]
	 return 1
      fi

      # Return time and selected playlist video
      echo "PLAYLIST"
      echo "Selected https://www.youtube.com/watch?v=${YLISTVID[${1}]} - ${TIMES[${1}]}"
      echo

      return
   # Catch any others, only tested with youtube links
   else
      mapfile -t RESULTS <<<$(youtube-dl --socket-timeout 5 --max-downloads 1 --get-title --get-duration ${VIDEOS[${1}]} 2> /dev/null)
      TITLES[${1}]=${RESULTS[0]}

      # Convert the result returned by --get-duration to seconds
      if [[ -v RESULTS[1] ]] && [[ ${#RESULTS[1]} -le 8 ]]; then
         TIMES[${1}]=$(getseconds ${RESULTS[1]})
      else
	 ((ERRCOUNT++))
	 echo "ERROR: Invalid time format"
	 echo
         unset -v TIMES[${1}] TITLES[${1}]
	 return 1
      fi
   fi
   
   # Return time for stdout
   echo "${TIMES[${1}]}s" 
   echo
}

# PLAY VIDEO FUNCTION
playvid () {
   # Set video url for playback, this should allow playlist swapping
   if [[ -v YLISTVID[${1}] ]]; then 
      local VURL="https://www.youtube.com/watch?v=${YLISTVID[${1}]}"
   else
      local VURL=${VIDEOS[${1}]}
   fi

   # Draw to xscreensaver window if run from xscreensaver
   if [[ ${_PPNAME} =~ xscreensaver ]]; then
      mpv --network-timeout=5 --osc=no --no-stop-screensaver --wid=${XSCREENSAVER_WINDOW} --really-quiet --mute=${MUTE} --start=${STARTTIME:-0} --length=${DUR} ${VURL} &
   # Generic play command
   else
      mpv --network-timeout=5 --osc=no --really-quiet --mute=${MUTE} --no-border ${SIZE} --start=${STARTTIME:-0} --length=${DUR} ${TOP} ${VURL} &
   fi
}

# XSCREENSAVER SIGSTOP && SIGCONT HANDLER
watcher() {
   local FREEZE=0

   # This tries to freeze MPV when the password screen comes up
   # Normaly XScreensaver passed a SIGSTOP to just the one child
   # Because this doesn't hit our child and can't be trapped we have to handle this 
   while :; do
      # When main script is hit by SIGSTOP from xscreensaver forward to MPV
      if [[ ${FREEZE} -eq 0 ]] && [[ $(ps -q ${$} -o state --no-headers) == T ]] && pkill -0 -P ${$} mpv; then
         echo "Freezing $(pgrep -P ${$} mpv)"
	 kill -SIGSTOP $(pgrep -P ${$} mpv)
	 FREEZE=1
      # Resume MPV when main pid resumes
      elif [[ ${FREEZE} -eq 1 ]] && [[ ! $(ps -q ${$} -o state --no-headers) == T ]] && pkill -0 -P ${$} mpv; then
         echo "Unfreezing $(pgrep -P ${$} mpv)"
	 kill -SIGCONT $(pgrep -P ${$} mpv)
	 FREEZE=0
      fi
      sleep 0.5
   done
}

# REQ CHECK
if ! command -v od > /dev/null; then
   echo "Missing od command required to run"
   exit
elif ! command -v youtube-dl > /dev/null; then
   echo "Missing youtube-dl command required to run"
   exit
elif ! command -v mpv > /dev/null; then
   echo "Missing mpv command required to run"
   exit
fi

# PLAYLIST CHECK
if [ -f ${_DIR}/playlist ]; then
   mapfile -t VIDEOS < ${_DIR}/playlist && echo "Loaded ${#VIDEOS[@]} videos/streams from ${_DIR}/playlist"
else
   echo "Couldn't find playlist under ${_DIR}"
   echo "Create the play list and run again"
   exit
fi

# XSCREENSAVER SPECIFICS 
if [[ ${_PPNAME} == xscreensaver-de ]]; then
   # The xscreensaver demo window passes custom args overwriting duration
   DUR=10
elif [[ ${_PPNAME} == xscreensaver ]]; then
   # Fork this to freeze video playback on password prompt.
   echo "XScreensaver detected, spinning up SIG watcher for proper freezing"
   watcher &
fi

# TWITCH ONLY SWITCH
if [[ ${@} =~ twitch ]]; then
   declare -a TEMPARRAY

   # Copy twitch streams to temp array and back
   for VALUE in ${VIDEOS[@]}; do
      [[ $VALUE =~ twitch ]] && TEMPARRAY+=($VALUE)
   done
   
   # Write over previous array and unset our temp array
   VIDEOS=("${TEMPARRAY[@]}")
   unset -v TEMPARRAY
   
   echo "Loaded ${#VIDEOS[@]} twitch streams from previous playlist"
fi

# HELP SWITCH
if [[ ${@} =~ [[:space:]][hH] ]] || [[ ! ${DUR} =~ ^[0-9]+$ ]] || [[ ${#VIDEOS[@]} -eq 0 ]]; then
   print_help
   exit
fi

# PRINT TITLES AND EXIT
if [[ ${@} =~ gettitles ]]; then
   echo

   for i in ${!VIDEOS[@]}; do

      # Regular file
      if [ -f ${VIDEOS[${i}]} ]; then
         echo "Local file"
	 echo ${VIDEOS[${i}]}
	 echo
      # Titles for web. Tested with youtube/twitch
      else
	 # Grab twitch stream description
	 if [[ ${VIDEOS[${i}]} =~ twitch ]]; then
            echo "Description for ${VIDEOS[${i}]}"
	    youtube-dl --socket-timeout 5 --get-description ${VIDEOS[${i}]}
	 # Youtube video title
         else
            echo "Title of ${VIDEOS[${i}]}"
	    youtube-dl --socket-timeout 5 --get-title ${VIDEOS[${i}]} 2> /dev/null || echo "Error retrieving..."
         fi
	 echo
      fi
   done   
   exit
fi

# FULLSCREEN SWITCH
if [[ ${@} =~ fullscreen ]]; then
   echo "[Enabled] - Fullscreen"
   SIZE="--fs"
fi

# MUTE SWITCH
if [[ ${@} =~ nomute ]]; then
   echo "[Enabled] - Audio"
   MUTE="no"
fi

# ONTOP SWITCH
if [[ ${@} =~ ontop ]]; then
   echo "[Enabled] - Ontop"
   TOP="--ontop"
fi

# END OF PRE MAIN OUTPUT
echo

# MAIN
while :; do
   
   # Check error count and sleep if greater than 5
   if [[ ${ERRCOUNT} -ge 5 ]]; then
      echo "Error count - ${ERRCOUNT}, sleeping 10s..."
      echo
      sleep 10

      # Reset counter
      ERRCOUNT=0
   fi

   # Generate random index for video to play
   VINDEX=$(($(rnum)%${#VIDEOS[@]}))
 
   # Always unset twitch stream times to check if live before this run
   if [[ ${VIDEOS[${VINDEX}]} =~ twitch ]]; then
      unset -v TIMES[${VINDEX}] TITLES[${VINDEX}]

      # Wait sooner for twitch streams to make sure not to check if live too early
      if pkill -0 -P ${$} mpv; then 
         echo "Waiting to check if ${VIDEOS[${VINDEX}]} is LIVE" 
         wait $(pgrep -P ${$} mpv)
         MPVRET=${?}
	 
	 # Track errors
	 if [[ ${MPVRET} -gt 0 ]] && [[ ${MPVRET} -lt 3 ]]; then
            ((ERRCOUNT++))
         elif [[ ${errcount} -gt 0 ]]; then
            ((ERRCOUNT--))
         fi
      fi
   # Always unset playlist stream time since well get a random video in the playlist
   elif [[ ${VIDEOS[${VINDEX}]} =~ playlist ]] && [[ ${VIDEOS[${VINDEX}]} =~ youtube ]]; then
      unset -v TIMES[${VINDEX}] TITLES[${VINDEX}]
   fi

   # Get time if we don't have it for next video
   if [ -z "${TIMES[${VINDEX}]}" ]; then gettime ${VINDEX} || continue; fi
   
   # Wait for any background videos to finish before playing next
   ( pkill -0 -P ${$} mpv ) && wait $(pgrep -P ${$} mpv)
   MPVRET=${?}
   
   # Try to track errors as best we can
   if [[ ${MPVRET} -gt 0 ]] && [[ ${MPVRET} -lt 3 ]] && [[ ! ${VIDEOS[${VINDEX}]} =~ twitch ]]; then 
      ((ERRCOUNT++))
   elif [[ ${ERRCOUNT} -gt 0 ]]; then
      ((ERRCOUNT--))
   fi

   # Check if duration is longer than video and adjust accordingly
   if [[ ${TIMES[${VINDEX}]} -lt ${DUR} ]]; then
      echo "Adjusting duration for shorter video length - ${TIMES[${VINDEX}]}s" 
      OLDUR=${DUR}
      DUR=${TIMES[${VINDEX}]}
      STARTTIME=$(($(rnum)%((${TIMES[${VINDEX}]}+1)-(${DUR}))))
   else
      # Set random start time based on duration
      STARTTIME=$(($(rnum)%((${TIMES[${VINDEX}]}+1)-${DUR})))
   fi

   # Start up video by index. Background so we can get the next video ready to play
   echo "Video/Stream [${VINDEX}] - ${VIDEOS[${VINDEX}]}"
   if [[ -v YLISTVID[${VINDEX}] ]]; then 
      echo "Playlist Video: https://www.youtube.com/watch?v=${YLISTVID[${VINDEX}]}"
   fi
   echo "Title: ${TITLES[${VINDEX}]}"
   echo "Playing ${DUR}s starting at ${STARTTIME} out of ${TIMES[${VINDEX}]}s"
   echo
   playvid ${VINDEX}

   # Reset duration if it was changed for a short video
   if [[ ${OLDUR} -gt 0 ]]; then
      echo "Setting duration back to ${OLDUR}s"
      echo
      DUR=${OLDUR}
      unset -v OLDUR
   fi
done
