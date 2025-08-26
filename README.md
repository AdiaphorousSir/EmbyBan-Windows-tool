# EmbyBan-Windows-tool
Automatically ban IP's with failed logins to Emby Server on Windows

*****   DISCLAIMER   *****

- This is my first app. I am not a professional programmer nor am I professional at making scripts.
  I created this app for fun and a simple way to block IP's. I'm sure there are better apps out there for windows but I just wanted something simple.

- I am not responsible for any damages or issues this program may cause.

- This app is not intended to secure your server. This App just manages windows firewall rules to ban IP's based on failed logins to your Emby Server.

- I cannot guarantee updates for this app.

- I cannot guarantee this app will work for you.

- No affiliation with Emby

- Downloading and/or running/installing files from the internet can be potentially dangerous for your computer's security and private information.

- Use at your own risk

*****   DISCLAIMER   *****

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The EmbyBan.ps1 file is only included if you would like to review the file and compile it yourself using PS2EXE

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

About EmbyBan:

- Tested on Windows 11 version 24H2 with Emby Server Version 4.8.11.0

- This app utilizes the windows firewall rules to automatically ban IP's based off of failed logins to Emby.

- This app runs in the system tray when launched.

- The auto-ban function runs every 5 minutes.

- This app must be ran as administrator to access windows firewall rules


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Setup:

 WINDOWS POWERSHELL is REQUIRED to be installed on your system for this app to run as it's just a Powershell script bundled into an executable wrapper through PS2EXE
( Visit Microsoft's website to acquire Windows Powershell: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5 )


1. Create a directory where you would like to keep EmbyBan and the banlist file
   ( Example: C:\EmbyBan)


2. Copy EmbyBan.exe to created directory
   ( Example: C:\EmbyBan )
   (For automatic startup when windows boots, copy EmbyBan.exe to C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup)

3. Run EmbyBan.exe as Administrator

4. Right click on EmbyBan in the system tray and select settings.

5. Emby Loge File: Select path to embyserver.txt log file
  ( Usually stored in C:\Users\<**YOURUSER**>\AppData\Roaming\Emby-Server\programdata\logs\embyserver.txt )

6. Banlist Folder: Select path of created directory
   ( Example: C:\EmbyBan )

7. Max Failures: Enter your preferred value for max attempts of failed logins before a ban is initiated

8. Default Ban Time (seconds) : Enter the desired amount of time (seconds) you would like the IP banned for

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

System Tray Menu:

- Run AutoBan Now: Manually runs IP ban function without waiting for the 5 minute ban cycle

- Manage Bans: Shows current IP bans, allows you to manually add or remove IPs, and displays the remaining ban time for each IP. Expired IP's are automatically removed after 1 minute.

- Settings: For setup steps above

- Exit: Closes EmbyBan

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
