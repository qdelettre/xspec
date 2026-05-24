FROM debian:trixie-slim

LABEL org.opencontainers.image.title="quint-runtime"
LABEL org.opencontainers.image.source="https://github.com/qdelettre/xspec"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN mkdir /workspace

# Install dependencies
RUN apt-get update && apt-get install -y \
	curl \
	git \
	build-essential \
	ca-certificates \
	tree \
	jq \
	openjdk-21-jdk \
	python3 \
	python3-pip \
	python3-venv \
	openssl \
	protobuf-compiler \
	&& rm -rf /var/lib/apt/lists/*

# Java: use arch-agnostic path for JAVA_HOME (Debian installs to java-21-openjdk-<arch>)
RUN ln -sf /usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture) /usr/lib/jvm/java-21-openjdk
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
	&& apt-get install -y nodejs \
	&& rm -rf /var/lib/apt/lists/*

# Install Quint CLI and Quint Language Server.
# Installed separately to ensure each package gets its full dependency tree
# (combined installs can produce missing transitive deps like lodash).
RUN npm install -g @informalsystems/quint && \
	npm install -g @informalsystems/quint-language-server


ARG GO_VERSION=1.24.1
ARG INSTALL_FOUNDRY=false

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) goarch="amd64" ;; \
    arm64) goarch="arm64" ;; \
    *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSLO "https://go.dev/dl/go${GO_VERSION}.linux-${goarch}.tar.gz"; \
  tar -C /usr/local -xzf "go${GO_VERSION}.linux-${goarch}.tar.gz"; \
  rm "go${GO_VERSION}.linux-${goarch}.tar.gz"

ENV PATH=/usr/local/go/bin:$PATH
ENV GOPATH=/tmp/go

# pinned to mcp-language-server v0.1.1 for reproducibility
RUN mkdir -p /tmp/mcp-build && \
	cd /tmp/mcp-build && \
	git clone --branch v0.1.1 --depth=1 https://github.com/isaacphi/mcp-language-server.git && \
	cd mcp-language-server && \
	git checkout 46e2950b7969334780675e7797e13f140d2d42ac && \
	go build -o /usr/local/bin/mcp-language-server . && \
	cd / && rm -rf /tmp/mcp-build /tmp/go

# Create a non-root user for security
RUN useradd -m -s /bin/bash dev && \
	chown -R dev:dev /workspace

# Create necessary directories for MCP servers
RUN mkdir -p /home/dev/mcp-servers && \
	mkdir -p /home/dev/mcp-servers/kb/data && \
	chown -R dev:dev /home/dev/mcp-servers

# Fetch mcp-servers/kb source from upstream at a pinned commit using sparse-checkout.
# Pinned to: 520e563613c25abac4c631ea2aa3181ba76ba193 (2026-03-06)
RUN git clone \
	--no-checkout \
	--filter=blob:none \
	--sparse \
	https://github.com/quint-co/quint-llm-kit.git \
	/tmp/quint-llm-kit && \
	cd /tmp/quint-llm-kit && \
	git sparse-checkout set mcp-servers/kb && \
	git checkout 520e563613c25abac4c631ea2aa3181ba76ba193 && \
	cp -a mcp-servers/kb/. /home/dev/mcp-servers/kb/ && \
	cd / && rm -rf /tmp/quint-llm-kit

RUN chown -R dev:dev /home/dev/mcp-servers/kb

# Set up working directory
WORKDIR /workspace

# Switch to non-root user
USER dev

# Install Rust for the dev user (after switching to dev user)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install Foundry (forge, cast, anvil, chisel) for Solidity development (optional)
RUN if [ "$INSTALL_FOUNDRY" = "true" ]; then \
    curl -L https://foundry.paradigm.xyz | bash && \
    /home/dev/.foundry/bin/foundryup; \
  fi

# Set environment variables
ENV GOPATH=/home/dev/go
ENV PATH=/usr/local/go/bin:$GOPATH/bin:/home/dev/.cargo/bin:/home/dev/.foundry/bin:$PATH

# Install dependencies and compile KB server (cached unless code changes)
WORKDIR /home/dev/mcp-servers/kb
RUN npm install && \
	npm run build

# Build indices from content (only re-runs when content changes)
RUN npm run setup && \
	chown -R dev:dev /home/dev/mcp-servers/kb/data

# Return to workspace
WORKDIR /workspace

# Pre-warm the Rust evaluator cache.
# First `quint run --backend=rust` downloads ~50MB into ~/.quint/rust-evaluator-*/.
# Doing it at build time avoids download races when users (or LLM agents) fire
# multiple `quint run` invocations in parallel on a fresh container.
RUN printf 'module prewarm {\n  var x: int\n  action init = x'\'' = 0\n  action step = x'\'' = x\n  val ok = x == 0\n}\n' > /tmp/prewarm.qnt && \
    quint run /tmp/prewarm.qnt --invariant=ok --backend=rust --max-samples=1 --max-steps=1 > /dev/null && \
    rm /tmp/prewarm.qnt && \
    ls /home/dev/.quint/rust-evaluator-*/quint_evaluator

# Default command
CMD ["tail", "-f", "/dev/null"]
