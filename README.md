# shuffler
Cut clips of X time from a playlist of youtube/twitch/local videos. Useful for general playback or xscreensaver looping

## Usage
```
Usage:  [#] [hH] [printstring]
 Options:
   hH		Print usage and exit
   gettitles	Anywhere in arg this will print titles/descriptions and exit
 
   #		Arg one as number of seconds to play before moving to next clip

 Notes:
   If a clip is shorter than the duration (Default: 300s)
   The duration will be set to the length of that clip for playback
   This results in the clip being played from start to finish
```

## Playlists
Playlist is read from ${HOME}/.config/shuffler/playlists.
It can contain local files, youtube addresses, and twitch streams.
All paths/URLs must be fully complete I.E. https://www.youtube.com/...
See an example playlists under the examples file for more detail of a mixed file

## Xscreensaver
This should work with xscreensaver as long as you have the binary added to your local path.
I.E. /usr/local/bin/shuffler

You'll need to add an entry to the ${HOME}/.xscreensaver file to allow it to show up in the select screen.
Note the example has shuffler on its own line below.
```
ail -20 ${HOME}/.xscreensaver 
  GL: 				cubestack -root				    \n\
  GL: 				cubetwist -root				    \n\
  GL: 				discoball -root				    \n\
  GL: 				hexstrut -root				    \n\
  GL: 				splodesic -root				    \n\
  GL: 				vigilance -root				    \n\
  GL: 				esper -root				    \n\
				shuffler					    \n\


pointerPollTime:    0:00:05
pointerHysteresis:  10
windowCreationTimeout:0:00:30
initialDelay:	0:00:00
GetViewPortIsFullOfLies:False
procInterrupts:	True
xinputExtensionDev: False
overlayStderr:	True
authWarningSlack:   20
```

### TODO 
* Clean up variables/code style
* Figure out a way to SIGSTOP the MPV fork when xscreensaver SIGSTOPS the main process loop. (Tried with an exec but only seems to respawn after ~120 seconds)
