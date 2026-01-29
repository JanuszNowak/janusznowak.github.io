---
title: Monitor Azure Service Principal Password Expiration with PowerShell
author: Janusz Nowak
header:
  teaser: /wp-content/uploads/2026/azure-spn-password-monitoring.webp
permalink: /post/Monitor-Azure-Service-Principal-Password-Expiration
categories:
  - Azure
  - PowerShell
  - Security
  - Microsoft Graph
tags:
  - Azure
  - PowerShell
  - Service Principal
  - Microsoft Graph
  - Security
  - Monitoring
---

Managing Service Principal (SPN) credentials is a critical aspect of Azure security. Expired passwords can cause service disruptions, while timely monitoring helps maintain operational continuity and security compliance. This article demonstrates how to use Azure PowerShell with Microsoft Graph to monitor all existing password credentials on Service Principals and their expiration status.

## Overview

Service Principals in Azure are identities used by applications, services, and automation tools to access Azure resources. These identities often use password credentials (client secrets) that have expiration dates. Monitoring these expiration dates is crucial for:

- **Preventing Service Disruptions**: Avoid application failures due to expired credentials
- **Security Compliance**: Ensure regular credential rotation according to security policies
- **Proactive Management**: Get advance notice before credentials expire
- **Audit and Reporting**: Maintain visibility of all credential expiration dates

## Prerequisites

Before running the monitoring script, ensure you have:

1. **Azure PowerShell Module**: Install the Microsoft Graph PowerShell SDK
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

2. **Required Permissions**: You need the following Microsoft Graph API permission:
   - `Application.Read.All` - To read Service Principal and application information

3. **Appropriate Azure Role**: Ensure your account has sufficient permissions to read Service Principal information (e.g., Application Administrator, Cloud Application Administrator, or Global Administrator)

## The Monitoring Script

Here's a comprehensive PowerShell script that connects to Microsoft Graph, retrieves all Service Principals with password credentials, and generates an expiration report:

```powershell
# Connect to Microsoft Graph if not already connected
if (!(Get-MgContext)) { Connect-MgGraph -Scopes "Application.Read.All" }

# Get all Service Principals with password credentials
$allSPNs = Get-MgServicePrincipal -All -Property "Id", "DisplayName", "AppId", "PasswordCredentials"

$report = foreach ($spn in $allSPNs) {
    foreach ($credential in $spn.PasswordCredentials) {
        $expiryDate = $credential.EndDateTime
        $daysLeft = ($expiryDate - (Get-Date)).Days
        
        [PSCustomObject]@{
            DisplayName    = $spn.DisplayName
            AppId          = $spn.AppId
            KeyId          = $credential.KeyId
            ExpirationDate = $expiryDate
            DaysRemaining  = $daysLeft
            Status         = if ($daysLeft -le 0) { "Expired" } elseif ($daysLeft -le 30) { "Urgent" } else { "Healthy" }
        }
    }
}

# Display results in a sortable table
$report | Sort-Object DaysRemaining | Out-GridView -Title "SPN Secret Expiration Report"
```

## Understanding the Script

Let's break down what each section of the script does:

### 1. Authentication
```powershell
if (!(Get-MgContext)) { Connect-MgGraph -Scopes "Application.Read.All" }
```
This checks if you're already connected to Microsoft Graph. If not, it prompts for authentication with the required scope to read application information.

### 2. Retrieve Service Principals
```powershell
$allSPNs = Get-MgServicePrincipal -All -Property "Id", "DisplayName", "AppId", "PasswordCredentials"
```
This retrieves all Service Principals in your tenant, specifically requesting the properties we need for our report.

### 3. Generate Report
The script iterates through each Service Principal and its password credentials, creating a custom object with:
- **DisplayName**: The friendly name of the Service Principal
- **AppId**: The unique application ID
- **KeyId**: The unique identifier for the specific credential
- **ExpirationDate**: When the credential expires
- **DaysRemaining**: Number of days until expiration
- **Status**: Categorized as "Expired" (≤0 days), "Urgent" (≤30 days), or "Healthy" (>30 days)

### 4. Display Results
```powershell
$report | Sort-Object DaysRemaining | Out-GridView -Title "SPN Secret Expiration Report"
```
Results are sorted by days remaining and displayed in an interactive grid view for easy filtering and sorting.

## Setting Up Notifications

To make this monitoring solution more proactive, you can extend it to send notifications. Here are several approaches:

### Option 1: Email Notifications with Send-MailMessage

```powershell
# Filter for credentials expiring soon or already expired
$criticalCreds = $report | Where-Object { $_.DaysRemaining -le 30 }

if ($criticalCreds.Count -gt 0) {
    $emailBody = $criticalCreds | ConvertTo-Html -Property DisplayName, AppId, ExpirationDate, DaysRemaining, Status | Out-String
    
    $mailParams = @{
        To         = "admin@yourdomain.com"
        From       = "azure-monitoring@yourdomain.com"
        Subject    = "⚠️ Azure SPN Credentials Expiring Soon"
        Body       = $emailBody
        BodyAsHtml = $true
        SmtpServer = "smtp.yourdomain.com"
    }
    
    Send-MailMessage @mailParams
}
```

### Option 2: Microsoft Teams Webhook

```powershell
$criticalCreds = $report | Where-Object { $_.DaysRemaining -le 30 }

if ($criticalCreds.Count -gt 0) {
    $teamsWebhook = "YOUR_TEAMS_WEBHOOK_URL"
    
    $messageCard = @{
        "@type"    = "MessageCard"
        "@context" = "https://schema.org/extensions"
        summary    = "SPN Credentials Expiring"
        themeColor = "FF0000"
        title      = "⚠️ Service Principal Credentials Expiring Soon"
        sections   = @(
            @{
                facts = $criticalCreds | ForEach-Object {
                    @{
                        name  = $_.DisplayName
                        value = "Expires in $($_.DaysRemaining) days - $($_.ExpirationDate.ToString('yyyy-MM-dd'))"
                    }
                }
            }
        )
    }
    
    Invoke-RestMethod -Uri $teamsWebhook -Method Post -Body ($messageCard | ConvertTo-Json -Depth 10) -ContentType "application/json"
}
```

### Option 3: Azure Logic Apps Integration

For a more robust solution, export the report to a file and trigger an Azure Logic App:

```powershell
# Export to CSV
$report | Export-Csv -Path "spn-expiration-report.csv" -NoTypeInformation

# Or export to JSON for Logic App consumption
$report | ConvertTo-Json -Depth 10 | Out-File "spn-expiration-report.json"
```

You can then create an Azure Logic App that:
1. Triggers on a schedule or file upload to Azure Storage
2. Reads the report data
3. Sends notifications via email, Teams, or ServiceNow
4. Creates tickets for expired or soon-to-expire credentials

## Automation with Azure Automation

To run this monitoring automatically, deploy it as an Azure Automation Runbook:

1. **Create an Automation Account** in the Azure Portal
2. **Configure Managed Identity** with the required Microsoft Graph permissions
3. **Create a Runbook** with the monitoring script
4. **Schedule the Runbook** to run daily or weekly

Example runbook script:

```powershell
# Connect using Managed Identity
Connect-MgGraph -Identity

# Rest of your monitoring script here
$allSPNs = Get-MgServicePrincipal -All -Property "Id", "DisplayName", "AppId", "PasswordCredentials"

# ... (complete script from above)

# Export results to Automation Account output
Write-Output "Report generated: $($report.Count) credentials monitored"
Write-Output "Expired: $(($report | Where-Object {$_.Status -eq 'Expired'}).Count)"
Write-Output "Urgent: $(($report | Where-Object {$_.Status -eq 'Urgent'}).Count)"
```

## Best Practices

1. **Regular Monitoring**: Run the script at least weekly to catch expiring credentials in time
2. **Advance Notice**: Set your "Urgent" threshold based on your organization's credential rotation process time (e.g., 60 days if the approval process takes weeks)
3. **Automated Rotation**: Consider implementing automated credential rotation for non-critical applications
4. **Audit Trail**: Keep historical reports to demonstrate compliance and track credential management
5. **Least Privilege**: Use the minimum required permissions (`Application.Read.All` is read-only)
6. **Multiple Notification Channels**: Implement redundant notification methods to ensure alerts are received

## Troubleshooting

### Common Issues

**Issue**: "Insufficient privileges to complete the operation"
- **Solution**: Ensure your account has the `Application.Read.All` permission granted and admin consent is given

**Issue**: Script runs but returns no results
- **Solution**: Verify that Service Principals actually have password credentials configured. Some SPNs only use certificate credentials or managed identities

**Issue**: Out-GridView doesn't display
- **Solution**: On Windows Server Core or Linux, use alternative output methods like `Format-Table` or export to CSV

## Conclusion

Monitoring Service Principal password expiration is essential for maintaining secure and reliable Azure operations. By implementing this PowerShell-based monitoring solution with automated notifications, you can proactively manage credential lifecycles and prevent service disruptions.

The script provided gives you a solid foundation that can be extended with:
- Custom notification logic
- Integration with ITSM tools
- Automated credential rotation workflows
- Compliance reporting

Remember to regularly review and update your Service Principal credentials as part of your overall security hygiene practices.

## Additional Resources

- [Microsoft Graph PowerShell SDK Documentation](https://learn.microsoft.com/en-us/powershell/microsoftgraph/)
- [Service Principals in Azure AD](https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Best practices for application credentials](https://learn.microsoft.com/en-us/azure/active-directory/develop/security-best-practices-for-app-registration)
- [Azure Automation Documentation](https://learn.microsoft.com/en-us/azure/automation/)
