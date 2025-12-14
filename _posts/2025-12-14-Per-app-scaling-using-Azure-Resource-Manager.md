---
title: Per-app scaling using Azure Resource Manager
author: Janusz Nowak
header:
  teaser: /wp-content/uploads/2025/azure-app-service-per-app-scaling.webp
permalink: /post/Per-app-scaling-using-Azure-Resource-Manager
categories:
  - Azure
  - App Service
tags:
  - Azure
  - App Service
  - PowerShell
  - ARM
  - Scaling
---

# Per-app scaling using Azure Resource Manager

Implement per-app scaling for high-density hosting in Azure App Service.

> **Note**
>
> We recommend that you use the Azure Az PowerShell module to interact with Azure. To get started, see [Install Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps). To learn how to migrate to the Az PowerShell module, see [Migrate Azure PowerShell from AzureRM to Az](https://learn.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az).

For more detailed information, see the [official Microsoft documentation on per-app scaling](https://learn.microsoft.com/en-us/azure/app-service/manage-scale-per-app).

## Overview

You can scale your Azure App Service apps by scaling the App Service plan they run on. When multiple apps run in the same App Service plan, each scaled-out instance runs all the apps in the plan.

In contrast, per-app scaling can be enabled at the App Service plan level to scale an app independently from the App Service plan that hosts it. This way, an App Service plan can be scaled to 10 instances, but an app can be set to use only five.

> **Note**
>
> Per-app scaling is available only for **Standard**, **Premium**, **Premium V2**, **Premium V3**, and **Isolated** pricing tiers.

## Service Scenarios and Benefits

### Key Scenarios

Per-app scaling is particularly useful in the following scenarios:

1. **Multi-tenant Applications**: When hosting multiple customer applications in a single App Service plan, you can allocate different resources to each customer based on their tier or usage patterns.

2. **Mixed Workload Environments**: Applications with different resource requirements can coexist in the same plan. For example, a resource-intensive API can be limited to fewer instances while a lightweight web app can scale to more instances.

3. **Cost Optimization**: Maximize resource utilization by running multiple apps on a single App Service plan while still maintaining granular control over each app's scale.

4. **Development and Testing**: Run production, staging, and development versions of an app in the same plan with different scaling configurations.

### Benefits

- **Improved Resource Utilization**: Optimize costs by hosting multiple apps on fewer App Service plans while maintaining performance
- **Better Isolation**: Prevent one app from consuming all available instances in a shared plan
- **Flexible Scaling**: Each app can scale independently based on its specific needs
- **Simplified Management**: Manage multiple apps in a single plan with individual scaling policies
- **Cost Efficiency**: Reduce infrastructure costs while maintaining granular control over app resources

## App Allocation

Apps are allocated to the available App Service plan using a best-effort approach for an even distribution across instances. While an even distribution isn't guaranteed, the platform makes sure that two instances of the same app aren't hosted on the same App Service plan instance.

The platform doesn't rely on metrics to decide on worker allocation. Applications are rebalanced only when instances are added or removed from the App Service plan.

## Per-app scaling using PowerShell

### Create a plan with per-app scaling

Create a plan with per-app scaling by passing in the `-PerSiteScaling $true` parameter to the `New-AzAppServicePlan` cmdlet.

```powershell
New-AzAppServicePlan -ResourceGroupName $ResourceGroup -Name $AppServicePlan `
                            -Location $Location `
                            -Tier Premium -WorkerSize Small `
                            -NumberofWorkers 5 -PerSiteScaling $true
```

### Enable per-app scaling with an existing App Service Plan

Enable per-app scaling with an existing App Service Plan by passing in the `-PerSiteScaling $true` parameter to the `Set-AzAppServicePlan` cmdlet.

```powershell
Set-AzAppServicePlan -ResourceGroupName $ResourceGroup `
   -Name $AppServicePlan -PerSiteScaling $true
```

### Configure app-level scaling

At the app level, configure the number of instances the app can use in the App Service plan.

In the following example, the app is limited to two instances regardless of how many instances the underlying app service plan scales out to.

```powershell
# Get the app we want to configure to use "PerSiteScaling"
$newapp = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $webapp

# Modify the NumberOfWorkers setting to the desired value
$newapp.SiteConfig.NumberOfWorkers = 2

# Post updated app back to Azure
Set-AzWebApp $newapp
```

> **Important**
>
> `$newapp.SiteConfig.NumberOfWorkers` is different from `$newapp.MaxNumberOfWorkers`. Per-app scaling uses `$newapp.SiteConfig.NumberOfWorkers` to determine the scale characteristics of the app.

## Per-app scaling using Azure Resource Manager

The following Azure Resource Manager template creates:

- An App Service plan that's scaled out to 10 instances
- An app that's configured to scale to a maximum of five instances

The App Service plan is setting the **PerSiteScaling** property to true `"perSiteScaling": true`. The app is setting the **number of workers** to use to 5 `"properties": { "numberOfWorkers": 5 }`.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "appServicePlanName": {
            "type": "string",
            "metadata": {
                "description": "Name of the App Service Plan"
            }
        },
        "webAppName": {
            "type": "string",
            "metadata": {
                "description": "Name of the Web App"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Location for all resources"
            }
        }
    },
    "resources": [
        {
            "type": "Microsoft.Web/serverfarms",
            "apiVersion": "2022-03-01",
            "name": "[parameters('appServicePlanName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "P1",
                "tier": "Premium",
                "capacity": 10
            },
            "properties": {
                "perSiteScaling": true
            }
        },
        {
            "type": "Microsoft.Web/sites",
            "apiVersion": "2022-03-01",
            "name": "[parameters('webAppName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]"
            ],
            "properties": {
                "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                "siteConfig": {
                    "numberOfWorkers": 5
                }
            }
        }
    ],
    "outputs": {
        "webAppUrl": {
            "type": "string",
            "value": "[concat('https://', reference(resourceId('Microsoft.Web/sites', parameters('webAppName'))).defaultHostName)]"
        }
    }
}
```

## Summary

Per-app scaling in Azure App Service provides fine-grained control over resource allocation in high-density hosting scenarios. By enabling this feature, you can optimize costs while maintaining the performance and isolation requirements of individual applications. Whether you're using PowerShell or Azure Resource Manager templates, implementing per-app scaling is straightforward and offers significant benefits for multi-tenant and mixed workload environments.

## References

- [Manage per-app scaling - Microsoft Learn](https://learn.microsoft.com/en-us/azure/app-service/manage-scale-per-app)
- [Azure App Service plan overview](https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans)
- [Scale up an app in Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/manage-scale-up)
