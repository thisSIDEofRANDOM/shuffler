# shuffler
Cut clips of X time from a playlist of youtube/twitch/local videos. Useful for general playback or xscreensaver looping

## Usage
```
Usage:  [#] [hH] [gettitles]
 Options:
   hH		Print usage and exit
   gettitles	Anywhere in arg this will print titles/descriptions and exit
 
   #		Arg one as number of seconds to play before moving to next clip

 Notes:
   If a clip is shorter than the duration (Default: 300s)
   The duration will be set to the length of that clip for playback
   This results in the clip being played from start to finish

   If spun up by XScreensaver, will spawn a watcher function
   This function handles freezing video playback when SIGSTOP
    is sent to base script by XScreensaver for password entry
```

## Playlists
Playlist is read from ${HOME}/.config/shuffler/playlists.
It can contain local files, youtube addresses, and twitch streams.
All paths/URLs must be fully complete I.E. https://www.youtube.com/...
See an example playlists under the examples file for more detail of a mixed file

## Requirements
Must have - mpv, youtube-dl, and od in your path for program to run

## Xscreensaver
This should work with xscreensaver as long as you have the binary added to your local path.
I.E. /usr/local/bin/shuffler

You'll need to add an entry to the ${HOME}/.xscreensaver file to allow it to show up in the select screen.
Note the example has shuffler on its own line below.
```
tail -20 ${HOME}/.xscreensaver 
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

### Verbose Example
$ shuffler 30
```
Loaded 4 videos/streams from /home/tsunamibear/.config/shuffler/playlist
Getting status/time(seconds) of /home/tsunamibear/Videos/Shark.mp4 - 992s

Video/Stream [0] - /home/tsunamibear/Videos/Shark.mp4
Title: Shark.mp4
Playing 30s starting at 755 out of 992s

Waiting to check if https://www.twitch.tv/geekandsundry is LIVE
Getting status/time(seconds) of https://www.twitch.tv/geekandsundry - LIVE

Video/Stream [2] - https://www.twitch.tv/geekandsundry
Title: Rebroadcast of Shows from the past Week! Lots of good stuff! Enjoy the weekend <3 Remember all that glitters is gold! - !rbschedule
Playing 30s starting at 0 out of 30s

Getting status/time(seconds) of https://www.youtube.com/watch?v=Ts_GKTDF_QY - 40047s

Video/Stream [3] - https://www.youtube.com/watch?v=Ts_GKTDF_QY
Title: GTA V - Full Walkthrough 【Ultra Settings 】 【NO Commentary】
Playing 30s starting at 30835 out of 40047s

Waiting to check if https://www.twitch.tv/overwatchleague is LIVE
Getting status/time(seconds) of https://www.twitch.tv/overwatchleague - ERROR: overwatchleague is offline

Video/Stream [3] - https://www.youtube.com/watch?v=Ts_GKTDF_QY
Title: GTA V - Full Walkthrough 【Ultra Settings 】 【NO Commentary】
Playing 30s starting at 29282 out of 40047s
```
