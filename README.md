# betterfox-updater-windows
I made a Betterfox Updater and prefsCleaner for windows, just drop **`Updater.bat`** & **`prefsCleaner.ps1`** & **`user-overrides.js`**
 into the firefox profiles folder and execute **`Updater.bat`**, download link at the bottom.

<img width="396" height="331" alt="Image" src="https://github.com/user-attachments/assets/11bbc5b1-f324-40d7-b94c-cf8966a95535" />

#### Why prefsCleaner?
When you update `user.js` to a new version, obsolete and deleted* entries from the previous version may still be present in `prefs.js`.
To remedy this, `Updater.bat` runs a cleaning routine that removes entries from `prefs.js` defined in the old `user.js`, giving you a clean slate. (Same approach as [arkenfox](https://github.com/arkenfox/user.js/blob/fb56d7bb4ed07898c9d94ca7ecc89697dd88cc3c/prefsCleaner.bat#L22).)
When `Updater.bat` is executed, it first cleans `prefs.js`, then downloads the latest version of `user.js` and appends `user-overrides.js` to the end of the file.
Backup copies are made of both `prefs.js` & `user.js`
Make sure <ins>**firefox is not running!**</ins> when using the updater.
*<sub>Example pref that wouldn't be deleted when upgrading from version 152 to 154 without a prefsClean , ([Line 28](https://github.com/yokoffing/Betterfox/blob/8e415d1633f10fe0192d9c938e4ca2628eeec9f9/user.js#L28) in version 152)</sub>

### Steps
1. Open the firefox profiles folder and <ins>**close firefox**</ins>
2. Copy `Updater.bat` & `prefsCleaner.ps1` & `user-overrides.js`*  into the folder and run `Updater.bat`  
3. Restart firefox, that's it!
*<sub>**user-overrides.js** is mandatory, update routine will not work without it, Add your user_pref's of choice to it</sub>

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&pause=1000&width=435&lines=Updated+version+below!)]()
Download: [prefsCleaner-v4.zip](https://github.com/user-attachments/files/33309185/prefsCleaner-v4.zip) 5 KB

<em>You can create a desktop shortcut to run it if you want, it should be in this format:
(adjust for your path)
Target: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\winuser\AppData\Roaming\Mozilla\Firefox\Profiles\wgigyenw.Safe Profile\prefsCleaner.ps1"` 

Start in: `"C:\Users\winuser\AppData\Roaming\Mozilla\Firefox\Profiles\wgigyenw.Safe Profile"`
you can then add a nice icon from `%SystemRoot%\System32\imageres.dll`</em> 😉

<p align="center">
  <img width="94" height="101" src="https://github.com/user-attachments/assets/2d530280-ce05-4ca3-87e4-6172b68e326e">
</p>
To be notified* when there's a new Betterfox release, create an account here: 

[newreleases.io](https://newreleases.io/) this service is free.
*<sub>Supports notification by: Email, Slack, Telegram, Discord, Hangouts Chat, Microsoft Teams, Mattermost, Rocket.Chat, Matrix, Webhooks</sub>


<img width="1200" height="60" alt="Image" src="https://github.com/user-attachments/assets/0b0bd39e-ef6a-4040-b8e7-edd0d4764f06" />


