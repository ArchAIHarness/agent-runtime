FROM docker.1ms.run/library/node:22-slim

ENV TZ=Asia/Shanghai

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai

WORKDIR /app
COPY .opencode/opencode.json .opencode/
COPY .opencode/agents/ .opencode/agents/
COPY .opencode/commands/ .opencode/commands/
COPY .opencode/modes/ .opencode/modes/
COPY .opencode/plugins/ .opencode/plugins/
COPY .opencode/skills/ .opencode/skills/
COPY .opencode/tools/ .opencode/tools/
COPY .opencode/themes/ .opencode/themes/
COPY AGENTS.md .

EXPOSE 4096
CMD ["opencode", "web", "--port", "4096", "--hostname", "0.0.0.0"]
