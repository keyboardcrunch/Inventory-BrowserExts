# Inventory-BrowserExts
Script to inventory Firefox and Chrome extensions, quickly.

![Inventory-BrowserExts](https://github.com/keyboardcrunch/Inventory-BrowserExts/blob/master/ExtensionInventory.jpg)

## What Do?
This script can inventory Firefox and/or Chrome extensions for each user from a list of machines. It returns all the information back in a csv file and prints to console a breakdown of that information.

## Usage
Inventory-BrowserExts -Computername $(Get-Content .\MachineList.txt) -DataDir "\\soc.corp.com\audit\" -Throttle 45 -Browser Chrome
