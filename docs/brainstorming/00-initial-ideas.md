# Initial Ideas

This document captures the original high-level idea for the Blackbox project before the later structured brainstorming.

## Verbatim Original Text

let me tell you a little bit of what this project is about. then you can make suggestions, ask for clarifications, etc. At this stage we are brainstorming not making plans yet.

So the idea is to have an app that functions is the blackbox of my life (like a blackbox in an airplane). It constantly captures my location and anything that can be captured from all the sensores of my iphone and apple watch and potentially from my health app and whatever else we come up with in the future.

I intend for the data to live in the cloud. On one hand, I want to keep a full history of my data, on the otherhand, I don't want to save more than makes sense because it could get expensive and useless at the same time.

I wan't the iphone app to collect all the data, clense it and upload it to the cloud in an efficient manner that takes into account my network connectivity status, cloud platform costs (storage, bandwidth, etc). Need to make smart traeoffs.

I also want the iphone app to have the UI to interact with the data. View it in meaningfull ways, edit the data where makes sense, etc.

For example, I want the blackbox to track and keep my location, travel path, speed, elevation, etc. I want it to recognize when I'm running, hicking, traveling by vehicle (can it tell if I am driving?), etc. can it deduce that I'm swiming? rawing? On a sail or speed boat? Flying in an airliner? Once it recognizes that I'm running it should show the relevant UI. Likewise with any other type of activity.

With all GPS jamming these days (and also when driving through a tunnel, for example), the app should be smart enough, using some huristics and data from the rest of the sensors, to realise that the data is bad and ignore it or, if ambiguous, flag it for me so I can decide 
In the future, I will likely want to implement a web UI for the collected data as well as an adroid version. Also, support other input sources such as Garmin or other smart watches.

## Cleaned-Up Restatement

The idea is to have an app that functions as the black box of my life, similar in spirit to a black box in an airplane.

It should constantly capture:
- location
- anything that can be captured from the sensors of my iPhone
- anything that can be captured from my Apple Watch
- potentially data from my Health app
- other data sources we may come up with in the future

The data should live in the cloud.

There is a tension between:
- keeping a full history of the data
- not saving more than makes sense, because storing too much may become both expensive and useless

The iPhone app should:
- collect the data
- cleanse it
- upload it to the cloud efficiently
- take into account network connectivity status
- take into account cloud platform costs such as storage and bandwidth
- make smart tradeoffs

The iPhone app should also provide the UI to interact with the data:
- view it in meaningful ways
- edit the data where it makes sense

Examples of things the app should track and infer:
- location
- travel path
- speed
- elevation
- whether I am running
- whether I am hiking
- whether I am traveling by vehicle
- whether I am driving
- whether I am swimming
- whether I am rowing
- whether I am on a sail boat
- whether I am on a speed boat
- whether I am flying in an airliner

Once it recognizes that I am engaged in a given activity, it should show relevant UI for that activity. The same idea applies to any other detected activity.

The app should also be smart about bad data.

Examples:
- GPS jamming
- tunnels while driving
- ambiguous or conflicting data from different sensors

It should:
- realize when data is bad
- ignore bad data when appropriate
- flag ambiguous situations for me to review when needed

Possible future directions:
- a web UI for the collected data
- an Android version
- support for additional input sources such as Garmin or other smart watches

## Notes

This document is intentionally simple and close to the original idea. The more developed thinking now lives in the separate brainstorming documents.
