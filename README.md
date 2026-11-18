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

- **The `pod-cli` skill and `podctx`**: for several Pod instances (yours, your customers'), CI
  jobs, and what the MCP tools do not cover (other environments, project variables, health
  checks, backups…). `podctx <instance> <pod command>` runs the `pod` CLI against a named
  instance, and `podctx <instance> api GET /api/v1/…` calls its API. The API key is read from your
  password manager at the last moment and never appears in an argument or in Claude's output.

### Several instances

Describe each instance in `~/.config/pod/instances` (or `$POD_INSTANCES_FILE`):

```ini
[acme]
url   = https://pod.acme.example
key   = op://Pod/acme/credential          # 1Password reference; or env:VARIABLE, or keychain:SERVICE (macOS)
image = registry.acme.example/pod:0.26.1  # optional: run the CLI from Pod's image when no pod binary is installed
```

Create the API key in Pod (Profile › API keys: `read`, or `write` to deploy) and store it in
your password manager yourself; a key written in clear in the file is refused. Check with
`podctx acme check`. In a project, `.pod/app.json` can bind the instance and the service:
`{"app": "shop", "instance": "acme", "service": "shop/web"}`, then `podctx . status`.

An MCP server per instance is possible too:
`claude mcp add --transport http pod-acme https://pod.acme.example/api/v1/mcp`.

`podctx` needs bash and curl; 1Password's `op`, Docker or the macOS keychain only for the key
or CLI sources you choose. The plugin's only hook puts `podctx` on the PATH at session start.

Your Pod instance must run Pod 0.18 or later. Since version 2.0.0 the plugin no longer sends
folders: use 1.1.0 with a Pod that still accepts them. Without the plugin, the MCP server alone works too:

```
claude mcp add --transport http pod https://pod.example.com/api/v1/mcp
```

## Development

```
claude plugin validate plugins/pod
bash plugins/pod/tests/test_podctx.sh
```
