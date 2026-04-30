---
layout: post
title: "Azure AI Foundry Local — AI on your terms, on your hardware"
date: 2025-05-01
categories:
  - Azure
  - AI
  - DevOps
tags:
  - Azure
  - AI
  - FoundryLocal
  - AzureLocal
  - OnPremises
  - DevOps
  - MLOps
  - Kubernetes
  - InfrastructureAsCode
comments: true
---

I have been running infrastructure for a long time. 20 years of "it works on my machine" jokes, 18 years of DevOps practice, and roughly a decade of Azure. The one pattern I keep seeing repeat itself — with containers, with Kubernetes, with serverless — is that every powerful cloud technology eventually needs to run closer to where the data actually lives. AI is no different.

Azure AI Foundry Local is Microsoft's answer to that inevitability. It lets you run AI model inference entirely on infrastructure you control — on-premises, on edge nodes, on a laptop, or inside an air-gapped datacenter — while still using the same developer tooling, the same OpenAI-compatible REST API, and the same governance model you already know from Azure.

This post is a practitioner's look at what it is, why it matters, and where it actually makes sense to use it.

---

## What is Azure AI Foundry Local?

Azure AI Foundry is Microsoft's unified platform for building, deploying, and governing AI applications. The **Local** variant extends this platform to run model inference outside Azure public regions — on Azure Local (Arc-enabled Kubernetes clusters you operate), and on individual devices running Windows, macOS, Android, and more.

The architecture is deliberately layered:

```
Microsoft Foundry (Cloud)
  └── Frontier models, fine-tuning, agent service, full platform
Azure Local + Foundry Local (On-Premises / Hybrid)
  └── Arc-enabled Kubernetes, operator-managed model lifecycle
Foundry Local (Device)
  └── Windows / macOS / Android, zero-dependency, bundleable
```

At the on-premises tier — which is what I will focus on here — Foundry Local runs on an Arc-enabled Kubernetes cluster managed through Azure Arc. You define models declaratively as Kubernetes custom resources (`Model`, `ModelDeployment`). The inference operator watches cluster state and handles the full lifecycle: catalog sync, scaling, endpoint exposure, TLS, API key auth.

From an application perspective, you hit an OpenAI-compatible REST endpoint. Swap the base URL and you are done. No SDK changes. No rewiring your agents.

---

## Why would you actually need this?

Let me be direct: if your data is not sensitive, your latency is acceptable, and you have no regulatory constraints, the cloud version of Foundry is almost certainly the better choice. Managed, cheaper to operate, no infra burden.

But there are real scenarios where local deployment is not just nice to have — it is a hard requirement.

### Use Case 1 — Financial services and regulated data

You are processing trade data, KYC documents, or credit scoring inputs. The data classification policy says this data cannot leave your datacenter boundary. Full stop. Cloud-based inference is blocked at the architecture review board before you even write the first line of code.

Foundry Local on Azure Local gives you a compliant path: model inference runs on your own hardware, data never transits a public network, and you can still build modern AI-powered features on top of it. The Arc control plane gives your cloud team governance and visibility without the data leaving.

### Use Case 2 — Healthcare and HIPAA / RODO environments

A hospital system wants to run an AI-assisted clinical decision support tool. Patient records are involved. Sending that data to a cloud endpoint — even an encrypted one — triggers a legal and compliance review that could kill the project timeline.

Running the model locally removes that blocker. The AI workload is another on-premises service like any other. You control the audit trail, the data residency, and the access policy.

### Use Case 3 — Manufacturing floor and edge scenarios

A factory has vision-based quality inspection running on a production line. Internet connectivity is unreliable. Round-trip latency to a cloud endpoint would introduce unacceptable delay — or simply fail when the uplink drops.

Foundry Local is designed for this. Disconnected operations are a first-class scenario. The inference endpoint runs on local compute, catalog sync happens during maintenance windows, and the line keeps running regardless of WAN availability.

### Use Case 4 — Sovereign cloud and government

Government agencies in the EU and elsewhere operate under strict data sovereignty requirements. Azure sovereign cloud regions exist, but for many classified or sensitive workloads even those are insufficient. Foundry Local on Azure Local, integrated with sovereign-compliant Arc environments, provides a path.

### Use Case 5 — Developer inner loop and cost control

This one is underrated. Running large model inference in the cloud costs money, accumulates fast during development, and adds latency to every iteration. Foundry Local on a developer machine (Windows or macOS) gives the same API surface locally. Zero cloud spend. Sub-millisecond round trips. No quota limits blocking a sprint demo.

You can build against the local endpoint and swap to the cloud deployment for production. Same code. Same SDK. The base URL is an environment variable.

### Use Case 6 — CI/CD pipeline isolation

Your AI application has integration tests that call an inference endpoint. Running those tests against a shared cloud deployment introduces flakiness (rate limits, quota, latency variation) and cost. Running them against a local Foundry endpoint in the pipeline agent gives you deterministic, fast, free test execution. I have been pushing for this pattern with pipeline agents on Proxmox LXC for a while — Foundry Local slots in cleanly.

### Use Case 7 — Quick local proof of concept in 5 minutes

You want to show something to a stakeholder, validate an idea, or just answer the question "can this model actually do X?" — without creating an Azure subscription, waiting for quota approval, or writing any infrastructure code.

Install Foundry Local, pull phi-3-mini, ask it something. That is it.

```bash
# Install on Windows
winget install Microsoft.FoundryLocal

# Pull a small but capable model (~2 GB)
foundry model pull microsoft/phi-3-mini-4k-instruct

# Ask it something useful right now
foundry model run microsoft/phi-3-mini-4k-instruct \
  --prompt "Explain Azure DORA metrics in 3 bullet points"
```

Or if you already have your app wired to the OpenAI SDK:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:5273/v1",
    api_key="local"  # any non-empty string works
)

response = client.chat.completions.create(
    model="phi-3-mini-4k-instruct",
    messages=[{"role": "user", "content": "What is lead time for changes?"}]
)
print(response.choices[0].message.content)
```

No Azure account needed. No cost. No network. Works on a train, in a hotel, at a conference with sketchy Wi-Fi. This is the fastest path from "I want to experiment with AI" to a running inference endpoint — and the code you write against it is identical to what will run in production against Foundry in the cloud.

---

## Architecture on Azure Local

For on-premises deployments the stack looks like this:

```
Azure Local (HCI / on-prem hardware)
  ├── Arc-enabled Kubernetes cluster
  │     ├── Inference Operator (Foundry control plane)
  │     ├── Model CRDs        (catalog + availability)
  │     └── ModelDeployment   (runtime intent, scaling, endpoint)
  ├── GPU or CPU nodes         (execution profile)
  ├── TLS Ingress              (secure endpoint access)
  └── API Key Auth             (bearer token per deployment)

Azure Arc (management plane — no data plane traffic)
  ├── Policy and governance
  ├── Extension lifecycle
  └── Observability (OTel, metrics, traces)
```

The key architectural principle: **Arc manages, data stays local**. The management plane communicates with Azure Arc over standard outbound HTTPS. Inference traffic — the actual prompts and responses — never leaves your cluster.

Model lifecycle management is fully declarative:

```yaml
apiVersion: foundry.azure.com/v1alpha1
kind: ModelDeployment
metadata:
  name: phi-3-mini-local
spec:
  modelId: microsoft/phi-3-mini-4k-instruct
  scalingProfile: standard
  endpoint:
    expose: true
    auth:
      type: apiKey
```

Apply it, the operator handles the rest. Consistent, auditable, GitOps-friendly. This is Infrastructure as Code for AI workloads.

---

## Getting started on a developer machine

For local dev the entry point is simpler. Install Foundry Local, pull a model, run inference:

```bash
# Install (Windows, via winget)
winget install Microsoft.FoundryLocal

# Verify the service is running
foundry service status

# Pull and run a model
foundry model run microsoft/phi-3-mini-4k-instruct

# Hit the OpenAI-compatible endpoint
curl http://localhost:5273/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi-3-mini-4k-instruct",
    "messages": [{"role": "user", "content": "What is DORA?"}]
  }'
```

The endpoint is OpenAI-compatible. Any application built against the OpenAI SDK works immediately — point `AZURE_OPENAI_ENDPOINT` at localhost and the app has no idea it is running local inference.

For GPU acceleration: hardware with a supported NVIDIA, AMD, or Intel GPU (or NPU) will be detected automatically. On CPU-only hardware it still works, just slower for larger models. For most phi-3 mini scenarios on a modern developer laptop, CPU inference is fine for inner-loop work.

---

## Integration with DevOps pipelines

This is where it gets interesting for CI/CD. Add Foundry Local to your Azure DevOps or GitHub Actions pipeline agent (containerised or LXC-based) and your AI integration tests run locally — no cloud dependency, no quota management, no test costs.

A simple Azure Pipelines setup:

```yaml
steps:
  - script: |
      winget install Microsoft.FoundryLocal --silent
      foundry model pull microsoft/phi-3-mini-4k-instruct
      foundry service start
    displayName: 'Start Foundry Local'

  - script: dotnet test ./src/AI.IntegrationTests
    env:
      OPENAI_BASE_URL: http://localhost:5273/v1
      OPENAI_API_KEY: local
    displayName: 'Run AI integration tests'

  - script: foundry service stop
    displayName: 'Stop Foundry Local'
    condition: always()
```

You get reproducible, cost-free AI integration testing on every PR. This is the same "deploy anything to anywhere" philosophy applied to the AI layer.

---

## What to watch out for

A few things from practical experience that are worth flagging:

**Hardware sizing matters a lot.** Running phi-3-mini locally on a developer machine with 16 GB RAM is fine. Running larger models (Mistral, Llama 3 70B) on commodity hardware is painful. Know your model size before committing to a hardware spec.

**Preview status.** Foundry Local on Azure Local is in preview and currently requires access request approval. Factor that into delivery timelines if you are planning a production rollout.

**Operational overhead.** You are trading cloud operational burden for on-premises operational burden. GPU drivers, Kubernetes node maintenance, model update cadence — that is now your team's problem. Make sure that tradeoff is actually justified by your requirements.

**Not a replacement for Foundry cloud.** Fine-tuning, the full Agent Service with Responses API, advanced evaluation, frontier model access — those remain cloud-only features. Local is for inference at the edge or in regulated environments. Design your architecture accordingly.

---

## Summary

Azure AI Foundry Local solves a real problem that a lot of enterprise teams run into the moment they try to take AI seriously in regulated or latency-sensitive environments. It is not for everyone — if your data can live in Azure, the cloud platform is the right choice. But when data sovereignty, compliance, disconnected operation, or cost control on inner-loop dev work are genuine constraints, having a local inference endpoint that is fully consistent with your cloud tooling is a significant advantage.

The OpenAI-compatible API means adoption friction is near zero for teams already using the Azure OpenAI SDK. The Kubernetes-native deployment model on Azure Local means your platform team can manage it like any other workload — declarative, GitOps-friendly, Arc-governed.

The pattern is familiar: same concept as running Azure Arc for servers, Azure Arc for data, or Azure Stack HCI — Azure's management and developer experience, running on your hardware. Foundry Local is just that model applied to AI inference.

Worth exploring if you are hitting the ceiling on what cloud-only AI can do for your architecture.

---

**Useful links:**
- [What is Foundry Local on Azure Local — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sovereign-clouds/private/foundry-local/what-is-foundry-local-on-azure-local?wt_mc_id=AZ-MVP-5005297)
- [Microsoft Foundry Blog](https://devblogs.microsoft.com/foundry/)
- [Azure AI Foundry — Deployment Overview](https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/deployments-overview?wt_mc_id=AZ-MVP-5005297)
- [Request preview access — Foundry Local on Azure Local](https://learn.microsoft.com/en-us/azure/azure-sovereign-clouds/private/foundry-local/what-is-foundry-local-on-azure-local?wt_mc_id=AZ-MVP-5005297)
