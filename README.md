iOS IDVoice sample application overview
===========================================

**The application code is compatible with VoiceSDK 3.0. See tag 'v2.14' for VoiceSDK 2.13 and 2.14 support**

This sample application is intended to demonstrate the VoiceSDK voice verification 
and anti-spoofing capabilities:

* It provides a simple text-dependent enrollment and voice verification scenario: user enrolls with three entries of their voice to create a strong voiceprint. Then they can use the created voiceprint for voice verification. By enrolling for the second time user overwrites their voiceprint.

* It provides simple text-independent enrollment and verification scenario: user enrolls with 10 seconds of their speech to create a strong voiceprint. By enrolling for the second time user overwrites their voiceprint.

* It provides text-independent continuous verification scenario without anti-spoofing check.

* It implements simple logging for voice verification results and anti-spoofing checks along with audio records. Collected logs can be sent via email or instant messaging app.

The application also demonstrates the way to validate user audio input by performing speech endpoint detection and estimating net speech length.

**All source code contains commentary that should help developers.**

Tips for voice verification process
-----------------------------------

- **Do enrolls in quiet conditions. Speak clearly and without changing the intonation of your usual voice.**

Please refer to [IDVoice quick start guide](https://docs.idrnd.net/voice/#idvoice-speaker-verification), [IDLive quick start guide](https://docs.idrnd.net/voice/#idlive-voice-anti-spoofing) and [signal validation guide](https://docs.idrnd.net/voice/#signal-validation-utilities) in order to get more detailed information and best practicies for the listed capabilities.

Developer tips
--------------

- This repository does not contain VoiceSDK distribution itself. Please copy libs/VoiceSdk.framework and the contents of init_data folder from the IDVoice + IDLive iOS package received from ID R&D to the VoiceSDK/ folder in order to be able to build and run the application. You can see/modify Initialization paths in `Globals.swift`  file.
- See `EnginesManager.swift`  and `AppDelegate.swift` for verification and speech summary engines initialization code
- See `AudioRecorder.swift` for voice recording with speech analysis code
- See `EnrollmentVC.swift` for voice template creation code and singal-to-noise ratio (SNR) computation code
- See `VerificationVC.swift` for voice templates matching code

