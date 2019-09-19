# LiveNoiseFilter
A script to actively perform noise reduction on audio streams in Linux

The goal of this script is to allow for microphone inputs to have noise reduction applied to the audio in real time. Unlike noise supression filters, which typically apply things like high-pass filters and the like, this imitates the Noise Reduction effect in Audacity. Here, a sample of background noise is first recorded, and used as a profile to actively cancel noise. This allows for more accurate noise cancellation. Unlike Audacity, this is applied to the audio stream, and in real time, utilizing SoX.

This only has the following dependencies:
* Pulseaudio
* Alsa (for loopback devices)
* SoX (Sound eXchange)

Executing the script performs the following:

1. Check for alsa loopback kernel module. If it is not loaded, it will prompt to load it.
2. Identify the audio devices. If a single device is identified for the source (e.g. microphone) and sink (alsa loopback), these are selected by default. If multiple devicse are identified, the user may select.
3. Record a background noise sample. The user is prompted to re-record the sample if needed.
4. Apply noise cancellation to the input audio stream. This is done until the script is terminated.
