# Bus Inspection Marketing Brief

## Working Product Definition

Bus Inspection is BusDK's product line for local site inspection, observation,
action-list, and report workflows. It gives inspection teams a workspace-local
portal for managing customers, sites, inspection packages, role-scoped access,
manager inspection work, customer acknowledgements, photos, generated reports,
and AI-assisted configuration.

The current market focus should stay on recurring technical and site inspection
work. The product should not claim to handle every possible inspection domain
until those workflows have been proven. The strongest current story is a
deterministic local portal for inspection service providers, site operators,
and facility teams that need auditable reports and customer-visible action
tracking.

## Short Positioning

We help inspection service providers and site operators turn recurring site
inspections into auditable reports and customer-visible action lists, unlike
spreadsheets, paper forms, shared folders, or generic form tools, because Bus
Inspection keeps inspections, observations, photos, customer comments,
acknowledgements, and report exports together in deterministic workspace-local
data.

## Core Questions

### Goal

The immediate marketing goal should be qualified pilots and demos. Bus
Inspection is workflow-specific enough that the first conversion should usually
be a serious evaluation, sample report review, or guided demo rather than a
generic self-service signup.

The product page should convert visitors into one of these outcomes:

- Request a pilot for an inspection workflow.
- Book a demo with their own inspection/report process in mind.
- Review a sample inspection report and action-list export.
- Understand whether local workspace data and role-scoped access fit their
  organization.

Secondary goals are product understanding among site operators, inspection
service providers, and technical decision-makers who need operational evidence,
customer visibility, and repeatable reporting.

### Audience

Primary audience:

- Inspection service providers that manage recurring customer site checks.
- Site operators and facility teams responsible for technical inspection
  records.
- Maintenance, safety, or operations managers who need action-list follow-up.
- Organizations that send customer-facing inspection reports with photos,
  observations, due dates, and acknowledgements.
- Teams in regulated or evidence-heavy environments where old inspections,
  report snapshots, and customer responses matter.

The current product language and workflows also suggest a strong early fit for
Finnish technical inspection work, including käytönjohtaja-style site reporting.
That should be treated as a concrete beachhead, not as the only possible long-
term market.

### Problem

Inspection work often breaks across disconnected tools:

- Site details live in one spreadsheet.
- Inspection notes live in forms, documents, or email.
- Photos are stored in folders or message threads.
- Action items are copied manually into reports.
- Customers acknowledge or comment through email instead of a controlled flow.
- Previous inspection values are difficult to compare during the next visit.
- Final PDF/DOCX reports are disconnected from the data and configuration that
  produced them.

This creates operational drag and weak auditability. Teams may complete the
inspection, but later struggle to prove what was inspected, what was found, who
acknowledged it, what report was sent, and what changed between rounds.

### Offer

Bus Inspection offers a local inspection portal for BusDK workspaces:

- Customer, site, contact, report-package, and user administration.
- Role-scoped visibility for admins, managers, customers, and configuration
  users.
- Inspection creation with report metadata.
- Dossier and section values pinned to a published configuration version.
- Previous-inspection comparison during data entry.
- Rolling action lists with observation classes, statuses, notes, event
  history, due/resolution metadata, and customer acknowledgement.
- Photo attachment handling with inline previews.
- Cross-site observation filtering by site, status, date, and category.
- Snapshot-based PDF exports for inspection reports and action lists.
- DOCX export for inspection reports.
- AI-assisted configuration requests with proposed diffs, rationale, approval,
  and publication of new config versions.
- Gateway-owned authentication with inspection-local authorization profiles.
- Deterministic workspace-local state and file artifacts.

### Value

The buyer should care because Bus Inspection reduces the manual work and
uncertainty around recurring inspection reporting:

- Keep inspection data, observations, photos, comments, and exports in one
  workspace.
- Give managers a focused flow for site inspection work.
- Give customers a controlled way to see, comment on, and acknowledge their own
  observations.
- Generate reports and action lists from versioned snapshots instead of
  rebuilding documents manually.
- Preserve the data/config version behind each export.
- Keep sensitive inspection records local to the workspace instead of forcing
  them into an external SaaS database.

The practical outcome is clearer inspection history, faster report assembly,
better customer follow-up, and stronger evidence when someone asks what was
inspected and what happened next.

### Differentiation

Bus Inspection should be positioned against these alternatives:

- Spreadsheets and document templates: flexible, but weak for audit history,
  photos, customer acknowledgement, and repeatable exports.
- Generic form builders: useful for capture, but usually not enough for
  inspection history, role-scoped customer access, and report snapshots.
- Shared folders and email: easy to start, but poor for status, accountability,
  and controlled customer visibility.
- Vertical SaaS inspection tools: often polished, but may be less local,
  harder to adapt, and more disconnected from BusDK workspace automation.

BusDK's differentiators:

- Deterministic workspace-local state.
- Role-scoped access through the Bus gateway.
- Customer-facing acknowledgement and comment flow.
- Snapshot-based exports pinned to the inspection data/config version.
- Photo evidence tied directly to observations and action lists.
- Configurable report packages and versioned inspection sections.
- AI-assisted configuration with review, diff, and publish control.
- Integration with shared Bus UI, data, gateway, and document-generation
  patterns.

### Proof

Avoid unsupported market claims until real deployments exist. Current proof
should be product and demo proof:

- Admins can create customers, sites, contacts, report packages, users, and
  site access.
- Managers can create inspections, enter section values, compare with previous
  inspections, and create observations.
- Customers can comment on and acknowledge their own observations.
- Photos can be attached and previewed in observation workflows.
- Exports can produce inspection reports and action-list documents.
- Generated exports are snapshot-based and role-scoped.
- AI configuration users can request, review, approve, and publish config
  changes.
- Unit and end-to-end tests cover admin foundations, manager/customer action
  lists, export downloads, AI configuration publication, access control, and
  audit-sensitive flows.

Evidence to collect later:

- Time saved per report.
- Number of recurring sites managed.
- Number of inspections and observations completed.
- Customer acknowledgement rates.
- Time from inspection to report delivery.
- Before/after comparison against the customer's existing spreadsheet/document
  process.
- Real sample reports from pilot customers, with sensitive details removed.
- Case studies from inspection service providers or site operators.

### Objections

Likely objections and how the page should answer them:

- "Does it match our exact report format?"
  Bus Inspection supports report packages and versioned configuration, but the
  page should be honest about what formats are currently supported and invite a
  pilot for specialized templates.
- "Can our customers only see their own sites?"
  The product should show role-scoped site visibility and customer-only
  observation access as core behavior.
- "Is local workspace data a benefit or extra work?"
  Position local data as control, auditability, and portability. Also explain
  the operational setup clearly so it does not feel mysterious.
- "Can it replace our current SaaS or CMMS?"
  Do not overclaim. Present Bus Inspection first as an inspection reporting and
  action-list portal. Integrations and replacement scope should be evaluated in
  pilots.
- "Does it work on tablets or phones at sites?"
  The page should show the actual mobile/tablet behavior if it is ready. If not,
  keep the claim limited to browser-based portal workflows.
- "Can we trust AI-assisted configuration?"
  AI configuration should be described as assisted, reviewable, and publish-
  controlled. It should not be presented as unreviewed automatic compliance
  logic.
- "Is this only for Finland?"
  The current workflow has Finnish domain language, but the underlying product
  is a local inspection/action-list portal. Market the proven Finnish/technical
  inspection workflow first and broaden only when localization and templates
  support it.

### Tone

The tone should be professional, operational, and evidence-oriented. Bus
Inspection should feel like serious workflow software for teams that need
trustworthy inspection records.

Use:

- site inspections
- action lists
- observations
- photo evidence
- customer acknowledgement
- role-scoped access
- report snapshots
- local workspace data
- auditable inspection history
- configurable report packages

Avoid:

- generic AI hype
- "fully automatic compliance"
- "works for every inspection"
- vague productivity multipliers without evidence
- consumer-style playful language

### Channels

Initial channels:

- Product page on `busdk.com`.
- End-user documentation page with setup and workflow guide.
- Sample inspection report and sample action-list export.
- Demo video or GIF showing admin setup, manager inspection, customer
  acknowledgement, and export download.
- Sales/pilot one-pager for inspection service providers and site operators.

Later channels:

- Case studies from real pilot deployments.
- Template-specific landing pages for concrete inspection domains.
- Comparison page against spreadsheets, generic form builders, and vertical
  inspection SaaS.
- Integration notes for organizations that need data exchange with their
  existing systems.

### Call To Action

Primary CTA:

- Request a Bus Inspection pilot.

Secondary CTAs:

- View a sample inspection report.
- Watch the inspection-to-export demo.
- Review the local data and access-control model.
- Book a workflow fit session.

### Success Metrics

Product marketing should be judged by:

- Product page visits from relevant audiences.
- Sample report downloads.
- Demo requests.
- Pilot requests.
- Pilot-to-active-workspace conversion.
- Number of sites/customers created in pilot workspaces.
- Number of inspections created.
- Number of observations and acknowledgements completed.
- Number of PDF/DOCX exports generated.
- Repeat use across more than one inspection cycle.
- Time from inspection completion to report delivery.

## Page Message

Suggested page headline:

> Local inspection reports and action lists, built on auditable workspace data.

Suggested supporting copy:

> Bus Inspection helps inspection teams manage sites, observations, photos,
> customer acknowledgements, and generated reports in one local BusDK
> workspace. Create inspection packages, record findings, keep action lists
> moving, and export snapshot-based PDF/DOCX reports without scattering the
> evidence across spreadsheets, folders, and email.

Suggested proof-led section titles:

- Manage customers, sites, and access in one portal.
- Record inspections with observations, photos, and history.
- Let customers comment on and acknowledge their own findings.
- Generate report and action-list exports from versioned snapshots.
- Keep inspection data local, deterministic, and auditable.
- Use AI-assisted configuration with review and publish control.

## Naming Notes

Keep the public product name as **Bus Inspection** for now. It is simple and
matches the module. If the market focus narrows further, page copy can specify
the concrete domain, for example "Bus Inspection for technical site reporting"
or "Bus Inspection for recurring facility inspections."

Avoid renaming it to a generic AI product. AI-assisted configuration is useful,
but the buyer value is inspection workflow, report generation, customer
acknowledgement, and auditable data.

## Current Module Ownership

Primary module:

- `bus-inspection`

Important supporting capabilities:

- `bus-gateway` for trusted identity handoff.
- `bus-ui` for shared portal UI primitives.
- `bus-data` for deterministic workspace tables.
- Bus document/export infrastructure for PDF/DOCX generation.
- Bus AI platform capabilities where AI-assisted configuration needs a model
  adapter.
