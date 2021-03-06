<#
.SYNOPSIS

    Parses the security settings from a Group Policy XML export.

    Author: Jason Lang (@curi0usJack)
    License: BSD 3-Clause
    Required Dependencies: An Active Directory Group Policy XML export file.
    Optional Dependencies: None

.DESCRIPTION

    Invoke-GPOLinks ingests an XML file containing the group policy settings for a given domain. It
	then parses out the security settings, OU links, and enabled status to a text file.
	
	To create the XML export file, run the following PowerShell commands from a domain-joined machine
	with Remote Server Administration Tools installed:
	
	> Import-Module ActiveDirectory
	> Get-GPOReport -All -ReportType Xml -Path "gpos.xml"

.PARAMETER Path

    Specifies the path to Group Policy XML export file.

.EXAMPLE

    Invoke-GPOLinks -Path c:\gpodata.xml

    Description
    -----------
    Generates a text file containing the security settings of the various Active Directory GPOs.


.OUTPUTS

    A simple text file in the format of "GPOLinks-<DATE>.txt".
	
	The output file contains the security settings of the given GPO as well as any OU's they are linked to.
	Note that the "Link" line specifies either a "D" or an "E". "D" means that the policy is linked to that 
	OU but the link is disabled. "E" means the policy is linked to the OU and is enabled.

.LINK

    http://www.shellntel.com/
#>
param
(
	[parameter(Mandatory=$true)]
	[string]
	$Path
)

$logpath = "GPOLinks-{0}.txt" -f (Get-Date -Format yyyyMMddhhmmss)
if (Test-Path $Path)
	{ Write-Host "[*] Parsing $Path. Could take several minutes." }
else
{
	Write-Host "[!] Could not find $Path. Please verify and try again. `n"
	Write-Host "[*] Done.`n"
	return
}

$unused = @()
[xml]$gpodata = Get-Content $Path

foreach ($gpo in $gpodata.report.GPO)
{
	$name = $gpo.Name.Trim()
	
	if (($gpo.LinksTo | measure).Count -eq 0)
		{ $unused += $gpo.Name.Trim() }
	else {
		Write-Host "[*] Parsing GPO: $name"
		Add-Content $logpath "GPO Name: $name"
		$secoptions = $gpo.Computer.ExtensionData.Extension.SecurityOptions.Display
		if (($secoptions | measure).Count -gt 0)
		{
			foreach ($opt in $secoptions)
			{
				$name = $opt.Name
				if ([string]::IsNullOrEmpty($opt.Name) -eq $false)
				{
					if ([string]::IsNullOrEmpty($opt.DisplayBoolean) -eq $false)
						{ $val = $opt.DisplayBoolean }
					elseif ([string]::IsNullOrEmpty($opt.DisplayString) -eq $false)
						{ $val = $opt.DisplayString }
					elseif ([string]::IsNullOrEmpty($opt.DisplayNumber) -eq $false)
						{ $val = $opt.DisplayNumber }
					else 
						{ $val = "Unknown Display Type" }
						
					Add-Content $logpath "[SETTING]---> $name -- $val"
				}
			}
		}
		
		foreach ($link in $gpo.LinksTo) 
		{
			$ouname = $link.SOMName
			$oupath = $link.SOMPath
			$enabled = $link.Enabled
			
			if ($enabled -eq $true)
				{ $strenabled = "E" }
			else
				{ $strenabled = "D" }
			
			if ($enabled = $true)
				{ Add-Content $logpath "[LINK]-----$strenabled> $oupath" }
		}
		Add-Content $logpath "`n"
	}
}

if ($unused.Count -gt 0)
{
	Write-Host "[*] Logging unused GPOs"
	Add-Content $logpath "`nUNLINKED GPOs"
	foreach ($gpo in ($unused | sort))
		{ Add-Content $logpath ("[!] {0}" -f $gpo) }
}

Write-Host "[*] Data written to $logpath"
Write-Host "[*] Done!`n"
