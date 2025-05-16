<# ::
:#

@echo off & setlocal EnableExtensions DisableDelayedExpansion
:# Copy the script to a temporary powershell file, then run it
copy "%~f0" "%TEMP%\%~n0.ps1" >NUL && powershell -NoProfile -Command "& {Start-Process PowerShell -Wait -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"%TEMP%\%~n0.ps1\" %args%' }"
:# Save any error codes returned, then delete the temporary powershell file
set "ec=%ERRORLEVEL%" & del "%TEMP%\%~n0.ps1" >NUL
exit /b %ec%

:#
#>

#  Script name:    DisableAccount v4.0.3
#  Created on:     03-10-2022
#  Updated on:     04-12-2024
#  Author:         Ian Morley
#  Contributer:    Aidan Payne
#  Purpose:        Disables users with all necessary local and cloud AD actions


#Logo
$Logo = @"
______ _           _     _       ___                            _
|  _  (_)         | |   | |     / _ \                          | |
| | | |_ ___  __ _| |__ | | ___/ /_\ \ ___ ___ ___  _   _ _ __ | |_
| | | | / __|/ _  | '_ \| |/ _ \  _  |/ __/ __/ _ \| | | | '_ \| __|
| |/ /| \__ \ (_| | |_) | |  __/ | | | (_| (_| (_) | |_| | | | | |_
|___/ |_|___/\__,_|_.__/|_|\___\_| |_/\___\___\___/ \__,_|_| |_|\__|


"@
$Logo

# Gets user information for verification purposes
function Write-Log{
    Param
    (
        $text
    )

    "$(get-date -format \"yyyy-MM-dd HH:mm:ss\"): $($text)" | out-file $log -Append
}

# Gets user information for verification purposes
function datachecker(){
	$userinfos = get-aduser -Identity $username -Properties sAMAccountName,EmployeeID,manager,title,physicalDeliveryOfficeName,department,displayName

	if ($userinfos.Manager -eq $null){
	write-host "The attribute manager does not exist"} else{

    }

	$userdata = New-Object PSObject -Property @{
			'Username'           = $userinfos.sAMAccountName
			'Fullname'           = $userinfos.displayname
			'Title'              = $userinfos.title
  		'EmployeeID'         = $userinfos.employeeID
			'Office'	           = $userinfos.physicalDeliveryOfficeName
			'Department'	       = $userinfos.department
			'Manager'            = $userinfos.manager
			} | Select-Object Username,Fullname,title,EmployeeID,Office,Department,manager

	Write-Host "Please check the following and confirm this is the correct account." -ForegroundColor Red
	$userdata
	write-log -text "$userdata"
	Write-Host "Are you certain this is the account you wish to disable?" -ForegroundColor Red
}

# Gathers all direct reports and then removes the disabled user from the direct report's manager value
function managerchecker(){
	$userman = Get-ADUser $username -prop Manager,displayname
	$UsersFromManagerlist = ""
	write-log -text "Checking all manager attributes. This can take a few minutes..."
	write-host "Checking all manager attributes. This can take a few minutes..."
	$UsersFromManagerlist = get-aduser -fi * -prop Manager,displayname | where {$_.Manager -eq $userman.DistinguishedName}
	$counter = ($UsersFromManagerlist | Measure-Object).Count
	if ($UsersFromManagerlist -ne $null){
		$text_usersfromManagerList = "For " +$counter+ " user/s, the user "+ $userman.displayname + " was entered as manager. The value is set to NULL for the following users:"
		write-log -text $text_usersfromManagerList
		Write-Host "For" $counter "user/s, the user" $userman.displayname "was entered as manager. The value is set to NULL for the following users:"
		foreach ($user in $UsersFromManagerlist){
			Set-ADUser -identity $User.SamAccountName -Manager $null
			Write-Host "-" $user.displayname " - " $user.samaccountname -ForegroundColor Yellow
			Write-log -text "-" $user.displayname " - " $user.samaccountname
		}
	} else {
			Write-Log -text "The user is not listed in any manager attribute."
			Write-Host "The user is not listed in any manager attribute."
			}
	Write-Log -text "The manager attibute check was completed..."
	Write-Host "All direct reports have been removed." -ForegroundColor Green
	Write-log "`n------"
	Write-Host "`n------`n"
}

# Deletes User from all on-prem groups and copies groups to clipboard
function delgroups(){
	$groups = @()
	$groups = Get-ADPrincipalGroupMembership -Identity $username -resourcecontextserver tectrucks.local | Select-Object -ExpandProperty Name | Where-Object { $_ -ne 'Domain Users' }
	$groups | clip
	write-log -text "All groups of the user:"
	write-host "If groups exist they will print here:"
		foreach ($group in $groups){
			if ($group -ne "Domain Users"){
				Remove-ADGroupMember -Identity $group -Members $username -confirm:$false -ErrorAction Ignore
				write-log -text $group -ForegroundColor Yellow
				Write-Host "-" $group -ForegroundColor Yellow
			}
		}
		write-log -text "The user was removed from all groups"
		write-log -text "------"
	  Write-Host "The user was removed from all groups." -ForegroundColor Green
	  Write-Host "`n------`n"
}

# Deletes user from all cloud groups
function delcloudgroups(){
	$userID = $(get-mguser -search "UserPrincipalName:$username" -consistencylevel Eventual).id
	$params = @{SecurityEnabledOnly = $False} 
	$cloudgroups = get-mgusermembergroup -userID $userID -bodyparameter $params
	$cloudgroupnames = @()
	foreach($cloudgroup in $cloudgroups){
		$cloudgroupnames += $(get-mggroup -groupid $cloudgroup).displayName
		remove-mggroupmemberbyref -groupid $cloudgroup -directoryobjectID $userID
	}
}

# Clear location/branch/region extensionattributes
function ClearLocationAttributes(){
    Set-ADUser -Identity $username -Clear Extensionattribute1,Extensionattribute2,Extensionattribute3
    Write-Host "User's location attributes cleared"
    Write-Log -text "User's location attributes cleared"
}

# Disables the user, removes their manager value, and sets office to exclude
function DisableUser(){
    $userinfos = get-aduser -Identity $username -Properties sAMAccountName,EmployeeNumber,manager,title,displayName -ErrorAction SilentlyContinue
	$managerdataname = $null

	Set-ADUser -identity $username -Replace @{physicalDeliveryOfficename="EXCLUDE"}
	Set-ADUser -identity $username -Manager $null

	write-host "Office was set to EXCLUDE" -ForegroundColor Green
	write-log -text "Office was set to EXCLUDE"
	if ($managerdataname -ne $null){
		write-host "The attribute manager changed from $managerdataname to NULL"
		write-log -text "The attribute manager changed from $managerdataname to NULL"
	}

	Disable-ADAccount -Identity $username
	write-log -text "$username was disabled"

	Write-Host 'The user was disabled' -ForegroundColor Green
	$userid =  get-aduser -Identity $username -prop ObjectGUID
	Move-ADObject -Identity $userid.ObjectGUID -TargetPath $OU_disableUser
	write-log -text "$username was moved to $OU_disableUser"
	Write-Host "The user was moved to $OU_disableUser" -ForegroundColor Green
	Write-Host "`n------`n"
}

# Closes the script
function CloseScript(){
	write-log -text "------"
	write-log -text "the script is aborted"
	Write-Host "`n------`n"
	Write-Host "the script is aborted"
	Read-Host "Press Enter to exit"
}

# Removes licenses and converts mailbox to shared mailbox
function AzureAD_changes() {
	$userinfos = get-aduser -Identity $username -Properties sAMAccountName,EmployeeNumber,manager,title,displayName,UserPrincipalName -ErrorAction SilentlyContinue
	$mail = $username + "@tecequipment.com"
	$mailbox = get-mailbox $mail -ErrorAction SilentlyContinue
	if ($mailbox){
		Set-Mailbox $mail -Type Shared
		$validateSharedMailbox = $FALSE
		while($validateSharedMailbox -ne $TRUE){
	    		if ((get-mailbox $mail | select -ExpandProperty recipienttypedetails) -eq 'SharedMailbox'){
	        		$validateSharedMailbox = $TRUE
	    		} else {
	    			write-host "Mailbox still not shared, waiting 3 seconds..."
	        		Start-Sleep -seconds 3
	    		}
		}
		write-host "The user's mailbox changed to shared mailbox" -ForegroundColor Green
		write-log -text "The user's mailbox changed to shared mailbox"
	} else {
		write-host "No mailbox was found" -ForegroundColor Green
		write-log -text "No mailbox was found"
	}
	write-host $userinfos.UserPrincipalName
	$mgGraphUser = get-mguser -search "UserPrincipalName:$($userinfos.UserPrincipalName)" -consistencylevel Eventual
	write-host $mgGraphUser
	$mgAssignedLicenses = get-mguserlicensedetail -userID "$($mgGraphUser.id)"
	if ($mgAssignedLicenses){
		foreach ($License in $mgAssignedLicenses){
			set-mguserLicense -userid $mgGraphUser.id -addLicenses @() -RemoveLicenses @($License.skuid)
		}
		write-host "All licenses removed" -ForegroundColor Green
		write-log -text "All licenses removed"
	} else {
		write-host "No licenses found" -ForegroundColor Green
		write-log -text "No licenses found"
	}
}

# Sets user mailnickname and hide from GAL
function RemoveFromGal() {
	set-aduser -Identity $username -add @{msexchhidefromaddresslists=$true;mailnickname="$username"}
	write-host "User hidden from GAL"
	Write-Log -text "User hidden from GAL"
}

# Script calling all functions
Connect-Mggraph -scopes User.ReadWrite.All, Organization.Read.All, group.readwrite.all -nowelcome
Connect-ExchangeOnline -ShowBanner:$false

# Dynamically calculate OU path from current date and domain
$year = (Get-Date).Year
$month = (Get-Date).Month
$quarter = "Q$([math]::Ceiling($month / 3))"
$domainComponents = (Get-ADDomain).DistinguishedName
$OU_disableUser = "OU=$year`_$quarter,OU=Disabled Users,OU=Accounts,$domainComponents"

$ticket = Read-Host "What is the ticket number?"
$username = Read-Host "What is the username of the account you wish to disable?"
if (!(Get-ADUser -Filter "sAMAccountName -eq '$($Username)'")) {
	Write-Host "User $username does not exist." -ForegroundColor red
	write-log -text "User $username does not exist." -ForegroundColor red
	Read-Host "Press Enter to exit"
    exit
} else {

	$date = get-date -format "yyyyMMdd"

	# Set default log path to C:\temp and ensure it exists
	$defaultLogPath = "C:\\temp"
	$useDefault = Read-Host "Use the default log path ($defaultLogPath)? (y/n)"
	if ($useDefault -match '^(y|yes)$') {
		$logDirectory = $defaultLogPath
	} else {
		$logDirectory = Read-Host "Enter full path for log directory"
	}

	if (!(Test-Path $logDirectory)) {
		try {
			New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
		} catch {
			Write-Host "Failed to create log directory. Exiting..." -ForegroundColor Red
			exit
		}
	}

	$log = Join-Path $logDirectory "$ticket" + "_" + "$username".Replace('.', '') + ".log"
	if (!(Test-Path $log)) {
		New-Item -ItemType File -Path $log -Force -ErrorAction Stop | Out-Null
	}

    datachecker
    $request = Read-Host "(y/n)"
	Write-Host "`n------`n"
    if ($request -eq "y" -or $request -eq "yes"){
		managerchecker
		delgroups
		delcloudgroups
    	AzureAD_changes
		DisableUser
		ClearLocationAttributes
		RemoveFromGal
    	Write-Host "User groups have been copied to your clipboard. Please paste them into the ticket." -ForegroundColor Yellow
    	Write-Host "A log of this session has been saved to $log`n"
		Read-Host "Press Enter to exit"
	} else {
		CloseScript
	}
}
