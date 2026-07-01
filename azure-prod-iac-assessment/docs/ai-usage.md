# AI Usage Note

I used AI assistance as a drafting and review aid for this assessment. The AI tool helped with:

- Creating an initial repository structure
- Drafting Terraform resource patterns for Azure VM, VNet, NSG, Key Vault, and Azure Monitor alerting
- Drafting README and operational runbook content
- Reviewing the wording for clarity and handoff readiness

I did not use AI to insert secrets, credentials, or customer-specific information. All Terraform inputs that could be sensitive, such as SSH public keys and alert email addresses, are passed through variables or environment variables. I reviewed the generated content and adjusted it to align with the assessment requirements, least-privilege access, no hardcoded secrets, and operational usability.
