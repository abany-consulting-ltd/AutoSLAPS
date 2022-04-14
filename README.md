# SLAPS
Serverless LAPS for Intune Deployment

The original work for these scripts are from https://github.com/jseerden/SLAPS, so full credit goes to J Seerden for the base scripts on which this project is being built upon.

Changes to the process are as follows:

1. A seperated installer file (SLAPS-Install.ps1), which does the following:
    - Creates an install directory of C:\ProgramData\Microsoft\SLAPS, and copies across the 'New-LocalAdmin.ps1' and 'schtask.bat' files into this directory.

2. Creates a Scheduled Task from the 'schtask.bat' file, to run every 3 months under the SYSTEM context. The task runs initially on first install.

3. The Scheduled Task targets the 'New-LocalAdmin.ps1' script, which does the following:
    - Checks for the presence of the specified Local Administrator account (the name set within the script under the $userName variable)
    - If not found it will create and add to the Local Administrator group
    - 