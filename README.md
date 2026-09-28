# Olidian plugins for Claude Code

## pod

Put what you build with Claude Code online on your [Pod](https://github.com/Olidian) instance,
in one sentence: "put this folder online".

```
/plugin marketplace add Olidian/claude-plugins
/plugin install pod@olidian
```

Claude Code asks for your Pod address (e.g. `https://pod.example.com`). Then run `/mcp`,
choose `pod` and sign in: your browser opens Pod, where you pick the organization and the
access (deploy, or read only). Then ask Claude to deploy.

What the plugin brings:

- **Pod's MCP server** (`<your Pod>/api/v1/mcp`): deploy a folder, follow the build, read logs,
  set environment variables, add a database or a domain, roll back, delete an app.
- **The `deploy-to-pod` skill**: the flow, and what Pod expects of a Dockerfile. Claude writes
  one if the project has none, following Pod's guide.
- **A hook** that lets the one command Pod gives to send the folder (`git ls-files | tar | curl`
  to a single-use upload URL of your instance) run without a permission prompt. Any other
  command follows your usual permission rules. It needs `python3`; without it, you are asked
  as usual.

Your Pod instance must run Pod 0.10 or later. Without the plugin, the MCP server alone works too:

```
claude mcp add --transport http pod https://pod.example.com/api/v1/mcp
```

## Development

```
python3 -m unittest discover -s tests
claude plugin validate plugins/pod
```
