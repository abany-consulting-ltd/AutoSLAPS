
# AutoSLAPS

Au automated Serverless LAPS for deployment via Intune, to randomise Local Administrator passwords on a 3 month cycle and store all passwords in your Azure Vault.

## Description

The original work for these scripts are from https://github.com/jseerden/SLAPS, so full credit goes to J Seerden for the base scripts on which this project is being built upon.

This project builds on the base scripts adding password rotation, and end-to-end automation for the creation of the required Azure Function and Azure Vault, all required access policies for the Vault (read/modify access for the function and a read only AzureAD group for IT access), and full packaging and deployment into Intune.


## Requirements

* An Azure subscription along with Intune licensing
* A pre-configured Azure Storage blob.


### Installation

* Download repo contents and unzip to a computer which has the modules installed as per requirements.
* In the same directory, create a new file called ‘variables.JSON’ and copy across the following contents:

```
{
    "Azure_Username": "",
    "Azure_Password": "",
    
    "Azure_Tenent_ID":  "",
    "Azure_Subscription_ID":  "",

    "Azure_Vault_Name":  "",
    "Azure_Vault_ResourceGroup":  "",
    "Azure_Vault_Location":  "",

    "Azure_Function_Name":  "",
    "Azure_Function_ResourceGroup":  "",
    "Azure_Function_Location":  "",

    "Azure_Storage_Name":  "",

    "Local_Admin_UserName": "",
    "Password_Char_Length": "",

    "Intune_App_Version": "1.0.0",

    "Test_Data": "{\"method\":\"post\",\"queryStringParams\":[],\"headers\":[],\"body\":\"{\\n        \\\"keyName\\\": \\\"TESTPC001\\\",\\n        \\\"contentType\\\": \\\"Local Administrator Credentials\\\",\\n        \\\"tags\\\": {\\n            \\\"Username\\\": \\\"local.admin\\\"\\n        }\\n    }\\n\"}"


}

```

* Apply required attributes to the JSON file to suite your requirements. NO NOT EDIT THE ‘TEST_DATA’ LINE. (also do not edit any other variables within any other script. The ‘variables.JSON’ file controls everything)
* From an elevated PS window, execute the Deploy-ASLAPS.ps1 file.


### Testing

When the installation is completed, it should have created an Azure Function, and Azure Vault, and an Intune Win32 application called AutoSLAPS.

The first thing to test is the Azure Function, ensuring it is writing to the Vault:

* Within Azure, search for Function App, and ensure that the function is present with the name specified in the variables.json ("Azure_Function_Name":)
* Click into the function, and click 'Functions' in the left hand pane.
* Click into the 'Set-KeyVaultSecret' function
* On the left, click 'Code + Test'
* If all has gone well, the PS1 script should now be visible as a 'run.PS1' file. Ensure line 8 contains the name of your Azure Vault.
* Above the script, click 'Test/Run'
* In the right-hand pane, there should now be a test PC, with a test username of 'local.admin'. Click 'Run' to test.

Now let's check the Vault to ensure that the password has been stored ok.

* Within Azure, search for Key Vaults
* Click into the Vault
* On the left, click 'Secrets'
* If the function is working properly, there should now be an entry for 'TESTPC001'
* Click into it, and then click into the current version entry
* Click 'Show Secret Value' to view the password.

Once the Azure compontents have been tested as working, you can now test the Intune application.

* Within Intune/AzureAD, create a device security group for testing purposes, and add an Intune enrolled device to test the deployment.
* Within Intune, click 'Apps', and then click 'Windows' from the left hand menu
* Find and click into 'AutoSLAPS'
* Click 'Properties' on the left, and scroll down to 'Assignments' and click 'Edit'
* Under 'Required', click 'Add group'
* Search for your newly created test group, and click select the group.
* Click 'Review + save' to apply the permissions.

Once this is done, head over to the Intune enrolled device where you shall be deploying the application to. Open 'Services', and restart the 'IntuneManagementExtension' service. This will force the IME agent to check into Intune for changes.




* A seperated installer file (SLAPS-Install.ps1), which does the following:
    - Creates an install directory of C:\ProgramData\Microsoft\SLAPS, and copies across the 'New-LocalAdmin.ps1' and 'schtask.bat' files into this directory.

* Creates a Scheduled Task from the 'schtask.bat' file, to run every 3 months under the SYSTEM context. The task runs initially on first install.

* The Scheduled Task targets the 'New-LocalAdmin.ps1' script, which does the following:
    - Checks for the presence of the specified Local Administrator account (the name set within the script under the $userName variable)
    - If not found it will create and add to the Local Administrator group




