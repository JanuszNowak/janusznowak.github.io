---
title: Azure Bicep Modules
author: Janusz Nowak
header:
  teaser: /wp-content/uploads/2022/AzureBicepModules.webp
permalink: /post/Azure_Bicep_Modules
  - Azure
  - Bicep
tags:
  - Azure
  - Bicep
  - IoC
  - Azure DevOps
  - Azure Pipelines
  - Code
  - Yaml
  - Continuous Delivery
  - Continuous Deployment
  - Pull Request
  - Continuous Integration
---

On previous [posts](./tags/#bicep) we have been introduced, how to get started, use extension or migrate from ARM templates for azure bicep or how to use in Continuous Delivery/Continuous Deployment, also how to validate Azure Bicep on Pull Requests/Branch protection.

![Azure_Bicep_Modules](/wp-content/uploads/2022/Azure_Bicep_Modules.webp)

# Azure Bicep Modules

On current one I will cover that Azure Bicep enables you to organize deployments into modules. A module is a Bicep file (or an ARM JSON template) that is deployed from another Bicep file. With modules, you improve the readability of your Bicep files by encapsulating complex details of your deployment. You can also easily reuse modules for different deployments.

## Azure Bicep Modules Sharing

We have three options to share modules:

- [template spec](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/template-specs?tabs=azure-powershell)
  - can be deployed directly from the API, Azure PowerShell, Azure CLI, and the Azure portal, [UiFormDefinition](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-specs-create-portal-forms)
- [public modules registry](https://github.com/Azure/bicep-registry-modules)
  - only supported by Bicep
- [private modules registry](https://github.com/Azure/bicep-registry-modules)
  - only supported by Bicep

<!-- ## Module definition -->
