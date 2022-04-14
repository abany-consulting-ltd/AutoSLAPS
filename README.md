
# Serverless LAPS (SLAPS)

Serverless LAPS for deployment via Intune, to randomise Local Administrator passwords on a 3 month cycle and store all passwords in your Azure Vault.

## Description

The original work for these scripts are from https://github.com/jseerden/SLAPS, so full credit goes to J Seerden for the base scripts on which this project is being built upon.

## Getting Started

### Dependencies

* Intune enrolled devices for target endpoints
* The content of the Microsoft Win32 Content Prep Tool (https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)

### Installing

* How/where to download your program
* Any modifications needed to be made to files/folders

### Executing program

Changes to the process are as follows:

* A seperated installer file (SLAPS-Install.ps1), which does the following:
    - Creates an install directory of C:\ProgramData\Microsoft\SLAPS, and copies across the 'New-LocalAdmin.ps1' and 'schtask.bat' files into this directory.

* Creates a Scheduled Task from the 'schtask.bat' file, to run every 3 months under the SYSTEM context. The task runs initially on first install.

* The Scheduled Task targets the 'New-LocalAdmin.ps1' script, which does the following:
    - Checks for the presence of the specified Local Administrator account (the name set within the script under the $userName variable)
    - If not found it will create and add to the Local Administrator group




```
code blocks for commands
```

## Help

Any advise for common problems or issues.
```
command to run if program contains helper info
```

## Authors

John Seerden  
[@jseerden](https://twitter.com/jseerden)

Mark Kinsey
[@MarkDKinsey](https://twitter.com/MarkDKinsey)

## Version History

* 0.2
    * Various bug fixes and optimizations
    * See [commit change]() or See [release history]()
* 0.1
    * Initial Release

## License

This project is licensed under the [NAME HERE] License - see the LICENSE.md file for details

## Acknowledgments

Inspiration, code snippets, etc.
* [awesome-readme](https://github.com/matiassingers/awesome-readme)
* [PurpleBooth](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2)
* [dbader](https://github.com/dbader/readme-template)
* [zenorocha](https://gist.github.com/zenorocha/4526327)
* [fvcproductions](https://gist.github.com/fvcproductions/1bfc2d4aecb01a834b46)