#Requires -Version 4

<# 
 
.SYNOPSIS
	MSCloudIdAssessment.psm1 is a Windows PowerShell module to gather configuration information across different components of the identity infrastrucutre

.DESCRIPTION

	Version: 1.0.0

	MSCloudIdUtils.psm1 is a Windows PowerShell module with some Azure AD helper functions for common administrative tasks


.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>


<# 
 .Synopsis
  Starts the sessions to AzureAD and MSOnline Powershell Modules

 .Description
  This function prompts for authentication against azure AD 

#>
function Start-MSCloudIdSession		
{
    [CmdletBinding()]
    param
    ()

    Connect-MsolService
    Connect-AzureAD
}

<# 
 .Synopsis
  Gets Azure AD Application Proxy Connector Logs

 .Description
  This functions returns the events from the Azure AD Application Proxy Connector Admin Log

 .Parameter DaysToRetrieve
  Indicates how far back in the past will the events be retrieved

 .Example
  Get the last seven days of logs and saves them on a CSV file   
  Get-MSCloudIdAppProxyConnectorLog -DaysToRetrieve 7 | Export-Csv -Path ".\AzureADAppProxyLogs-$env:ComputerName.csv" 
#>
function Get-MSCloudIdAppProxyConnectorLog
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [int]
        $DaysToRetrieve
    )
    $TimeFilter = $DaysToRetrieve * 86400000
    $EventFilterXml = '<QueryList><Query Id="0" Path="Microsoft-AadApplicationProxy-Connector/Admin"><Select Path="Microsoft-AadApplicationProxy-Connector/Admin">*[System[TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>' -f $TimeFilter
    Get-WinEvent -FilterXml $EventFilterXml
}

<# 
 .Synopsis
  Gets the Azure AD Password Writeback Agent Log

 .Description
  This functions returns the events from the Azure AD Password Write Bag source from the application Log

 .Parameter DaysToRetrieve
  Indicates how far back in the past will the events be retrieved

 .Example
  Get the last seven days of logs and saves them on a CSV file   
  Get-MSCloudIdPasswordWritebackAgentLog -DaysToRetrieve 7 | Export-Csv -Path ".\AzureADAppProxyLogs-$env:ComputerName.csv" 
#>
function Get-MSCloudIdPasswordWritebackAgentLog
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [int]
        $DaysToRetrieve
    )
    $TimeFilter = $DaysToRetrieve * 86400000
    $EventFilterXml = "<QueryList><Query Id='0' Path='Application'><Select Path='Application'>*[System[Provider[@Name='PasswordResetService'] and TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>" -f $TimeFilter
    Get-WinEvent -FilterXml $EventFilterXml
}

<# 
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-MSCloudIdNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv" 
#>
function Get-MSCloudIdNotificationEmailAddresses
{
    $technicalNotificationEmail = Get-MSOLCompanyInformation | Select-Object -ExpandProperty TechnicalNotificationEmails
    $result = New-Object -TypeName psobject -Property @{ NotificationEmailScope = "Tenant"; NotificationType = "Technical Notification"; RecipientName = "N/A";  EmailAddress = $technicalNotificationEmail; ; RoleMemberObjectType = "email address"; RoleMemberAlternateEmail = "N/A" }

    Write-Output $result

	#Get email addresses of all users with privileged roles

    $roles = Get-AzureADDirectoryRole

    foreach ($role in $roles)
    {
        $roleMembers = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId
        foreach ($roleMember in $roleMembers)
        {
            $alternateEmail = $roleMember.OtherMails -join ";"
            $result = New-Object -TypeName psobject -Property @{ NotificationEmailScope = "Role"; NotificationType = $role.DisplayName; RecipientName = $roleMember.DisplayName;  EmailAddress = $roleMember.Mail; UPN = $roleMember.UserPrincipalName; RoleMemberObjectType = $roleMember.ObjectType; RoleMemberAlternateEmail = $alternateEmail }
            Write-Output $result
        }
    }
}


<# 
 .Synopsis
  Gets a report of all assignments to all applications

 .Description
  This functions returns a list indicating the applications and their user/groups assignments  

 .Example
  Get-MSCloudIdAppAssignmentReport | Export-Csv -Path ".\AppAssignments.csv" 
#>
function Get-MSCloudIdAppAssignmentReport
{
	#Get all app assignemnts using "all users" group
	#Get all app assignments to users directly

    Get-AzureADServicePrincipal -All $true | Get-AzureADServiceAppRoleAssignedTo -All $true
}

<# 
 .Synopsis
  Gets a report of all members of roles 

 .Description
  This functions returns a list of users who hold special roles in the directory

 .Example
  Get-MSCloudIdAdminRolesReport | Export-Csv -Path ".\AdminRoles.csv" 
#>
function Get-MSCloudIdAdminRolesReport
{	
	$roles = Get-AzureADDirectoryRole

    foreach ($role in $roles)
    {
        $roleMembers = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId
        foreach ($roleMember in $roleMembers)
        {
            $result = New-Object -TypeName psobject -Property @{ RoleName = $role.DisplayName; RoleMemberDisplayName = $roleMember.DisplayName; RoleMemberEmail = $roleMember.Mail; RoleMemberUPN = $roleMember.UserPrincipalName; RoleMemberObjectType = $roleMember.ObjectType }
            Write-Output $result
        }
    }
}

<# 
 .Synopsis
  Provides a report to show all the keys expiration date accross application and service principals 

 .Description
  Provides a report to show all the keys expiration date accross application and service principals
  
 .Example
  Connect-AzureAD
  Get-MSCloudIdApplicationKeyExpirationReport
  
#>
Function Get-MSCloudIdApplicationKeyExpirationReport
{
    param()
    
    $apps = Get-AzureADApplication -All $true

    foreach($app in $apps)
    {
        $appObjectId = $app.ObjectId
        $appName = $app.DisplayName
        

        $appKeys = Get-AzureADApplicationKeyCredential -ObjectId $appObjectId

        foreach($appKey in $appKeys)
        {        
            $result = New-Object PSObject
            $result  | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $appName
            $result  | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Application"
            $result  | Add-Member -MemberType NoteProperty -Name "KeyType" -Value $appKey.Type
            $result  | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $appKey.StartDate
            $result  | Add-Member -MemberType NoteProperty -Name "End Date" -Value $appKey.EndDate
            $result  | Add-Member -MemberType NoteProperty -Name "Usage" -Value $appKey.Usage
            Write-Output $result
        }

        $appKeys = Get-AzureADApplicationPasswordCredential -ObjectId $appObjectId
        
        foreach($appKey in $app.PasswordCredentials)
        {        
            $result = New-Object PSObject
            $result  | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $appName
            $result  | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Application"
            $result  | Add-Member -MemberType NoteProperty -Name "KeyType" -Value "Password"
            $result  | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $appKey.StartDate
            $result  | Add-Member -MemberType NoteProperty -Name "End Date" -Value $appKey.EndDate
            Write-Output $result
        }
    }

    
    $servicePrincipals = Get-AzureADServicePrincipal -All $true

    foreach($sp in $servicePrincipals)
    {
        $spName = $sp.DisplayName
        $spObjectId = $sp.ObjectId

        $spKeys = Get-AzureADServicePrincipalKeyCredential -ObjectId $spObjectId        

        foreach($spKey in $spKeys)
        {
            $result = New-Object PSObject
            $result  | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $spName
            $result  | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Service Principal"
            $result  | Add-Member -MemberType NoteProperty -Name "KeyType" -Value $spKey.Type
            $result  | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $spKey.StartDate
            $result  | Add-Member -MemberType NoteProperty -Name "End Date" -Value $spKey.EndDate
            $result  | Add-Member -MemberType NoteProperty -Name "Usage" -Value $spKey.Usage
            Write-Output $result
        }    
        
        $spKeys = Get-AzureADServicePrincipalPasswordCredential -ObjectId $spObjectId    

        
        foreach($spKey in $spKeys)
        {
            $result = New-Object PSObject
            $result  | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $spName
            $result  | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Service Principal"
            $result  | Add-Member -MemberType NoteProperty -Name "KeyType" -Value "Password"
            $result  | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $spKey.StartDate
            $result  | Add-Member -MemberType NoteProperty -Name "End Date" -Value $spKey.EndDate
            Write-Output $result
        }    
    }
}


<# 
 .Synopsis
  Gets a report of all members of roles 

 .Description
  This functions returns a list of consent grants in the directory

 .Example
  Get-MSCloudIdConsentGrantList | Export-Csv -Path ".\ConsentGrantList.csv" 
#>

<# 
.SYNOPSIS
    Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments).

.PARAMETER PrecacheSize
    The number of users to pre-load into a cache. For tenants with over a thousand users,
    increasing this may improve performance of the script.

.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 | Export-Csv -Path "permissions.csv" -NoTypeInformation
    Generates a CSV report of all permissions granted to all apps.

.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 -ApplicationPermissions -ShowProgress | Where-Object { $_.Permission -eq "Directory.Read.All" }
    Get all apps which have application permissions for Directory.Read.All.
#>
Function Get-MSCloudIdConsentGrantList
{
    [CmdletBinding()]
    param(
        [int] $PrecacheSize = 999
    )
    # An in-memory cache of objects by {object ID} andy by {object class, object ID} 
    $script:ObjectByObjectId = @{}
    $script:ObjectByObjectClassId = @{}

    # Function to add an object to the cache
    function CacheObject($Object) {
        if ($Object) {
            if (-not $script:ObjectByObjectClassId.ContainsKey($Object.ObjectType)) {
                $script:ObjectByObjectClassId[$Object.ObjectType] = @{}
            }
            $script:ObjectByObjectClassId[$Object.ObjectType][$Object.ObjectId] = $Object
            $script:ObjectByObjectId[$Object.ObjectId] = $Object
        }
    }

    # Function to retrieve an object from the cache (if it's there), or from Azure AD (if not).
    function GetObjectByObjectId($ObjectId) {
        if (-not $script:ObjectByObjectId.ContainsKey($ObjectId)) {
            Write-Verbose ("Querying Azure AD for object '{0}'" -f $ObjectId)
            try {
                $object = Get-AzureADObjectByObjectId -ObjectId $ObjectId
                CacheObject -Object $object
            } catch { 
                Write-Verbose "Object not found."
            }
        }
        return $script:ObjectByObjectId[$ObjectId]
    }
   
    # Get all ServicePrincipal objects and add to the cache
    Write-Verbose "Retrieving ServicePrincipal objects..."
    $servicePrincipals = Get-AzureADServicePrincipal -All $true 

    #there is a limitation on how Azure AD Graph retrieves the list of OAuth2PermissionGrants
    #we have to traverse all service principals and gather them separately.
    # Originally, we could have done this 
    # $Oauth2PermGrants = Get-AzureADOAuth2PermissionGrant -All $true 
    
    $Oauth2PermGrants = @()

    foreach ($sp in $servicePrincipals)
    {
        CacheObject -Object $sp
        $spPermGrants = Get-AzureADServicePrincipalOAuth2PermissionGrant -ObjectId $sp.ObjectId -All $true
        $Oauth2PermGrants += $spPermGrants
    }  

    # Get one page of User objects and add to the cache
    Write-Verbose "Retrieving User objects..."
    Get-AzureADUser -Top $PrecacheSize | ForEach-Object { CacheObject -Object $_ }

    # Get all existing OAuth2 permission grants, get the client, resource and scope details
    foreach ($grant in $Oauth2PermGrants)
    {
        if ($grant.Scope) 
        {
            $grant.Scope.Split(" ") | Where-Object { $_ } | ForEach-Object {               
                $scope = $_
                $client = GetObjectByObjectId -ObjectId $grant.ClientId
                $resource = GetObjectByObjectId -ObjectId $grant.ResourceId
                $principalDisplayName = ""
                if ($grant.PrincipalId) {
                    $principal = GetObjectByObjectId -ObjectId $grant.PrincipalId
                    $principalDisplayName = $principal.DisplayName
                }

                New-Object PSObject -Property ([ordered]@{
                    "PermissionType" = "Delegated"
                                    
                    "ClientObjectId" = $grant.ClientId
                    "ClientDisplayName" = $client.DisplayName
                    
                    "ResourceObjectId" = $grant.ResourceId
                    "ResourceDisplayName" = $resource.DisplayName
                    "Permission" = $scope

                    "ConsentType" = $grant.ConsentType
                    "PrincipalObjectId" = $grant.PrincipalId
                    "PrincipalDisplayName" = $principalDisplayName
                })
            }
        }
    }
    
    # Iterate over all ServicePrincipal objects and get app permissions
    Write-Verbose "Retrieving AppRoleAssignments..."
    $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object {
        $sp = $_.Value

        Get-AzureADServiceAppRoleAssignedTo -ObjectId $sp.ObjectId  -All $true `
        | Where-Object { $_.PrincipalType -eq "ServicePrincipal" } | ForEach-Object {
            $assignment = $_
            
            $client = GetObjectByObjectId -ObjectId $assignment.PrincipalId
            $resource = GetObjectByObjectId -ObjectId $assignment.ResourceId            
            $appRole = $resource.AppRoles | Where-Object { $_.Id -eq $assignment.Id }

            New-Object PSObject -Property ([ordered]@{
                "PermissionType" = "Application"
                
                "ClientObjectId" = $assignment.PrincipalId
                "ClientDisplayName" = $client.DisplayName
                
                "ResourceObjectId" = $assignment.ResourceId
                "ResourceDisplayName" = $resource.DisplayName
                "Permission" = $appRole.Value
            })
        }
    }
}

<# 
 .Synopsis
  Gets the list of all enabled endpoints in ADFS

 .Description
  Gets the list of all enabled endpoints in ADFS

 .Example
  Get-MSCloudIdADFSEndpoints | Export-Csv -Path ".\ADFSEnabledEndpoints.csv" 
#>
function Get-MSCloudIdADFSEndpoints
{
	Get-AdfsEndpoint | Where-Object {$_.Enabled -eq "True"} 
}


Function Remove-InvalidFileNameChars 
{
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}

<# 
 .Synopsis
  Exports the configuration of Relying Party Trusts and Claims Provider Trusts

 .Description
  Creates and zips a set of files that hold the configuration of ADFS claim providers and relying parties

 .Example
  Export-MSCloudIdADFSConfiguration
#>

Function Export-MSCloudIdADFSConfiguration
{
    $filePathBase = "C:\ADFS\apps\"
    $zipfileBase = "c:\ADFS\zip\"
    $zipfileName = $zipfileBase + "ADFSApps.zip"
    mkdir $filePathBase -ErrorAction SilentlyContinue
    mkdir $zipfileBase -ErrorAction SilentlyContinue

    $AdfsRelyingPartyTrusts = Get-AdfsRelyingPartyTrust
    foreach ($AdfsRelyingPartyTrust in $AdfsRelyingPartyTrusts)
    {
        $RPfileName = $AdfsRelyingPartyTrust.Name.ToString()
        $CleanedRPFileName = Remove-InvalidFileNameChars -Name $RPfileName
        $RPName = "RPT - " + $CleanedRPFileName
        $filePath = $filePathBase + $RPName + '.xml'
        $AdfsRelyingPartyTrust | Export-Clixml $filePath -ErrorAction SilentlyContinue
    }

    $AdfsClaimsProviderTrusts = Get-AdfsClaimsProviderTrust
    foreach ($AdfsClaimsProviderTrust in $AdfsClaimsProviderTrusts)
    {
 
        $CPfileName = $AdfsClaimsProviderTrust.Name.ToString()
        $CleanedCPFileName = Remove-InvalidFileNameChars -Name $CPfileName
        $CPTName = "CPT - " + $CleanedCPFileName
        $filePath = $filePathBase + $CPTName + '.xml'
        $AdfsClaimsProviderTrust | Export-Clixml $filePath -ErrorAction SilentlyContinue
 
    } 

    If (Test-Path $zipfileName)
    {
        Remove-Item $zipfileName
    }

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($filePathBase, $zipfileName)
    
    invoke-item $zipfileBase
}

Export-ModuleMember -Function Start-MSCloudIdSession
Export-ModuleMember -Function Get-MSCloudIdAppProxyConnectorLog
Export-ModuleMember -Function Get-MSCloudIdPasswordWritebackAgentLog
Export-ModuleMember -Function Get-MSCloudIdNotificationEmailAddresses
Export-ModuleMember -Function Get-MSCloudIdAppAssignmentReport
Export-ModuleMember -Function Get-MSCloudIdAdminRolesReport
Export-ModuleMember -Function Get-MSCloudIdConsentGrantList
Export-ModuleMember -Function Get-MSCloudIdApplicationKeyExpirationReport
Export-ModuleMember -Function Get-MSCloudIdADFSEndpoints
Export-ModuleMember -Function Export-MSCloudIdADFSConfiguration
