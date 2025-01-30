<#

WUOffline (Windows Update Offline) module for PowerShell

Not to be confused with "WSUS Offline Update" (WOU), which is an unrelated
project with similar overall goals, but intended to solve different problems.

Since the Windows Update subsystem can also provide updates for other products
(like Office or SQL), the updates this module finds, may be more than just
updates for Windows.  But they're still updates handled by Windows Update,
and are thus still Windows Updates.  Got that?

Written by Benjamin Scott
  http://www.dragonhawk.org/
Originally inspired by Scan-UpdatesOffline.ps1
  Dated 12/12/2019 
  by Andrei Stoica of Microsoft
  https://gallery.technet.microsoft.com/Using-WUA-to-Scan-for-f7e5e0be
  Retrieved 2019 JAN 15

NOTE_BOUND_PARAM_MODULE:
$PSBoundParameters.ContainsKey() acts weird in a module, outside of
the exported function itself.  So anything that depends on the actual
bound parameters has to be checked in the exported function.

NOTE_NULL_STRING_PARAM:
PoSh forces any [string] parameter to contain a string, even if not set.
PoSh will not allow anything cast as [string] to contain $null.
In either case, the empty string gets stored instead.
So if you want to distinguish between "parameter not specified" and
"parameter explicitly set to empty string", you have to check for the
existence of the parameter (not the value), and then store a special
string-null-value, which then evaluates as equal to $null.

#>

<#

LEGAL NOTICE

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to http://unlicense.org/

#>

########################################################################
# safety

# throw errors on undefined variables
Set-StrictMode -Version 1

# abort immediately on error
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

########################################################################
# constants

# https://docs.microsoft.com/en-us/windows/win32/api/wuapicommon/ne-wuapicommon-serverselection
Set-Variable -option Constant -name SearchOthers -Value 3

# UpdateServiceOption
# https://docs.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-updateserviceoption
Set-Variable -option Constant -name VolatileService -Value 0
Set-Variable -option Constant -name NonVolatileService -Value 1

# WU needs a name for the offline scan catalog "service"
Set-Variable -option Constant -name svcName -Value "WSUSSCN2_CAB"

########################################################################
# exported functions

# ----------------------------------------------------------------------
function Get-WinUpdate {
<#
.SYNOPSIS

Get-WinUpdate.  Get concise information about Windows Updates.

.DESCRIPTION

Get-WinUpdate scans for and reports on Windows Updates, installed on and/or
needed by the local computer.  It uses the Microsoft offline scan catalog,
which you must download and provide.  It outputs PowerShell objects, suitable
for piping for viewing, storage, or further processing.  The information on
needed updates includes the URL for the package to download from Microsoft.

.EXAMPLE

Get-WinUpdate C:\WinUpdate\wsusscn2.cab | Format-Table

Scan for needed updates and display the results in tabular form. No
progress information will be given.

.EXAMPLE

Get-WinUpdate -Verbose -Catalog C:\WinUpdate\wsusscn2.cab | Export-CSV -Path C:\WinUpdate\updates.CSV

Scan for needed updates, and store the results in a Comma Separated
Values (CSV) file, suitable for Excel or other programs. The -Verbose
switch means major operations will be identified as they are performed,
and a few simple statistics will be given.

.EXAMPLE

Get-WinUpdate C:\WinUpdate\wsusscn2.cab -Exclude 890830 | % { $_.Links -split " " } > urls.txt

Scan for needed updates, and store the URLs that need to be downloaded
into a text file. Exclude update 890830 (the Malicious Software Removal
Tool included every month). The URL list can then be given to downloader
programs such as WGET, CURL, GetRight, etc.

.EXAMPLE

Get-WinUpdate -All C:\WinUpdate\wsusscn2.cab | Out-GridView

Scan and report all updates installed on the machine, as well as any
needed.  Display the results in an interactive GUI table.

.PARAMETER Catalog

Full path and file name of Windows Update offline scan catalog.
Typically named WSUSSCN2.CAB and obtained from the
http://go.microsoft.com/fwlink/?LinkId=76054 redirector.

.PARAMETER Installed

Instead of searching for Windows Updates that are needed, search for
updates which are already installed. This can be used to report which
updates have been installed on the machine.

.PARAMETER All

Search for both updates which are needed, and those which are already
installed. This can be used to provide a "status report" for a machine.
If both -All and -Installed are specified, -All wins.

.PARAMETER Superseded

When searching for Windows Updates, include potentially-superseded
updates.  This is a Windows Update internal option.

.PARAMETER Include

A list of one or more strings, which are checked against the MSKB IDs of 
updates. Only updates where the MSKB ID exactly matches an include 
string are subject to further processing; the rest are omitted. If no 
-Include is specified, all updates are processed (subject to -Exclude).

If an update matches both -Include and -Exclude, it is excluded.

.PARAMETER Exclude

A list of one or more strings, which are checked against the MSKB IDs of
updates. Any update where the MSKB ID exactly matches an exclude string,
is omitted from further processing.

If an update matches both -Include and -Exclude, it is excluded.

.PARAMETER Query

Explicitly specify the query that will be given to the Windows Update
engine for the update search.  Overrides -All or -Installed, but not 
-Include or -Exclude (the former influence the query given to WU; the 
latter are applied to the results from the WU search).

For query syntax, see: https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdatesearcher-search

.PARAMETER ShowDebug

Shortcut to setting DebugPreference=Continue for this script run.  Tons of
debugging/internal progress information is always written to the Debug
output/object stream.  This switch will reveal that, without the constant
prompting that a full -Debug entails.

.INPUTS

None.  You cannot pipe objects to this script.

.OUTPUTS

A stream of PowerShell custom objects, each one representing a single
top-level Update. A single top-level Update may have multiple "bundled"
package files associated with it. The members of the object include the
MSKB ID, the full title of the update, and the URLs for the associated
package file(s). The output objects are suitable for piping to other
PowerShell cmdlets for viewing, storage, or further processing.

The Warning and/or Verbose streams can be consulted for operational
status and results.

.NOTES

$Id: WUOffline.psm1,v 1.20 2022/11/21 15:19:33 bscott Exp bscott $

Written by Benjamin Scott - http://www.dragonhawk.org/

This is free and unencumbered software released into the public domain.  You
can do whatever you want with it.  There is no warranty.  See the "Unlicense"
at https://unlicense.org/ for details.

Not to be confused with "WSUS Offline Update" (WOU), which is an unrelated
project with similar overall goals, but intended to solve different problems.

For -Include and -Exclude, the matching uses the numeric part of the 
MSKB ID only, without any leading prefix like "KB".  The matching is done 
by this script, not the WU Search facility, because the latter only 
accepts update GUIDs, which can only be determined by looking at the 
results of a Search. (Or so it appears.  Better ideas welcome.) 

Overall workflow for WUOffline would be something like this:

1. Download offline scan catalog from Microsoft.  URL:
	http://go.microsoft.com/fwlink/?LinkId=76054
2. Copy scan catalog to target system
3. On the target system, run something like this:
	Get-WinUpdate C:\WU\WSUSSCN2.CAB | select links > C:\WU\links.txt
4. Copy links.txt to Internet-connected system
5. Download the files from links.txt, for example:
	wget -i links.txt
6. Copy results of download to target system
7. On the target system, run something like this:
	Install-WinUpdate C:\WU\WSUSSCN2.CAB C:\WU

If some target systems cannot have data copied off, build a model system, with
identical software configuration, but with no data and thus not subject to
one-way data flow restrictions.  Use the model system to generate the
links.txt and test update installation.  Then introduce media containing the
downloaded content to the target systems.

.LINK
Install-WinUpdate

.LINK
Start-WUScan

.LINK
Install-WUUpdates

#>

[CmdletBinding()]
Param(

[Parameter(Mandatory=$true,HelpMessage="Full absolute path to offline scan catalog (WSUSSCN2.CAB)")]
[string]$Catalog,

[Parameter(Mandatory=$false,HelpMessage="Report installed updates instead of needed?")]
[switch]$Installed = $false,

[Parameter(Mandatory=$false,HelpMessage="Report both installed and needed updates?")]
[switch]$All = $false,

[Parameter(Mandatory=$false,HelpMessage="Include superseded updates?  Defaults to false.")]
[switch]$Superseded = $false,

[Parameter(Mandatory=$false,HelpMessage="Only process updates matching this KB ID.  -Exclude overrides.")]
[string[]]$Include,

[Parameter(Mandatory=$false,HelpMessage="Do not process updates matching this MS KB.  Overrides -Include.")]
[string[]]$Exclude,

[Parameter(Mandatory=$false,HelpMessage="Explictly specify the WU Search query to run.  Overrides -Installed or -All.")]
[string]$Query,

[Parameter(
	Mandatory=$False,
	HelpMessage="Display debug output (without debug prompting)?"
	)]
[switch]$ShowDebug

) # Param

If ($ShowDebug) {
    $DebugPreference = 'Continue'
}

Write-Debug "Get-WinUpdate: START"

# see NOTE_BOUND_PARAM_MODULE 
# see NOTE_NULL_STRING_PARAM
if (-not $PSBoundParameters.ContainsKey('Query')) {
	$Query = [System.Management.Automation.Language.NullString]::Value
	}

# this is the main point of divergence between Get- and Install-WinUpdate
# $installable is not used for Get-, only for -Install
$installable = $null

main $installable

Write-Debug "Get-WinUpdate: EXIT"

} # Get-WinUpdate

# ----------------------------------------------------------------------
function Install-WinUpdate {
<#
.SYNOPSIS

Install-WindUpdate.  Install Update packages from local files.

.DESCRIPTION

Install-WinUpdate scans for needed updates, and then installs them from update
packages.  You must download and provide the scan catalog and update package
files.

.EXAMPLE

Install-WinUpdate C:\WinUpdate\wsusscn2.cab C:\WinUpdate\pkgs

Scans for needed updates, and then attempts to install them, using
package files previously placed in the C:\WinUpdate\pkgs directory. No
output will be given, unless a package is missing, a reboot is required,
or a problem is detected.

.EXAMPLE

Install-WinUpdate -Verbose -Catalog C:\WinUpdate\wsusscn2.cab -Repo C:\WinUpdate\pkgs

Scans for needed updates, and then attempts to install them, using
package files previously placed in the C:\WinUpdate\pkgs directory.
Major steps and a few statistics are reported as they occur.

.EXAMPLE

Install-WinUpdate C:\WinUpdate\wsusscn2.cab C:\WinUpdate\pkgs -Include 4566424

Install only updates with MSKB matching "4566424".  In this case, it is a
Servicing Stack Update, being installed before other updates.

.PARAMETER Catalog

Full path and file name of Windows Update offline scan catalog.
Typically named WSUSSCN2.CAB and obtained from the
http://go.microsoft.com/fwlink/?LinkId=76054 redirector.

.PARAMETER Repo

Full path and name of a directory/folder containing Windows Update
package files. These may be retrived by obtaining a list of URLs using
Get-WinUpdate, and then copying the resulting files to the target
system.

.PARAMETER Superseded

When searching for Windows Updates, include potentially-superseded
updates.  This is a Windows Update internal option.

.PARAMETER Include

A list of one or more strings, which are checked agains the MSKB IDs of 
updates. Only updates where the MSKB ID exactly matches an include 
string are subject to further processing; the rest are omitted. If no 
-Include is specified, all updates are processed (subject to -Exclude).

If an update matches both -Include and -Exclude, it is excluded.

.PARAMETER Exclude

A list of one or more strings, which are checked agains the MSKB IDs of
updates. Any update where the MSKB ID exactly matches an exclude string,
is omitted from further processing.

If an update matches both -Include and -Exclude, it is excluded.

.PARAMETER Query

Explictly specify the query that will be given to the Windows Update 
engine for the update search.  Does not override Include or -Exclude 
(those are applied to the results from the WU search). 

For query syntax, see: https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdatesearcher-search

.PARAMETER ShowDebug

Shortcut to setting DebugPreference=Continue for this script run.  Tons of
debugging/internal progress information is always written to the Debug
output/object stream.  This switch will reveal that, without the constant
prompting that a full -Debug entails.

.INPUTS

None.  You cannot pipe objects to this script.

.OUTPUTS

None. The Output stream should be empty. The Warning and/or Verbose
streams can be consulted for operational status and results.

.NOTES

$Id: WUOffline.psm1,v 1.20 2022/11/21 15:19:33 bscott Exp bscott $

Written by Benjamin Scott - http://www.dragonhawk.org/

This is free and unencumbered software released into the public domain.  You
can do whatever you want with it.  There is no warranty.  See the "Unlicense"
at https://unlicense.org/ for details.

Not to be confused with "WSUS Offline Update" (WOU), which is an unrelated
project with similar overall goals, but intended to solve different problems.

For -Include and -Exclude, the matching uses the numeric part of the 
MSKB ID only, without any leading prefix like "KB".  The matching is done 
by this script, not the WU Search facility, because the latter only 
accepts update GUIDs, which can only be determined by looking at the 
results of a Search. (Or so it appears.  Better ideas welcome.) 

Overall workflow for WUOffline would be something like this:

1. Download offline scan catalog from Microsoft.  URL:
	http://go.microsoft.com/fwlink/?LinkId=76054
2. Copy scan catalog to target system
3. On the target system, run something like this:
	Get-WinUpdate C:\WU\WSUSSCN2.CAB | select links > C:\WU\links.txt
4. Copy links.txt to Internet-connected system
5. Download the files from links.txt, for example:
	wget -i links.txt
6. Copy results of download to target system
7. On the target system, run something like this:
	Install-WinUpdate C:\WU\WSUSSCN2.CAB C:\WU

If some target systems cannot have data copied off, build a model system, with
identical software configuration, but with no data and thus not subject to
one-way data flow restrictions.  Use the model system to generate the
links.txt and test update installation.  Then introduce media containing the
downloaded content to the target systems.

.LINK
Get-WinUpdate

.LINK
Start-WUScan

.LINK
Install-WUUpdate

#>

[CmdletBinding()]
Param(

[Parameter(Mandatory=$true,HelpMessage="Full absolute path to offline scan catalog (WSUSSCN2.CAB)")]
[string]$Catalog,

[Parameter(Mandatory=$true,HelpMessage="Repository.  Path to the directory/folder containing update package files to load.")]
[string]$Repo,

[Parameter(Mandatory=$false,HelpMessage="Include superseded updates?  Defaults to false.")]
[switch]$Superseded = $false,

[Parameter(Mandatory=$false,HelpMessage="Only process updates matching this KB ID.  -Exclude overrides.")]
[string[]]$Include,

[Parameter(Mandatory=$false,HelpMessage="Do not process updates matching this MS KB.  Overrides -Include.")]
[string[]]$Exclude,

[Parameter(Mandatory=$false,HelpMessage="Explictly specify the WU Search query to run.")]
[string]$Query,

[Parameter(
	Mandatory=$False,
	HelpMessage="Display debug output (without debug prompting)?"
	)]
[switch]$ShowDebug

) # Param

If ($ShowDebug) {
    $DebugPreference = 'Continue'
}

Write-Debug "Install-WinUpdate: START"

# see NOTE_BOUND_PARAM_MODULE 
# see NOTE_NULL_STRING_PARAM
if (-not $PSBoundParameters.ContainsKey('Query')) {
	$Query = [System.Management.Automation.Language.NullString]::Value
	}

# since Install- doesn't have -All or -Installed switches, we dummy
# up some variables to take their place.
$All = $false
$Installed = $false

# this will hold a list of updates we will actually try to install
$installable = New-Object -COMObject Microsoft.Update.UpdateColl

main $installable

Write-Debug "Install-WinUpdate: EXIT"

} # Install-WinUpdate

########################################################################
# internal functions

# ----------------------------------------------------------------------
function main ($installable) {


Write-Debug "main: START"

# Explictly recast $Superseded as boolean.  Otherwise this:
#	$sch.IncludePotentiallySupersededUpdates = $Superseded
# will throw an error like this:
#	Specified cast is not valid
# I presume there is some weirdness with DCOM/WU and the [switch] type.
[boolean]$Superseded = $Superseded

# global counters
$script:topcount = 0
$script:skipped = 0

check_args
$Query = build_query
$WU = init_WU
$results = search_WU $WU.sch
process_WU_results $results

# the service tends to hang around in background if not explictly removed
Write-Debug "main: removing WU Service..."
$WU.mgr.RemoveService($WU.svcID)

Write-Debug "main: EXIT"

} # main

# ----------------------------------------------------------------------
function check_args () {
# sanity check the arguments/parameters given by external caller

# catalog file
if (-not [System.IO.Path]::IsPathRooted($Catalog) ) {
	Throw "Catalog path must be absolute, not relative: $Catalog"
	}
if (-not (Test-Path -PathType Leaf $Catalog)) {
	Throw "Catalog file does not appear to exist: $Catalog"
	}

# for Install- also do the repo
if ($installable) {
	if (-not [System.IO.Path]::IsPathRooted($Repo) ) {
		Throw "Repository path must be absolute, not relative: $Repo"
		}
	if (-not (Test-Path -PathType Container $Repo)) {
		Throw "Repository does not exist or is not a directory: $Repo"
		}
	}


} # check_args

# ----------------------------------------------------------------------
function build_query () {
# Unless $Query was explicitly specified, we need to build it.
# If we're installing, $All and $Installed will never be true,
# so the final else default will always be used, but that's good.

# Discovering NOTE_NULL_STRING_PARAM made this interesting.

# if Query is non-null, the parameter was specified by caller
$explict_query = ($null -ne $Query)

if ($explict_query) {
	Write-Debug "build_query: using explicit query"
	return $Query
	}
else {
	Write-Debug "build_query: building query automatically"
	if ($All) {
		return "IsInstalled=0 or IsInstalled=1"
		}
	elseif ($Installed) {
		return "IsInstalled=1"
		}
	else {
		return "IsInstalled=0"
		}
	}

} # build_query

# ----------------------------------------------------------------------
function init_WU () {
# initialize Windows Update and its various objects

Write-Verbose "Creating WU Session..."
$ses = New-Object -ComObject Microsoft.Update.Session

Write-Verbose "Creating WU Manager..."
$mgr = New-Object -ComObject Microsoft.Update.ServiceManager

Write-Verbose "Creating WU Service from Scan Package..."
$duration = Measure-Command {
	$svc = $mgr.AddScanPackageService($svcName, $Catalog, $VolatileService)
	}
elapsed $duration

$svcID = $svc.ServiceID.ToString()
Write-Debug "init_WU: ServiceID = <$svcID>"

Write-Verbose "Creating WU Searcher..."
$sch = $ses.CreateUpdateSearcher()

Write-Verbose "Setting up search parameters..."
$sch.ServerSelection = $SearchOthers
$sch.IncludePotentiallySupersededUpdates = $Superseded
$sch.CanAutomaticallyUpgradeService = $false

# IUpdateSearcher.Online
# https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdatesearcher-get_online
# Docs would lead you to believe we would want this turned off.
# But if you do that, Search detects zero updates.  So don't do that.
#$sch.Online = $false

Write-Verbose "Connecting Searcher to Service..."
$sch.ServiceID = $svcID

# collect the WU objects into a single custom object
$wrapper = [PSCustomObject] @{
	ses = $ses
	mgr = $mgr
	svc = $svc
	sch = $sch
	svcID = $svcID
	}

Write-Debug "init_WU: exiting"

return $wrapper

} # init_WU

# ----------------------------------------------------------------------
function search_WU ($searcher) {
# tell WU to search for updates that match our $Query

Write-Verbose "Searching for updates..."
$duration = Measure-Command {
	$results = $searcher.Search($Query)
	}
elapsed $duration

return $results

} # search_WU

# ----------------------------------------------------------------------
function process_WU_results ($results) {
# process the results of a Windows Update Searcher .Search()

report_OpResult $results.ResultCode

report_warnings $results.Warnings

Write-Verbose "Search found $( $results.Updates.Count ) top-level updates (before include/exclude)"

$processed = process_update_list -updates $results.updates -parent $null -parentKB $null -installable $installable

Write-Verbose "Kept $script:topcount updates after processing, omitted $script:skipped"

if ($script:topcount -lt 1) {
	Write-Warning "Zero updates found (after processing)"
	return
	}

if ($installable) {
	# When installing, we ignore the $processed results.
	# Instead we're interested in what gets put in $installable.
	install_updates $installable
	}
else {
	# When just reporting needed updates, we emit the processed list.
	# The external caller should get a stream of objects with update info.
	# The results can then by piped to Format-Table, Export-CSV, etc.
	Write-Output $processed
}

} # process_WU_results

# ----------------------------------------------------------------------
function hex ($dword) {
# converts a DWORD (32-bit unsigned int) to hexadecimal string

return ("0x" + $dword.ToString("X8"))

} # hex

# ----------------------------------------------------------------------
function elapsed ($span) {
# reports a human-friendly interpretation of the given timespan

# spaces and literal "m" and "s" get escaped with \
$span = $span.ToString('m\m\ ss\s')
Write-Verbose "Duration: $span"

} # elapsed

# ----------------------------------------------------------------------
function report_OpResult ($code) {
# interprets an OperationsResultCode and informs the operator
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/a0eb1e12-0a6a-47c9-a70f-f272d87b5227

$name = switch ($code) {
	0 { "NotStarted" }
	1 { "InProgress" }
	2 { "Succeeded" }
	3 { "SucceededWithErrors" }
	4 { "Failed" }
	5 { "Aborted" }
	default { "UNKNOWN" }
	}

$msg = "ResultCode: $code ($name)"

# if we got the desired 2/Success, that is reported as a verbose detail
# if it is something else, report it as a warning
if ($code -eq 2 ) {
	Write-Verbose $msg
	}
else {
	Write-Warning $msg
	}

} # report_OpResult

# ----------------------------------------------------------------------
function report_warnings ($warns) {

$warnCount = $warns.Count
if ($warnCount -gt 0) {
	Write-Warning "Search reported $warnCount warnings"
	}

} # report_warnings

# ----------------------------------------------------------------------
function process_update_list ($updates, $parent, $parentKB, $installable) {

Write-Debug "process_update_list: entering with parentKB=<$parentKB>"

foreach ($update in $updates) {
	process_update_single $update $parent $parentKB $installable
	}

Write-Debug "process_update_list: exiting with parentKB=<$parentKB>"

} # process_update_list

# ----------------------------------------------------------------------
function process_update_single ($update, $parent, $parentKB, $installable) {

Write-Debug "process_update_single: parentKB=<$parentKB>"

# flatten KB
$KB = ($update.KBArticleIDs -join '/')
Write-Debug "process_update_single: KB=<$KB>"

# if there is an include list, and the KB is *NOT* in it, skip the update
# except if this KB has a blank KB ID
#   in which case we can't make a determination
#   but those should all be bundled updates for a parent
#   and so should be caught when their parent KB ID was filtered
if ($Include -and $KB -and ($Include -notcontains $KB)) {
	Write-Debug "process_update_single: skipping not-included"
	$script:skipped++
	return
	}

# if the KB is in the list of excludes, skip it
if ($Exclude -contains $KB) {
	Write-Debug "process_update_single: skipping excluded"
	$script:skipped++
	return
	}

# we assume:
#   every top-level update has a KB ID
#   every bundled update has no KB ID (gets it from parent)
# anything else blows our model out of the water
if ($parent) { # we are a bundled
	# if KB is defined and not empty, we puke
	if (($KB) -and ($KB -ne [string]::Empty)) {
		throw "encountered a bundled update with its own KB ID (KB=<$KB> parent=<$parentKB>)"
		}
	}
else { # no parent, we are top-level
	# increase the counter of top-level updates
	# (possibly right before we throw an error, but good if not)
	$script:topcount++
	# if KB is not defined, or KB is empty, we puke
	if ((-not $KB) -or ($KB -eq [string]::Empty)) {
		throw "encountered a top-level update without a KB ID"
		}
	}

# $effectiveKB is used in error messages, reporting, and the like.
# (Because $KB will be empty if we are a bundled update, and that's not
# very useful to the operator.)
$effectiveKB = if ($parent) { $parentKB } else { $KB }

# add a NoteProperty to track if we've added this to $installable
Add-Member -InputObject $update -MemberType NoteProperty -TypeName boolean -Name InstAdded -Value $false

$title = $update.Title

# turn the categories into a single string, separated by slashes
$cats = (( $update.Categories | Select-Object -ExpandProperty Name ) -join '/')

# init $links to empty list
$links = @()

# add links from *this* update
$links_more = process_download_list -KB $effectiveKB -update $update -parent $parent -installable $installable
Write-Debug "process_update_single: links from this update: <$( $links_more )>"
# conditional because sometimes $null would show up as a member of $links
if ($links_more) { $links += $links_more }

# interpret various properties into a concise status string
# Installed=Installed-for-all-products, Present=Installed-for-some
$status = switch ($true) {
	($update.IsInstalled)	{ "Installed"	; break }
	($update.IsPresent)	{ "Present"	; break }
	($update.IsDownloaded)	{ "Loaded"	; break }
	default			{ "Needed"	; break }
	}
Write-Debug "process_update_single: status=<$status>"

# BundledUpdate
# if we have a parent, we are ourselves a BundledUpdate
# a BundledUpdate with nested BundledUpdates blows our little mind
if (($parent) -and ($update.BundledUpdates.Count -gt 0)) {
	Throw "encountered a bundle with a nested bundle (parentKB=<$parentKB>)"
	}
$bundled = process_update_list -updates $update.BundledUpdates -parent $update -parentKB $KB -installable $installable

# all we've ever seen from bundled updates is URLs
# so add links from bundled updates, and ignore the rest
$links_more = $bundled.links
Write-Debug "process_update_single: links from bundled updates: <$( $links_more )>"
if ($links_more) { $links += $links_more }

# flatten links into a space-separated string
# since URLs cannot contain spaces, this works out nicely
$links = ($links -join ' ')

# We haven now gathered and prepared all the info.
# We collect the info in a custom object to present it in a convenient format.
$update_info = [PSCustomObject] @{
	KB       = $effectiveKB
	Status   = $status
	Title    = $title
	Cats     = $cats
	Links    = $links
	}

Write-Debug "process_update_single: exiting parentKB=<$parentKB> KB=<$KB>"

return $update_info

} # process_update

# ----------------------------------------------------------------------
function process_download_list ($KB, $update, $parent, $installable) {
# loop through the download list and get all the URLs
# loop through the download list and get all the URLs
# each URL is emitted to the output stream
# effectively making the return value a list of strings
# if $installable is defined, we also try to load the package file

Write-Debug "process_download_list: entering with KB=<$KB>"

foreach ($download in $update.DownloadContents) {

	$url = $download.DownloadUrl
	Write-Debug "process_download_list: url=<$url>"

	Write-Output $url

	# if we're trying to install, also try to load the package
	if ($installable) {
		load_update_pkg -KB $KB -update $update -parent $parent -installable $installable
		}

	} # foreach $download

} # process_download_list

# ----------------------------------------------------------------------
function load_update_pkg ($KB, $update, $parent, $installable) {

# get the base file name (with extension) from the URL
$leaf = Split-Path -Leaf $url
Write-Debug "load_update_pkg: leaf=<$leaf>"

# look in the repository for a file with of the same name
$file = Join-Path $repo $leaf
Write-Debug "load_update_pkg: file=<$file>"

# if the file does not exist in the repository...
if (-not (Test-Path $file) ) {
	# tell the operator
	Write-Warning "Could not find package file, skipping:"
	Write-Warning "  KB=<$KB>"
	Write-Warning "  File=<$leaf>"
	# move on to the next thing
	return
	}

# if we found it, assume it's the right file, and try to load it
Write-Verbose "Loading package: $leaf"

# .CopyToCache() requires an object implementing IStringCollection
# so we have to wrap $file in a compatible class else first
$sc = New-Object -COMObject Microsoft.Update.StringColl
# StringColl.Add() tends to return zero (0), discard that
$sc.Add($file) | Out-Null

# now add the package file to the BundledUpdate
$update.CopyToCache($sc)

# now we want to add the top-level update to the $installable collection
# if we have a $parent update, top would be the parent
# if no $parent, this update is the top-level update
$topUpdate = if ($parent) { $parent } else { $update }

# if we've already added this, don't do it again
# (this is just the list of (top-level) updates to *install*-- every package is added regardless)
if ($topUpdate.InstAdded) {
	Write-Debug "load_update_pkg: topUpdate already added to installable, not adding again"
	return
	}

# package was loaded, add this update to the list to install
# here .Add returns the index of the new member, discard that
Write-Debug "load_update_pkg: adding topUpdate to installable"
$installable.Add($topUpdate) | Out-Null

Write-Debug "load_update_pkg: marking topUpdate as added"
$topUpdate.InstAdded = $true

Write-Debug "load_update_pkg: exiting at end"

} # load_update_pkg

# ----------------------------------------------------------------------
function install_updates ($installable) {

Write-Verbose "Loaded $( $installable.Count ) updates"

Write-Verbose "Creating WU Installer..."
$ins = New-Object -COMObject Microsoft.Update.Installer

Write-Verbose "Feeding update list to Installer..."
$ins.Updates = $installable

Write-Verbose "Installing updates..."
$duration = Measure-Command {
	$results = $ins.Install()
	}
elapsed $duration

# interpret results for overall install attempt

report_OpResult $results.ResultCode

$hr = $results.HResult
if ($hr -ne 0) {
	$hr = hex $hr
	Write-Warning "Install process had overall HRESULT $hr"
	}

# interpret results for individual updates

Write-Verbose "Checking installation results..."
# we have to check results of each update individually
# and we have to use a counter because .GetUpdateResult takes an index
for ($index = 0 ; $index -lt $installable.Count ; $index++) {
	check_update_result -installable $installable -index $index
	}

# I tried putting $ins.Commit here, just in case,
# but that just threw a method-does-not-exist error.
# https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdateinstaller4-commit

# check for the nearly-inevitable reboot
if ($results.RebootRequired) {
	Write-Warning "Windows Update says a reboot is required."
	}

} # install_updates

# ----------------------------------------------------------------------
function check_update_result ($installable, $index) {

$update = $installable.Item($index)

# flatten KB
$KB = $( $update.KBArticleIDs )
Write-Debug "results check: KB=<$KB>"

# if there is an include list, and the KB is *NOT* in it, skip the update
# don't need to worry about bundled updates with blank $KB here --
#   the $installable list is just top-level updates
if ($Include -and ($Include -notcontains $KB)) {
	Write-Debug "check_update_result: skipping not-included"
	return
	}

# if the KB is in the list of excludes, skip it
if ($Exclude -contains $KB) {
	Write-Debug "check_update_result: skipping excluded"
	return
	}

# get the results for this update in particular
# Note that GetUpdateResult() here does not match the docs.
# https://docs.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iinstallationresult-getupdateresult
# They claim it takes two arguments and returns an HRESULT.
# In practice it takes just the index, and returns an
# object implementing IUpdateInstallationResult.
$upRes = $results.GetUpdateResult($index)

$rc = $upRes.ResultCode
$hr = $upRes.HResult

# if either code indicates trouble, report them both
if ( ($hr -ne 0) -or ($rc -ne 2) ) {
	$hr = hex $hr
	Write-Warning "Update $KB had HRESULT $hr and ResultCode $rc"
	}

} # check_update_result

########################################################################
# exports

Export-ModuleMember -Function Get-WinUpdate
Export-ModuleMember -Function Install-WinUpdate

########################################################################