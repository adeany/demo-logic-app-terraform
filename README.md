# demo-logicapp-terraform

This project includes two Terraform templates for [Azure Logic Apps](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-overview):

### [tf-logicapp-private](/tf-logicapp-private/)

Creates a virtual network and private Azure Logic App (Standard) within that network for private-only access.

To facilitate testing, it also creates a VM jump host.

### [tf-logicapp-consumption](/tf-logicapp-consumption/)

Creates a simple Logic App (Consumption) workflow with no network restrictions.


### [tf-logicapp-defender-connection](/tf-logicapp-defender-connection/)

Creates a simple Logic App (Consumption) workflow that is connected to a Microsoft Defender for Cloud Recommendation.