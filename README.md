# Olidian plugins for Claude Code

## pod

Put what you build with Claude Code online on your [Pod](https://github.com/Olidian) instance,
in one sentence: "put this online".

```
/plugin marketplace add Olidian/claude-plugins
/plugin install pod@olidian
```

Claude Code asks for your Pod address (e.g. `https://pod.example.com`). Then run `/mcp`,
choose `pod` and sign in: your browser opens Pod, where you pick the organization and the
access (deploy, or read only). Then ask Claude to deploy.

What the plugin brings:

- **Pod's MCP server** (`<your Pod>/api/v1/mcp`): deploy a ready-made image, follow
  deployments, read logs, set environment variables, add a database or a domain, roll back,
  delete an app.
- **The `deploy-to-pod` skill**: the flow. Claude first looks for a ready-made image (Docker Hub
  first: official images, then verified publishers). When no image runs your own code, Pod
  builds it from a Git repository: Claude writes the Dockerfile if the project has none,
  following Pod's guide, pushes it with your go-ahead, and tells you how to link the repository
  in Pod's interface. Pod no longer receives folders sent from your machine.

Your Pod instance must run Pod 0.18 or later. Version 2.0.0 of the plugin no longer sends
folders and has no hook: use 1.1.0 with a Pod that still accepts them. Without the plugin, the MCP server alone works too:

```
claude mcp add --transport http pod https://pod.example.com/api/v1/mcp
```

## Development

```
claude plugin validate plugins/pod
```
