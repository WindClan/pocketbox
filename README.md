# pocketbox v4 - network music player

pocketbox v4 is a complete rewrite of pocketbox to fix 3 years worth of bugs. It serves the same purpose but has a different setup than v3 and before. v3 playlists can easily be adapted to v4.

# Usage

Instead of a janky UI, pocketbox's system has been simplified into 3 controls

## Launching

Launching pocketbox with no files and no arguments will result in an error. To fix this, either make a playlist file or launch with the command line arguments

pocketbox has two command line options, both optional.

- `path`: the path of the custom playlist location you want to play
- `shuffle`: should the custom playlist apply. defaults to true when a custom path is specified, depends on the file name otherwise

## Controls

Click any mouse button on the terminal to pause/unpause, and press any key to skip songs.

## Auto-Play Playlists

pocketbox has two default "autoplay" playlist files, `autoplay.pd` and `autoshuffle.pd`. As the names suggest, `autoshuffle` is shuffled and `autoplay` is played in order. This can be overridden with the command line arguments.


## Playlist format

```
[gdrive]
path:GDRIVESHARELINK
title:Beach Life-In-Death
artist:Car Seat Headrest

[url]
path:https://example.com/stopsmoking.dfpwm96
dfpwm96:true
title:Stop Smoking
artist:Car Seat Headrest
```

- `[HEADER]`: Either `url` or `gdrive`, `gdrive` is for google drive share links and `url` is for web urls
- `path`: the link to the song, has to be either a dfpwm file or a google drive share link.
- `dfpwm96`: whether the song is 96khz (or stereo 48khz), unless you know what you are doing you shouldn't use this.
- `title`: Song title
- `artist`: Song artist

An example playlist is provided in `autoplay.pd` in the github repo.