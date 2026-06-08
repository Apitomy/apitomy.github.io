---
layout: post
title: "What is Apitomy? An API-First Toolkit for Modern Teams"
date: 2026-06-07
author: Eric Wittmann
---

We've all been there. You sketch out an API on a whiteboard (or in a text file
at 2am), then spend the next week hand-editing YAML, writing boilerplate server code, keeping specs
and implementations in sync, and triaging the issues that inevitably pile up. Apitomy is an open
source toolkit built to short-circuit that grind -- covering the full API lifecycle from visual
design through code generation to AI-powered project orchestration. Each project works standalone,
but together they contribute to a surprisingly cohesive, design-first pipeline.

## The Foundation: Data Models

Everything in Apitomy builds on
[Data Models](https://github.com/Apitomy/apitomy-data-models) -- a unified library for reading,
writing, and manipulating API specification documents. It supports a broad range of formats:

- **OpenAPI** 2.0, 3.0.x, 3.1.x, and 3.2.x
- **AsyncAPI** 2.0 through 3.1
- **JSON Schema** Draft 4 through 2020-12

Hand it a spec and it auto-detects the type and version, parses it into a rich typed object model,
and gives you a clean API for traversal (via the visitor pattern), transformation, and
serialization. Need to validate? There are 150+ built-in rules with severity levels and error
codes, so you can catch problems before your users do.

Here's the fun part: the source is written in Java and transpiled to TypeScript via
[JSweet](https://www.nicolo-ribaudo.dev/jsweet), producing an npm package
(`@apitomy/data-models`) with **zero runtime dependencies**. One codebase, two languages, identical
APIs. Java and TypeScript developers get the same experience -- no second-class citizens.

Data Models is the shared foundation that both the OpenAPI Editor and Codegen projects build on.

## AI-Native API Editing: Data Models MCP

The [Data Models MCP Server](https://github.com/Apitomy/apitomy-data-models-mcp) brings the full
power of the Data Models library to AI coding assistants. It exposes over 100 purpose-built
[MCP](https://modelcontextprotocol.io/) tools that let assistants like Claude Code, Cursor, and
Windsurf treat API specs as structured data rather than raw text.

We've all seen what happens when you ask an AI to edit YAML -- the indentation alone can ruin your
afternoon. The MCP server sidesteps that entirely with precise, spec-aware operations: add a path,
define a schema, set up security schemes, validate the document. It even supports converting
between OpenAPI versions and inlining external `$ref` references.

Getting started is a single command. For Claude Code, add it to your MCP config:

```json
{
  "mcpServers": {
    "apitomy-data-models": {
      "command": "npx",
      "args": ["-y", "@apitomy/data-models-mcp"]
    }
  }
}
```

Once configured, you can ask your assistant to create, edit, and validate OpenAPI documents without
anyone having to count spaces in YAML ever again.

## Visual Design: OpenAPI Editor

Let's face it -- most developers would rather do just about anything than write YAML by hand. The
[OpenAPI Editor](https://github.com/Apitomy/apitomy-openapi-editor) is an embeddable React
component that gives you a full-featured visual editor for OpenAPI documents, so you can stop
arguing with your text editor about indentation.

The editor supports OpenAPI 2.0, 3.0.x, and 3.1.x. It includes tree-based navigation for paths,
schemas, responses, and tags; inline property editing with auto-save; real-time validation with
clickable problem navigation; and full undo/redo support. When you do need to drop into raw markup
(no judgment), a source view toggle lets you edit YAML or JSON directly and switch back seamlessly.

Built on [PatternFly 6](https://www.patternfly.org/), the editor integrates into React applications
with a straightforward component API:

```tsx
<OpenAPIEditor
  initialContent={openApiDocument}
  onChange={(event) => handleDocumentChange(event)}
  onSelectionChange={(event) => handleSelection(event)}
/>
```

Under the hood, the editor delegates all parsing, mutation, and validation to the Data Models
library. It's the visual layer; Data Models is the engine.

## From Spec to Code: Codegen

You've designed a beautiful API. Now what? You could hand-write all those JAX-RS annotations, or
you could let [Codegen](https://github.com/Apitomy/apitomy-codegen) do it for you. Unlike
broad-spectrum generators that target dozens of languages with varying quality, Apitomy Codegen is
purpose-built for **Quarkus and JAX-RS** -- and it generates **interfaces, not implementations**.

That distinction matters. Generated interfaces carry all the JAX-RS annotations (`@Path`, `@GET`,
`@Produces`, etc.) and bean validation constraints (`@NotNull`, `@Min`, `@Pattern`). Your
implementation classes stay clean -- just business logic, no annotation noise. The API contract
lives in the interface and stays in sync with the spec automatically.

Codegen plugs into your Maven build, binding to the `generate-sources` phase:

```xml
<plugin>
  <groupId>io.apitomy</groupId>
  <artifactId>apitomy-codegen-maven-plugin</artifactId>
  <configuration>
    <projectSettings>
      <javaPackage>com.example.api</javaPackage>
    </projectSettings>
    <inputSpec>${project.basedir}/src/main/resources/openapi.json</inputSpec>
  </configuration>
</plugin>
```

Configuration options include reactive return types (`CompletionStage<>`), builder pattern
generation, and fine-grained control via OpenAPI vendor extensions (`x-codegen-*`). Codegen uses
Data Models internally for spec parsing, giving it the same broad format support.

## AI-Powered Orchestration: Axiom

[Axiom](https://github.com/Apitomy/apitomy-axiom) takes Apitomy beyond tooling and into workflow
automation. It's an event-driven orchestration platform that monitors your GitHub (and eventually
Jira) repositories for issue activity, then intelligently delegates work to both AI and human
actors. Think of it as a project manager that never sleeps and never forgets to follow up.

Here's the flow: when a new issue is created or updated, Axiom's **AI Manager** evaluates the
event against configurable policies and produces a structured decision with a confidence score.
High-confidence decisions are acted on automatically -- creating a project, assigning a task,
choosing the right action type (analyze, implement, review, respond). Low-confidence decisions?
Those get bumped to a human, because sometimes you really do need a person in the loop.

Tasks are assigned to **actors**. An actor can be an AI agent (Claude Code or OpenCode, running in
an isolated subprocess with scoped permissions) or a human team member (notified via Slack,
Telegram, or the Axiom UI). The AI Manager can chain tasks intelligently -- an analysis task's
output can trigger an implementation task, followed by a review -- without anyone having to
manually shepherd the process.

Axiom's extensibility comes from its MCP-first architecture. All actor capabilities are delivered
via [MCP servers](https://modelcontextprotocol.io/), so adding domain-specific tools (code
analysis, database access, custom validators) requires no code changes to Axiom itself. And yes,
the platform eats its own dogfood -- its REST API is generated by Apitomy Codegen.

## How the Pieces Fit Together

Each Apitomy project is useful on its own, but the real magic is in composition:

1. **Design** your API visually in the OpenAPI Editor -- or use the **Data Models MCP Server** to
   build and edit specs directly from your AI coding assistant
2. The editor and MCP server both use **Data Models** under the hood for parsing, validation, and
   mutation
3. Feed your finished spec to **Codegen** to generate JAX-RS interfaces and data models
4. Implement your business logic against the generated interfaces
5. Set up **Axiom** to monitor your repo -- it triages incoming issues and delegates work to AI
   agents or your team

Design-first development with teeth: the spec is the source of truth, the generated code enforces
it, and the orchestration layer keeps the project moving.

## Get Started

All Apitomy projects are open source under the Apache License 2.0. You can find them on GitHub:

- [apitomy-data-models](https://github.com/Apitomy/apitomy-data-models) -- spec parsing and
  manipulation (Java + TypeScript)
- [apitomy-data-models-mcp](https://github.com/Apitomy/apitomy-data-models-mcp) -- MCP server for
  AI-assisted API editing
- [apitomy-openapi-editor](https://github.com/Apitomy/apitomy-openapi-editor) -- visual OpenAPI
  editor (React)
- [apitomy-codegen](https://github.com/Apitomy/apitomy-codegen) -- code generation for
  Quarkus/JAX-RS (Java)
- [apitomy-axiom](https://github.com/Apitomy/apitomy-axiom) -- AI-powered project orchestration

We welcome contributions, feedback, and ideas. Come say hi on
[GitHub](https://github.com/Apitomy) -- we'd love to hear what you're building.
