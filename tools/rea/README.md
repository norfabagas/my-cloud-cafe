# REA investigation

The runner uses REA **6.8.0**, reads a caller-supplied standalone APK, records its SHA-256, and saves complete CLI output. It never launches or patches the APK. A package-name match or self-consistent signature does not prove authenticity.

Requirements: Python 3.10+, Node.js compatible with REA 6.8.0, npm, full JDK 17+, and the caller-supplied `jadx-headless-mcp` **0.7.1** JAR. See [REA Android prerequisites](https://github.com/morluto/rea/blob/main/docs/android-analysis.md) for the pinned SHA-256 and official download link. REA setup does not supply the JAR.

The runner verifies the JAR against REA's pinned SHA-256: `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`.

```bash
export REA_JADX_MCP_JAR=/absolute/path/jadx-headless-mcp-0.7.1-all.jar
python3 tools/rea/investigate.py readiness --output evidence/readiness-001
python3 tools/rea/investigate.py inspect /absolute/path/MyCafe.apk --output evidence/my-cafe-001
```

Each output directory must be new. By default the runner invokes `npx --yes rea-agents@6.8.0` from a temporary directory outside the project; this downloads the pinned package into npm's cache. To use an already installed executable:

```bash
export REA_BIN=/absolute/path/to/rea
```

`inspect` saves signing evidence before checking JADX readiness, then captures the manifest/package inventory if ready. `summary.json` records errors and whether the input bytes stayed unchanged. A failed or incomplete result remains evidence of that limitation. Code analysis checks that `normalized_result.package_name` is exactly `com.melesta.coffeeshop`.

Follow up only after reading the inventory. Choose concrete classes and methods from actual evidence:

```bash
npx --yes rea-agents@6.8.0 search-android-classes /absolute/path/MyCafe.apk com.melesta --json
npx --yes rea-agents@6.8.0 inspect-android-class /absolute/path/MyCafe.apk exact.ClassName --json
npx --yes rea-agents@6.8.0 inspect-android-method /absolute/path/MyCafe.apk exact.ClassName exactMethod --overload-index 0 --json
```

The sample selectors are placeholders, not findings. Preserve output and Evidence IDs, overload indices, APK identity, limitations, and source locations. JADX cannot establish all native engine, server, dynamically loaded, or runtime behavior. No purchase or authentication bypass is included; the new Flutter game simply has no billing integration.
