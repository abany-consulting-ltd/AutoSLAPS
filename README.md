
# AutoSLAPS (Automated Serverless Local Administrator Password Solution)

Au automated Serverless LAPS for deployment via Intune, to randomise Local Administrator passwords on a 90 day cycle and store all passwords in your Azure Vault.

<br>

## Description

The original work for these scripts are from https://github.com/jseerden/SLAPS, so full credit goes to J Seerden for the base scripts on which this project is being built upon.

This project builds on the base scripts adding password rotation, and end-to-end automation for the creation of the required Azure Function and Azure Vault, all required access policies for the Vault (read/modify access for the function and a read only AzureAD group for IT access), and full packaging and deployment into Intune.

<br>

## Requirements

* An Azure subscription along with Intune licensing
* A pre-configured Azure Storage blob.
* 'Az', 'AzureAD' and 'IntuneWin32App' modules pre-installed on the computer where the install shall be run. (not essential as the scripts will check and download/import if necessary, but nice to pre-prepare for a more streamlined install)

<br>

## Installation

* Download repo contents and unzip to a computer which has the modules installed as per requirements.
* In the same directory, create a new file called ‘variables.json’ and copy across the following contents:

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

* Apply attributes to the JSON file to suite your requirements. <b>NO NOT EDIT THE ‘TEST_DATA’ LINE</b>
* From an elevated PS window, execute the .\Deploy-ASLAPS.ps1 file.

<br>

## Testing

When the installation is completed, it should have created an Azure Function, and Azure Vault, and an Intune Win32 application called AutoSLAPS.

The first thing to test is the Azure Function, ensuring it is writing to the Vault:

* Within Azure, search for 'Function App', and ensure that the function is present with the name specified in the 'variables.json' file ("Azure_Function_Name":)
* Click into the function, and click 'Functions' in the left hand pane.
* Click into the 'Set-KeyVaultSecret' function
* On the left, click 'Code + Test'
* If all has gone well, the PS1 script should now be visible as a 'run.PS1' file. Ensure line 8 contains the name of your Azure Vault.
* Above the script, click 'Test/Run'
* In the right-hand pane there should now be a test PC called 'TESTPC001' with a test username of 'local.admin'. Click 'Run' to test.

```
{
        "keyName": "TESTPC001",
        "contentType": "Local Administrator Credentials",
        "tags": {
            "Username": "local.admin"
        }
    }
```

<br>

Now let's check the Vault to ensure that the password has been stored ok.

* Within Azure, search for Key Vaults
* Click into the Vault
* On the left, click 'Secrets'
* If the function is working properly, there should now be an entry for 'TESTPC001'
* Click into it, and then click into the current version entry
* Click 'Show Secret Value' to view the password.

<br>

Once the Azure compontents have been tested as working, you can now test the Intune application.

* Within Intune/AzureAD, create a device security group for testing purposes, and add an Intune enrolled device to test the deployment.
* Within Intune, click 'Apps', and then click 'Windows' from the left hand menu
* Find and click into 'AutoSLAPS'
* Click 'Properties' on the left, and scroll down to 'Assignments' and click 'Edit'
* Under 'Required', click 'Add group'
* Search for your newly created test group, and click select the group.
* Click 'Review + save' to apply the permissions.

<br>

Once this is done, head over to the Intune enrolled device where you shall be deploying the application to. Open 'Services', and restart the 'IntuneManagementExtension' service. This will force the IME agent to check into Intune for changes.

<br>

The application install does the following:

* Copies the PS1 script that communicates with the Azure Function into 'C:\ProgramData\Microsoft\ASLAPS'
* Adds additional files into this directory also for Intune detection
* Creates a Scheduled Task called 'ASLAPS Password Reset'. This is for the password rotation schedule.
* Creates the local admin account
* Initiates an initial run of the Scheduled Task on install

<br>

Once the install is complete, the initial Scheduled Task run will execute 'C:\ProgramData\Microsoft\ASLAPS\ASLAPS-Rotate.ps1', which in turn will communicate with the Azure Function to retrieve a password. This will then be set against the local admin account, as well as being stored in the Vault.

To test, head over to your Azure Vault, retrieve the password for the Intune device, and then open a program on the Intune device using the admin credentials (run as another user). 

<br>

## Troubleshooting

Each script will produce a transcript file of <i>scriptname</i>.log within the 'C:\Windows\Temp' directory of the computer where the script is executed.
   
<br>

## Features being worked on pending release

* Web portal for password retrieval
* Auditing into Log Analytics workspace

<br>

## Acknowledgments

Base scripts and code snippets
* [J Seerden](https://github.com/jseerden/SLAPS)
* [Oliver Kieselbach](https://gist.github.com/okieselbach/4f11ba37a6848e08e8f82d9f2ffff516)
* [Nickolaj Andersen](https://github.com/MSEndpointMgr/IntuneWin32App)




