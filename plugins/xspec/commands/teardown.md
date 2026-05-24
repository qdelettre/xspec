---
command: /xspec:teardown
description: Stop and remove the Quint runtime container (image preserved)
version: 1.0.0
---

# Teardown the Quint Runtime

## Objective

Stop the `quint-runtime` container and remove it. Image remains cached for future `/xspec:setup`.

## Steps

1. **Check container exists**

```bash
docker ps -a --filter name=^quint-runtime$ -q
```

If empty: "Container already gone. Nothing to do." Stop.

2. **Stop + remove**

```bash
docker stop quint-runtime 2>/dev/null || true
docker rm quint-runtime
```

3. **Report**

Print: "✓ quint-runtime removed. Run /xspec:setup to recreate."

## Notes

- Image is intentionally preserved. To remove image too: `docker rmi quint-runtime:0.1.0`.
- Workspace files on host are untouched.
