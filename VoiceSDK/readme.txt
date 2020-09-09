Please copy libs/VoiceSdk.framework and the contents of init_data folder from the IDVoice + IDLive iOS package received from ID R&D to the VoiceSDK/ folder in order to be able to build and run the application. 

Contents of this folder by default should be the following:
- “antispoof2” folder (copy from /init_data folder in SDK package)
- “media” folder (copy from /init_data folder in SDK package)
- “verify” folder (copy from /init_data folder in SDK package)
- VoiceSdk.framework  (copy from /libs folder in SDK package)

You can see/modify Initialization paths in Globals.swift file.
