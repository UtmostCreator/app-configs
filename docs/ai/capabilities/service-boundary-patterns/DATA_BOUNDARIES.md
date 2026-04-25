# Data Boundaries

## Rules

- shared state increases blast radius and requires explicit isolation notes
- define least-privilege access for each data surface
- separate preview or test state from production state
- document backup, restore, and retention expectations for critical data paths

## Review Notes

- if multiple services share one datastore, record failure and upgrade coupling risk
- if one surface can impact auth, policy, or observability data, treat as high-risk
