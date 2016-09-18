# MDTDownloader
PowerShell script that automatically installs and configures an MDT deployment share and imports common packages.

The original intent for this script was brought upon when I was bouncing around to different clients during my
consulting years. I was constantly setting up multiple MDT Deployment Shares and creating image factories for
OSD.

Specifically what this script does is download all of the "download artifacts" listed in the PSD1 file and then
determine if MDT is installed or not as well as the ADK. If those are not installed then it will install them
and then create deployment share. It will create a basic hierarcy for applications within the deployment share.

Additional ideas for features and functions are welcome!