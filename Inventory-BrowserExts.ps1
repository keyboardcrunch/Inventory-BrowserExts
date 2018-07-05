<#
    .SYNOPSIS
        Runs a threaded survey of installed browser extensions for Firefox and Chrome.

    .DESCRIPTION
        InventoryBrowserExts will search all profiles and users for browsers with extensions installed and output that data to a csv.

    .PARAMETER Computername
        The target or targets to be surveyed.

    .PARAMETER Throttle
        The number of jobs for the survey to use. 10 is default.

    .PARAMETER DataDir
        The path for all saved data to be written. Defaults to .\ if left empty.

    .PARAMETER Browser
        The browser/s to target. Options are Firefox, Chrome or All.

    .EXAMPLE
        Inventory-BrowserExts -Computername $(Get-Content .\Data\BrowserInstalled.txt) -Browser Chrome -Throttle 25

        Description
        -----------
        Runs a survey of extensions installed in Google Chrome on all machines listed within BrowserInstalled.txt using job throttle 
        for the scan. Data is saved to C:\Inventory-BrowserExts\BrowserExtensions.csv

    .EXAMPLE
        Inventory-BrowserExts -Computername $(Get-Content .\Data\BrowserInstalled.txt) -DataDir "\\NetworkShare\Extensions\"

        Description
        -----------
        Runs a survey of extensions installed for both Firefox and Chrome on all machines within BrowserInstalled.txt 
        and saving data to \\NetworkShare\Extensions\BrowserExtensions.csv. Default 10 threads.
    
    .NOTES
        File Name: Inventory-BrowserExts.ps1
        Author: keyboardcrunch
        Date Created: 23/06/18
#>

Param (
    [Alias('IPAddress','Server')]
    [PSObject]$Computername = $Env:Computername,
    [Int]$Throttle = 10,
    [String]$DataDir = ".\",
    [ValidateSet('Firefox','Chrome','All')]
    [String]$Browser = "All"
)

# Variables and setup
$Archive = $(Join-Path $DataDir -ChildPath $("InventoryBrowserExts-$(Get-Date -Format MM.dd.yy)"))
New-Item -ItemType Directory -Path $Archive -Force | Out-Null
$ExtensionInventory = [System.IO.Path]::Combine($Archive, "BrowserExtensions.csv")

# Inventory script to be invoked
$InventoryScript = {
    Param (
        [ValidateSet('Firefox','Chrome','All')]
        [String]$Browser = "All"
    )

    $ExtensionList = @()
    $Computer = $($env:COMPUTERNAME)

    Function FirefoxSurvey {
        $ExtensionList = @()
        $SkipFolders = ("Public", "Default")
        $SkipExtensions = @(
            "Pocket",
            "Web Compat",
            "Default",
            "Activity Stream",
            "Application Update Service Helper",
            "Follow-on Search Telemetry",
            "Photon onboarding",
            "Form Autofill",
            "Firefox Screenshots"
        )
        $UserFolders = Get-ChildItem -Path "C:\Users\" -Exclude $SkipFolders
        ForEach ($User in $UserFolders) {
            $ExtFiles = Get-ChildItem -Path "$($User)\AppData\Roaming\Mozilla\Firefox\Profiles" -Recurse -Filter extensions.json -Force -ErrorAction SilentlyContinue
            ForEach ($ExtFile in $ExtFiles) {
                Try {
                    $ExtJson = Get-Content $ExtFile.FullName | ConvertFrom-Json | Select-Object addons
                    $Exts = $ExtJson.addons | Select-Object defaultLocale | Select-Object -ExpandProperty defaultLocale | Select-Object Name
                    ForEach ($Ext in $Exts) {
                        If (-Not($SkipExtensions -contains $Ext.Name)) {
                            $newRow = [PSCustomObject] @{
                                Computer = $Computer
                                User = $($User.Name)
                                Browser = "Firefox"
                                Extension = $($Ext.Name)
                                ExtString = "---"
                            }
                            $ExtensionList += $newRow
                        }
                    }
                } Catch {
                    <# Excluding this as it dirties the data
                    $newRow = [PSCustomObject] @{
                        Computer = $Computer
                        User = $($User.Name)
                        Browser = "Firefox"
                        Extension = "ERROR"
                        ExtString = "---"
                    }
                    $ExtensionList += $newRow
                    #>
                }
            }
        }
        Return $ExtensionList
    }

    Function ChromeSurvey {
        $ExtensionList = @()
        $SkipFolders = ("Public", "Default")
        $SkipExtensions = @(
            "apdfllckaahabafndbhieahigkjlhalf",
            "blpcfgokakmgnkcojhhkbfbldkacnbeo",
            "nmmhkkegccagdldgiimedpiccmgmieda",
            "pjkljhegncpnkpknbcohdijeoejaedia",
            "pkedcjkdefgpdelpbcmbmeomcjbeemfm", # Chrome Media Router
            "aapocclcgogkmnckokdopfmhonfmgoek",
            "aohghmighlieiainnegkcijnfilokake",
            "felcaaldnbdncclmgdcncolpebgiejap",
            "ghbmnnjooekpmoecnnnilnnbdlolhkhi",
            "jjkchpdmjjdmalgembblgafllbpcjlei", # McAfee Endpoint Security Web Control
            "hddjhjcbioambdhjejhdlobijkdnbggp"  # McAfee DLP Endpoint Chrome Extension
        )
        $UserFolders = Get-ChildItem -Path "C:\Users\" -Exclude $SkipFolders
        ForEach ($User in $UserFolders) {
            $Manifests = Get-ChildItem -Path "$($User)\AppData\Local\Google\Chrome\User Data\Default\Extensions" -Recurse -Exclude $SkipExtensions -Filter Manifest.json -Force -ErrorAction SilentlyContinue
            ForEach ($Manifest in $Manifests) {
                $ExtString = $Manifest.FullName -Split "\\"
                $ExtString = $ExtString[-3]
                Try {
                    $ExtData = Get-Content $Manifest.FullName | ConvertFrom-Json | Select-Object Name, Version
                    If (-Not($ExtData.Name -like "__MSG_*" -or $SkipExtensions -contains $ExtString)) {
                        $newRow = [PSCustomObject] @{
                            Computer = $Computer
                            User = $($User.Name)
                            Browser = "Chrome"
                            Extension = $($ExtData.Name)
                            ExtString = $ExtString
                        }
                        $ExtensionList += $newRow
                    }
                } Catch {
                    $newRow = [PSCustomObject] @{
                        Computer = $Computer
                        User = $($User.Name)
                        Browser = "Chrome"
                        Extension = "NAME_RESOLUTION_ERROR"
                        ExtString = $ExtString
                    }
                    $ExtensionList += $newRow
                }
            }
        }
        Return $ExtensionList
    }

    Switch ($Browser) {
        "Firefox" { $ExtensionList += FirefoxSurvey }
        "Chrome" { $ExtensionList += ChromeSurvey }
        default { 
            $ExtensionList += FirefoxSurvey
            $ExtensionList += ChromeSurvey
        }
    }
    Return $ExtensionList | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
}

Write-Host "Running inventory on $($Computername.Count) machines..." -ForegroundColor Yellow
$Inventory = Invoke-Command -ComputerName $Computername -ScriptBlock $InventoryScript -ArgumentList $Browser -ThrottleLimit $Throttle -ErrorAction SilentlyContinue
$Inventory | ConvertFrom-Csv | Export-Csv $ExtensionInventory -NoClobber -NoTypeInformation -Force -Append

Write-Host "Analyzing data..." -ForegroundColor Yellow
$Inventory = $Inventory | Convertfrom-csv -Header computer, user, browser, extension, extstring
Write-Host "`nDevice Count:`t`t$($($Inventory.computer | Sort-Object -Unique).count)"
Write-Host "`nUser Accounts:`t`t$($($Inventory.user | Sort-Object -Unique).count)"
Write-Host "`nExtension Count:`t$($($Inventory.extension | Sort-Object -Unique).count)"
Write-Host "`nExtension Breakdown:"
$Inventory | Group-Object -Property extension | Select-Object Name, Count | Sort-Object Count -Descending