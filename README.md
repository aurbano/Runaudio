# Runaudio

iOS app that will play music at the BPM you're currently walking/running


## What?

So I was running on a treadmill and pretty randomly a song played that matched my stepping rythm.
It made me realise how **awesome** it feels to be able to run exactly to a song's beat!

This is exactly what [RockMyRun](https://apps.apple.com/gb/app/rockmyrun-workout-music/id546417608) does, but I just wanted to learn how to do it myself :)

## How

There are two separate components to this: detecting the rythm you're running at (steps per minute), and then playing songs that match that.

### Stepping BPM detection

This seemed like it'd be really easy, but it's actually not! (like so many things in programming I suppose). But at least the idea is easy:

1. Get the data from the accelerometers, as frequently as possible (which is around 100Hz on an iPhone)
1. Combine it so there's one main signal to track
1. Analyse the signal to detect the steps
1. Time each step to calculate steps per minute.

I started with a very basic app that would combine the accelerometer data, then remove the moving average from the signal, to have it centered around 0. And finally find peaks to decide what the threshold should be when finding steps.

Here is a screenshot of the app with a chart with that data, and the calculated BPM in the middle:

> <img src="https://raw.githubusercontent.com/aurbano/Runaudio/master/Runaudio/assets/runaudio-screen.png" width="250" />

### Playing songs in that BPM

This part is fairly trivial, use an online database of songs that allows searching by BPM: [Tunebat](https://tunebat.com/Advanced), then play them using the Spotify API.
