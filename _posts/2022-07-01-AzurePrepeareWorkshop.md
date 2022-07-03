---
title: Azure Cloud prepare Workshops
author: Janusz Nowak
header:
  teaser: /wp-content/uploads/2022/AzurePrepareWorkshop.webp
permalink: /post/Azure_Prepare_For_Cloud_Workshops
categories:
  - Event
  - Community
  - Conference
  - Event
  - Workshop
tags:
  - Azure
  - Event
  - Community
  - Code
---

It is happening from time to time that you want to share your passion and knowledge about Azure Cloud with community on workshops.
![AzurePrepareWorkshop](/wp-content/uploads/2022/AzurePrepareWorkshop.webp)
First issues that you are struggling is that starting can be painfully, as people need to have [Azure Subscription](https://docs.microsoft.com/en-us/microsoft-365/enterprise/subscriptions-licenses-accounts-and-tenants-for-microsoft-cloud-offerings?view=o365-worldwide), [Azure Tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-create-new-tenant), connect payment card even for free [Azure Subscription](https://azure.microsoft.com/en-us/free/) as afraid to pay, go with whole process.
Even when all participants have [azure pass](https://www.microsoftazurepass.com/) they are struggling with issues as using all ready used email, use production tenant. One of the approach when each of participants on Azure Cloud workshops can not have their own Azure Subscription is to create, shared subscription.

When we care new subscription and tenant, create new workshops users and service principals and created dedicated resource group with corresponding access.

```powershell
$SubscriptionId=70bb294e-ef4d-4058-aca9-7c28117a958a
$domain="wit2022.onmicrosoft.com"

Connect-AzAccount -Tenant $domain
Select-AzSubscription -SubscriptionId  $SubscriptionId

Import-Module AzureAD
Connect-AzureAD -TenantDomain $domain

$login_prefix="user"
$password='Changeme1#'
$howManyCreate=100

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "ChangeMe1#"
$PasswordProfile.ForceChangePasswordNextLogin = $true
$array = @()
For ($i=2; $i -le $howManyCreate ; $i++)
{
    $user=$login_prefix+$i+"@"+$domain
    # create user
    $u=New-AzureADUser -DisplayName $user -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $login_prefix+$i -UserPrincipalName $user

    $sp=$login_prefix+$i
    # create service principal for AppId and $s.PasswordCredentials.SecretText, valid 10 days
    $s = New-AzAdServicePrincipal -DisplayName $sp -EndDate (Get-Date).AddDays(10) -StartDate $(Get-Date)

    # If need to create new secret for Application $aadAppsecret01.Value
    #$aadAppsecret01 = New-AzureADApplicationPasswordCredential -ObjectId $($s.AppId) -CustomKeyIdentifier "secret01" -StartDate $(Get-Date) -EndDate (Get-Date).AddDays(10)

    # Create resource group
    $rg=New-AzResourceGroup -Location westeurope -Name RG-user$i -Force

    # Assign user and service principal permissions for Resouce Group
    New-AzRoleAssignment -ObjectId $($u.ObjectId)  -RoleDefinitionName 'Owner' -ResourceGroupName $rg.ResourceGroupName
    New-AzRoleAssignment -ApplicationId $($s.AppId) -RoleDefinitionName 'Owner' -ResourceGroupName $rg.ResourceGroupName

    # Create object for get all information is nice output
    $object = New-Object -TypeName PSObject
    $object | Add-Member -Name 'user' -MemberType Noteproperty -Value $user
    $object | Add-Member -Name 'password' -MemberType Noteproperty -Value $PasswordProfile.Password
    $object | Add-Member -Name 'spAppId' -MemberType Noteproperty -Value $s.AppId
    $object | Add-Member -Name 'spSecret' -MemberType Noteproperty -Value $s.PasswordCredentials.SecretText
    $object | Add-Member -Name 'rgName' -MemberType Noteproperty -Value $rg.ResourceGroupName.ToString()
    $array += $object
}

$array | Format-Table
$array | Out-GridView
```

## Result

As result of script we will get this table, where we can share it with participants of workshops

| user                          | password   | spAppId                              | spSecret                                 | rgName   |
| ----------------------------- | ---------- | ------------------------------------ | ---------------------------------------- | -------- |
| user0@wit2022.onmicrosoft.com | ChangeMe1# | 5dfa5984-a665-406e-bb88-e4370d0edb1e | Obx8Q~ADxwkIfAL-ZsATG2sRrjBNDyASDASDASDA | RG-user0 |
| user1@wit2022.onmicrosoft.com | ChangeMe1# | 28b8025c-357e-4de0-ae1b-fed6ae1bcec3 | L~I8Q~O~rmBluvQBWC1QdUjwko2Fo~ASDASDASDA | RG-user1 |

## Clean up

When we are done we can remove all created objects

```powershell
Get-AzureADApplication|Remove-AzureADApplication
Get-AzureADUser -SearchString user|Remove-AzureADUser
Get-AzResourceGroup -Name Rg-user*|Remove-AzResourceGroup -Force
```
