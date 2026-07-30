FROM node:20-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install opencode
RUN curl -fsSL https://opencode.ai/install | bash

# Add opencode to PATH
ENV PATH="/root/.opencode/bin:${PATH}"

# Agent configuration (overridden per-agent)
ARG AGENT_NAME=agent
ENV AGENT_NAME=${AGENT_NAME}

# Copy agent-specific config if it exists
COPY agents/${AGENT_NAME}/ /agent-config/

WORKDIR /workspace

# Default: run as server with agent config
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
