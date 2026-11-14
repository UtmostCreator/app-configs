<!-- glyphbrace: seeded once and yours to edit. Glyphbrace never rewrites or removes it. -->
---
documentation:
  schema_version: 1
  id: TPL-0034
  kind: template
  status: template
  summary: "System Architecture: How Projects Interact"
  review:
    approval_ref: unknown
    summary_by: agent
---
# System Architecture: How Projects Interact

> Request access to other projects on demand when investigation requires files, data, logs, runtime traces, or repository context outside the current project boundary.

This document is the canonical cross-repository overview for the workspace system architecture.

It is maintained in `[CANONICAL_DOC_OWNER_REPOSITORY]` and should be included in adjacent repositories through `[SHARED_DOC_LINK_STRATEGY]`, such as symbolic links under `docs/shared`, rather than copied into each repository.

Verified against the current local workspace on `[LAST_VERIFIED_DATE]`.

## How The Most Difficult Parts Work

- Shared logic between projects:
  - `[CANONICAL_SHARED_LOGIC_DOC_PATH]`

## Shared Document Ownership

- Canonical file: `[CANONICAL_PROJECT_INTERACTION_DOC_PATH]`
- Linked into adjacent repositories through `[SHARED_DOC_LINK_PATH]`
- Current linked repositories in this workspace:
  - `[LOCAL_PATH_TO_REPOSITORY_A]`
  - `[LOCAL_PATH_TO_REPOSITORY_B]`
  - `[LOCAL_PATH_TO_REPOSITORY_C]`
  - `[LOCAL_PATH_TO_REPOSITORY_D]`
- If this document changes, linked repositories pick up the same content automatically through `[SHARED_DOC_SYNC_MECHANISM]`

## Repositories In Scope

### 1. `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]`

Local path: `[LOCAL_PATH_TO_CONTENT_OR_BACKEND_APPLICATION]`

#### Logs

- External process log: `[PATH_TO_EXTERNAL_PROCESS_LOG]`
- Application logs: `[PATH_TO_APPLICATION_LOG_DIRECTORY]`
- Temporary runtime logs: `[PATH_TO_TEMP_RUNTIME_LOG_PATTERN]`

#### Repository Context

> The `[REPOSITORY_CONTEXT_DIRECTORY]` folder may not be installed in every clone. Reference these paths when it is present.

| Purpose | Path |
|---|---|
| Open first | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/index.md` |
| Machine plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.json` |
| TSV plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.tsv` |
| Manifest | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-manifest.json` |
| Bundles | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/bundles/` |

Primary role: `[PRIMARY_ROLE_OF_CONTENT_OR_BACKEND_APPLICATION]`.

Verified stack from `[DEPENDENCY_MANIFEST_FILE]`:

- `[RUNTIME_OR_LANGUAGE_VERSION]`
- `[APPLICATION_FRAMEWORK_AND_VERSION]`
- `[CMS_OR_PLATFORM_LAYER_AND_VERSION]`
- `[DATA_DRIVER_OR_STORAGE_LAYER]`
- `[API_LAYER_OR_QUERY_SUPPORT]`
- Private dependency on `[SHARED_PACKAGE_OR_INTERNAL_MODULE]`

What it owns:

- content APIs
- content structure and delivery
- query or API layer
- checkout, order, workflow, or transaction session flow
- handoff from browse or discovery journey into transactional flow
- integration with `[INTERNAL_SYSTEM_OF_RECORD]` for availability, pricing, inventory, booking, order, or operational data
- integration with `[PAYMENT_OR_EXTERNAL_SERVICE_PACKAGE]` through `[SHARED_PAYMENT_OR_INTEGRATION_PACKAGE]`

Important implementation surface in this repository:

- `[ROUTES_FILE_OR_API_ENTRYPOINT]`
- `[PRIMARY_CONTROLLER_OR_HANDLER]`
- `[PRIMARY_DOMAIN_SERVICE]`
- `[INTEGRATION_SERVICE]`
- `[TEST_DIRECTORY_OR_TEST_SUITE]`

Practical storage model:

- Most runtime application data is backed by `[DATABASE_OR_STORAGE_BACKEND]`
- A meaningful amount of structure may still live in repository-tracked configuration such as `[CONFIG_DIRECTORY]`, `[SCHEMA_DIRECTORY]`, `[BLUEPRINT_DIRECTORY]`, or `[FIELDSET_DIRECTORY]`

#### Shared API Client Boundary

On the application side, `[SHARED_API_CLIENT_CLASS]` is the shared HTTP adapter that `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]` uses to fetch `[DOMAIN_OBJECTS]` from `[INTERNAL_SYSTEM_OF_RECORD]` and to submit `[TRANSACTION_OR_BOOKING_REQUESTS]` into `[INTERNAL_SYSTEM_OF_RECORD]`.

On the internal system side, `[SHARED_API_CLIENT_CLASS]` is only used in limited flows where the system needs to re-fetch canonical data in a shape expected by shared abstractions.

`[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]` connects to `[INTERNAL_SYSTEM_OF_RECORD]` through `[SHARED_API_CLIENT_FULLY_QUALIFIED_CLASS_OR_PACKAGE]`.

- `[PATH_TO_DETAILED_INTEGRATION_DOC]`

Verified wiring in this repository:

- `[INTEGRATION_SERVICE]` constructs the client with `[HOST_CONFIG_KEY]`, `[API_KEY_CONFIG_KEY]`, and `[USER_OR_TENANT_CONFIG_KEY]`
- the client sends `[AUTH_HEADER_NAMES]` and calls `[INTERNAL_SYSTEM_OF_RECORD]` HTTP routes under `[API_ROUTE_PREFIX]`
- most business code does not call raw internal-system routes directly; it goes through `[INTEGRATION_SERVICE]`

Verified use of `[SHARED_API_CLIENT_CLASS]` methods:

- `[METHOD_NAME]()` for `[PURPOSE]`
- `[METHOD_NAME]()` for `[PURPOSE]`
- `[METHOD_NAME]()` for `[PURPOSE]`
- `[METHOD_NAME]()` for `[PURPOSE]`
- `[METHOD_NAME]()` for `[PURPOSE]`

Current repository evidence does not show `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]` using `[UNUSED_OR_UNVERIFIED_METHOD_LIST]` directly.

### 2. `[PUBLIC_FRONTEND_REPOSITORY]`

Local path: `[LOCAL_PATH_TO_PUBLIC_FRONTEND]`

#### Logs

- External process log: `[PATH_TO_FRONTEND_PROCESS_LOG]`
- Hosting or runtime log: `[PATH_TO_FRONTEND_HOSTING_OR_RUNTIME_LOG]`

#### Repository Context

> The `[REPOSITORY_CONTEXT_DIRECTORY]` folder may not be installed in every clone. Reference these paths when it is present.

| Purpose | Path |
|---|---|
| Open first | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/index.md` |
| Machine plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.json` |
| TSV plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.tsv` |
| Manifest | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-manifest.json` |
| Bundles | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/bundles/` |

Primary role: `[PRIMARY_ROLE_OF_PUBLIC_FRONTEND]`.

Verified stack from `[PACKAGE_MANIFEST_FILE]` and `[FRONTEND_CONFIG_FILE]`:

- `[FRONTEND_FRAMEWORK_AND_VERSION]`
- `[UI_LIBRARY_AND_VERSION]`
- `[STATE_MANAGEMENT_LIBRARY]`
- dependency on `[SHARED_UI_COMPONENT_PACKAGE]`

What it owns:

- public browse UI
- SSR or client-rendered browse experience
- region, tenant, market, language, or locale bootstrap on the frontend side
- pre-transaction interaction before the user enters the transactional flow in `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]`

Verified integration points:

- `[REGION_OR_BOOTSTRAP_PLUGIN]` posts to `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]` at `[BOOTSTRAP_API_ENDPOINT]`
- `[FRONTEND_SERVER_API_PROXY]` proxies checkout, order, search, content, or domain-data requests to `[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]`
- `[FRONTEND_CONFIG_FILE]` declares `[CONTENT_BACKEND_URL_CONFIG_KEY]` and `[TRANSACTION_URL_CONFIG_KEY]`
- The repository README instructs developers to set `[PUBLIC_BACKEND_URL_ENV_VAR]`

#### SSR And Hydration Caveat

The most likely place for hydration mismatches in this workspace is `[PUBLIC_FRONTEND_REPOSITORY]`, especially when SSR pages render shared components from `[SHARED_UI_COMPONENT_REPOSITORY]` that branch their DOM using browser-only state.

Current local-source example re-verified on `[LAST_REVERIFIED_DATE]`:

- `[FRONTEND_PAGE_OR_BLOCK_COMPONENT]` renders `[SHARED_COMPONENT]` inside an SSR page shell and keeps only the interactive browser-only area under `[CLIENT_ONLY_WRAPPER]`
- `[SHARED_COMPONENT_SOURCE_PATH]` previously chose different mobile vs desktop DOM trees from `[VIEWPORT_COMPOSABLE_OR_BROWSER_STATE_SOURCE]` during render
- on SSR, browser-only sizing resolves from a non-browser environment, while on a client it resolves from the real viewport
- that produced `[HYDRATION_WARNING_MESSAGE]` because SSR emitted one branch and the client immediately wanted another branch

Current verified mitigation in local source:

- `[SHARED_COMPONENT_SOURCE_PATH]` gates viewport-dependent layout behind a mounted-phase flag such as `[HYDRATION_FLAG_NAME]`
- this keeps the SSR render on one stable branch during hydration, then allows enhanced layout to activate after mount
- the fix keeps the SSR shell, title, subtitle, footer, anchors, and SEO-relevant content available in initial HTML while avoiding branch mismatch during hydration
- `[FRONTEND_PAGE_OR_BLOCK_COMPONENT]` still keeps only the browser-only subtree under `[CLIENT_ONLY_WRAPPER]`; it does not wrap the whole content shell

Local package-sync caveat for this workspace:

- `[PUBLIC_FRONTEND_REPOSITORY]` consumes the published `[SHARED_UI_COMPONENT_PACKAGE]` package from `[PACKAGE_INSTALL_LOCATION]`, not necessarily the source repository directly
- when a hydration fix is made in `[SHARED_UI_COMPONENT_REPOSITORY]`, local verification in `[PUBLIC_FRONTEND_REPOSITORY]` may also require the installed package copy under `[INSTALLED_PACKAGE_COPY_PATH]` to match until the package is published or linked
- if the source repository and installed package copy drift, the app can appear unfixed even though the shared component source repository already contains the patch

Practical rule for this stack:

- SSR-safe structure must not depend on `window`, viewport width, `matchMedia`, or similar browser-only values during initial render
- responsive differences should prefer CSS or a mounted-phase enhancement instead of branch swaps during hydration
- `[CLIENT_ONLY_WRAPPER]` is appropriate for truly interactive browser-only subtrees such as search widgets, maps, payment widgets, or third-party embeds, but it should not wrap SEO-relevant content shells unless losing SSR is acceptable

In this workspace, hydration issues are most likely when one or more of these are true:

- a shared component in `[SHARED_UI_COMPONENT_SOURCE_DIRECTORY]` changes rendered element structure based on viewport or other browser-only state
- a page in `[FRONTEND_PAGE_DIRECTORY]` or `[FRONTEND_CONTENT_COMPONENT_DIRECTORY]` mixes SSR content with a child component that reads browser state during render rather than after mount
- fallback content and enhanced client content are structurally different rather than visually different
- a broad `[CLIENT_ONLY_WRAPPER]` is used to silence a mismatch, but that also removes important SSR output and hides the real owning component

Where to look first for hydration bugs in this frontend stack:

- `[FRONTEND_PAGE_OR_BLOCK_COMPONENT]`
- `[FRONTEND_PAGE_DIRECTORY]`
- `[SHARED_COMPONENT_SOURCE_PATH]`
- `[INSTALLED_SHARED_COMPONENT_COPY_PATH]`
- `[VIEWPORT_OR_BROWSER_STATE_COMPOSABLE]`
- any component using `[CLIENT_ONLY_WRAPPER]`, `[VIEWPORT_COMPOSABLE]`, `window`, `document`, `matchMedia`, or mounted-only data to choose markup shape

### 3. `[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]`

Local path: `[LOCAL_PATH_TO_INTERNAL_SYSTEM_OF_RECORD]`

#### Logs

- Application logs: `[PATH_TO_INTERNAL_SYSTEM_LOGS]`

All API calls:

- `[PATH_TO_API_COLLECTION_OR_REQUEST_DEFINITIONS]`

#### Repository Context

> `[REPOSITORY_CONTEXT_DIRECTORY]` was not detected in this project at last verification. Install repository context here if you need AI-assisted investigation across this repository.

| Purpose | Path when installed |
|---|---|
| Open first | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/index.md` |
| Machine plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.json` |
| TSV plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.tsv` |
| Manifest | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-manifest.json` |
| Bundles | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/bundles/` |

Primary role: `[PRIMARY_ROLE_OF_INTERNAL_SYSTEM_OF_RECORD]`.

Verified from `[DEPENDENCY_MANIFEST_FILE]` and local docs:

- `[RUNTIME_OR_LANGUAGE_VERSION]`
- `[APPLICATION_FRAMEWORK_AND_VERSION]`
- internal application, not the public browse experience
- depends on `[SHARED_PAYMENT_OR_INTEGRATION_PACKAGE]`

What it owns:

- booking, order, reservation, or transaction creation
- final price, availability, inventory, or operational authority
- internal operational workflows
- downstream logic consumed by website-facing or client-facing systems

Working rule that remains important for debugging:

- website or client systems may display intermediate values, but `[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]` remains the final authority when the transaction is created or committed

#### Shared API Client Boundary In The Internal System

`[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]` is usually the server behind `[SHARED_API_CLIENT_CLASS]`, not its main consumer.

Verified direct use of `[SHARED_API_CLIENT_CLASS]` is narrow:

- `[SERVICE_OR_CONTROLLER]` uses `[METHOD_NAME]()` before `[PURPOSE]`
- `[SERVICE_OR_CONTROLLER]` uses `[METHOD_NAME]()` while `[PURPOSE]`
- `[SERVICE_OR_CONTROLLER]` uses `[METHOD_NAME]()` before `[PURPOSE]`
- `[SERVICE_OR_CONTROLLER]` uses `[METHOD_NAME]()` before `[PURPOSE]`

In other words, `[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]` uses the shared client mostly to re-fetch canonical DTOs that match the shared package's abstractions.

Important distinction:

- many classes in `[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]` expose similarly named methods such as `[SERVER_SIDE_METHOD_LIST]`
- those are the server-side implementations and routes that the shared client calls
- they are not evidence that the internal system itself is consuming those `[SHARED_API_CLIENT_CLASS]` methods internally

### 4. `[SHARED_PAYMENT_OR_INTEGRATION_PACKAGE_REPOSITORY]`

Local path: `[LOCAL_PATH_TO_SHARED_PAYMENT_OR_INTEGRATION_PACKAGE]`

#### Logs

- `[LOG_STATUS_OR_PATHS]`

#### Repository Context

> `[REPOSITORY_CONTEXT_DIRECTORY]` was not detected in this project at last verification. Install repository context here if you need AI-assisted investigation across this repository.

| Purpose | Path when installed |
|---|---|
| Open first | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/index.md` |
| Machine plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.json` |
| TSV plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.tsv` |
| Manifest | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-manifest.json` |
| Bundles | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/bundles/` |

Primary role: shared package that abstracts payment, transaction, booking, integration, or external-service behavior between client applications, internal systems, and third-party services.

Verified from `[DEPENDENCY_MANIFEST_FILE]` and README:

- package name: `[SHARED_PACKAGE_NAME]`
- wraps `[THIRD_PARTY_SDK_OR_EXTERNAL_SERVICE_CLIENT]` behavior
- provides `[INTERNAL_SYSTEM_OF_RECORD]` facing support through its own abstractions
- used by client applications such as `[CLIENT_APPLICATION_TYPES]`

Capabilities shown in the package README:

- create payment links, transaction links, or action links
- create or update payment intents, transaction intents, or workflow intents
- create optional-item, add-on, or supplemental payment intents
- refund, reverse, cancel, or reconcile transactions
- fetch canonical records through `[SHARED_API_CLIENT_CLASS]`
- create records using `[DOMAIN_OBJECTS_OR_DTOs]`

Important boundary:

- this package handles shared integration behavior
- it does not change the ownership rule that `[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]` remains the final authority for committed domain state

### 5. `[SHARED_UI_COMPONENT_REPOSITORY]`

Local path: `[LOCAL_PATH_TO_SHARED_UI_COMPONENT_REPOSITORY]`

#### Logs

- `[LOG_STATUS_OR_PATHS]`
- AI tool usage record: `[PATH_TO_AI_TOOL_USAGE_LOG_IF_APPLICABLE]`

#### Repository Context

> The `[REPOSITORY_CONTEXT_DIRECTORY]` folder may not be installed in every clone. Reference these paths when it is present.

| Purpose | Path |
|---|---|
| Open first | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/index.md` |
| Machine plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.json` |
| TSV plan | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-plan.tsv` |
| Manifest | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/tree-manifest.json` |
| Bundles | `[LOCAL_PATH]/[REPOSITORY_CONTEXT_DIRECTORY]/tree-context/bundles/` |

Primary role: shared UI component library.

Verified stack from `[PACKAGE_MANIFEST_FILE]`:

- `[BUILD_TOOL]`
- `[UI_FRAMEWORK]` component package
- `[COMPONENT_DEVELOPMENT_TOOL]`
- `[TEST_FRAMEWORK]`
- package name `[SHARED_UI_COMPONENT_PACKAGE_NAME]`

What it owns:

- shared frontend UI components
- shared presentation-level building blocks for frontend applications

Most visible consumer in this workspace:

- `[PUBLIC_FRONTEND_REPOSITORY]`

## High-Level System Picture

```text
End user browser
    |
    v
[PUBLIC_FRONTEND_REPOSITORY]
    |
    +--> region, tenant, locale, or bootstrap request --> [CONTENT_OR_BACKEND_APPLICATION_REPOSITORY] [BOOTSTRAP_API_ENDPOINT]
    |
    +--> browse content and domain-data requests --> [CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]
    |
    +--> transaction, checkout, order, or workflow handoff --> [CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]
    |
    +--> shared UI comes from [SHARED_UI_COMPONENT_REPOSITORY]
    v
[CONTENT_OR_BACKEND_APPLICATION_REPOSITORY]
    |
    +--> content APIs and session or workflow ownership
    +--> pricing, availability, inventory, or validation requests --> [INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]
    +--> transaction request assembly --> [INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]
    +--> payment or external-service behavior --> [SHARED_PAYMENT_OR_INTEGRATION_PACKAGE_REPOSITORY]
    +--> assets, search, cache, geo, queue, or infrastructure --> [INFRASTRUCTURE_DEPENDENCIES]
    v
[INTERNAL_SYSTEM_OF_RECORD_REPOSITORY]
    |
    +--> final transaction creation
    +--> final price, availability, or operational recalculation
