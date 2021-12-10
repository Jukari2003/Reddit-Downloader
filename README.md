# Reddit-Downloader
Download Reddit Media

![alt text](https://github.com/Jukari2003/Reddit-Downloader/blob/main/Preview.png?raw=true)

    Usage Instructions:
        - Download Reddit-Downloader.zip from GitHub
            - Top Right Hand Corner Click "Code"
            - Select "Download Zip"
        - Extract Files to a desired location
        - Right Click on RD.ps1
        - Click "Edit"     (This should open up Reddit Downloader in Powershell ISE)
        - Once PowerShell ISE is opened. Click the Green Play Arrow.
        - Success!


----------------
	Program Features:

- Downloads Reddit Images
- Downloads Reddit Videos
- Prevents Duplicate Images/Videos via hash
- Prevents Duplicate requests to the same URL

---------------------

    Possible Errors:
        - Execution-Policy 
            - Some systems may prevent you from executing the script even in PowerShell ISE.
                -   On a Government machine: You're pretty much SOL unless you have admin rights.
                -   On a Home Computer: Run PowerShell ISE or PowerShell as an administrator
                    - Type the command:
                         -  Set-ExecutionPolicy Unrestricted
                    - Type 
                        -  Y
  
        - You're on a MAC
            - You will need to install PowerShell for MAC
                - https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7.1
