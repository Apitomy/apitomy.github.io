---
layout: post
title: "Design-First vs Code-First APIs: Why Apitomy Bets on Design-First"
date: 2026-06-08
author: Eric Wittmann
---

If you've been building APIs for more than five minutes, you've probably run into The Debate:
should you design your API spec first and generate code from it, or write code first and generate
the spec from annotations? Both camps have strong opinions. Apitomy firmly plants its flag in the
design-first camp -- and we think once you see the full pipeline in action, you might too.

## The Code-First Trap

Code-first is seductive. You write your JAX-RS endpoints, sprinkle on some annotations, and a
framework generates your OpenAPI spec at build time. No separate spec file to maintain, no context
switching -- just code. What's not to love?

Plenty, as it turns out.

The generated spec is a **byproduct**, not a contract. It reflects whatever your code happens to
do today, quirks and all. Rename a parameter? The spec changes. Refactor an endpoint? The spec
changes. Add a field you meant to keep internal? Surprise -- it's in the spec now. Your API
consumers are downstream of every implementation decision you make, whether you intended that or
not.

Code-first also makes it hard to **collaborate before building**. Product managers, frontend
developers, and partner teams can't easily review or contribute to an API design when the source
of truth is scattered across Java classes. And good luck getting useful feedback on a 3000-line
generated YAML file that nobody wrote by hand.

Then there's the versioning problem. When your spec is derived from code, you can't easily diff
what changed in your API contract between releases. You can diff the code, sure, but that tells
you what changed in the *implementation* -- not what changed from the consumer's perspective.

## The Design-First Advantage

Design-first flips the relationship. The OpenAPI spec is the **source of truth**, and everything
else flows from it. You design the API, get it right, *then* build.

This has some immediate practical benefits:

**Early feedback.** A spec can be reviewed, shared, and iterated on before a single line of
implementation code is written. Frontend teams can start building against mock responses. Partner
teams can validate that the API meets their needs. Disagreements happen during design, not after
deployment.

**Stable contracts.** The spec changes only when you deliberately change it. Implementation
refactors -- renaming internal variables, restructuring packages, swapping out a database -- don't
ripple through to your API consumers. The contract is insulated from the implementation.

**Better documentation.** When the spec is hand-crafted (or visually designed), descriptions tend
to be meaningful. Code-first specs inherit whatever terse annotation values developers bothered to
write -- which, in our experience, ranges from "barely adequate" to "TODO: add description."

**Clean diffs.** Want to know what changed in your API between v2.3 and v2.4? Diff the spec file.
It's human-readable, it's authoritative, and it tells you exactly what consumers need to know.

## The Design-First Tax (And How to Eliminate It)

So if design-first is so great, why doesn't everyone do it? Because historically, it came with a
tax: you had to maintain the spec *and* the code, and keeping them in sync was your problem.
Write a beautiful spec, then hand-code all the boilerplate to match it. Change the spec, then
manually update the code. Forget a field? Enjoy your runtime bug.

This is the problem Apitomy was built to solve. The toolkit eliminates the design-first tax by
automating the path from spec to running code.

### Design: OpenAPI Editor

The pipeline starts with the
[OpenAPI Editor](https://github.com/Apitomy/apitomy-openapi-editor) -- a visual, browser-based
editor that lets you design your API without writing YAML or JSON by hand. Point and click to add
paths, define schemas, configure security, set up servers. Real-time validation catches mistakes as
you go. Undo and redo keep you safe.

### Design (AI-Native): Data Models MCP

But what if you're already doing most of your development through an AI coding agent? Maybe you're
pair-programming with Claude Code or Cursor, and switching to a separate visual editor feels like
leaving your flow. Does that mean you're stuck with code-first?

Not at all. The
[Data Models MCP Server](https://github.com/Apitomy/apitomy-data-models-mcp) brings design-first
API development directly into your AI-assisted workflow. It exposes over 100 spec-aware MCP tools
that let your AI assistant create, edit, and validate OpenAPI documents using structured operations
-- not raw YAML manipulation.

The difference matters. When an AI agent edits YAML directly, you're basically back to code-first
with extra steps: the agent writes what it thinks the spec should look like, and you hope it got
the structure right. With the MCP server, the agent works through the same Data Models library that
powers the visual editor -- proper schema-aware operations, built-in validation, no indentation
roulette.

In practice, this means you can tell your AI assistant "add a POST /users endpoint that accepts a
username and email, returns a 201 with the created user, and requires Bearer auth" and get a
spec-compliant result that's validated before it's written. You stay in your terminal, your agent
stays in its flow, and the spec stays correct.

Whether you reach for the visual editor or the MCP server, the principle is the same: design the
API first, get it right, then generate the code. The tool just adapts to how you prefer to work.

### Model: Data Models

Under both the editor and the MCP server sits
[Data Models](https://github.com/Apitomy/apitomy-data-models) -- the library that parses,
validates, and manipulates OpenAPI (and AsyncAPI) documents. It provides the typed object model,
the visitor pattern for traversal, and the 150+ validation rules that catch problems before they
reach production.

Data Models is also what makes the editor-to-codegen handoff seamless. The same library that
validates your spec in the editor is the same library that parses it during code generation.
There's no format mismatch, no version incompatibility, no "it worked in the editor but broke in
the build." One library, one model, one source of truth.

### Generate: Codegen

The last mile is [Codegen](https://github.com/Apitomy/apitomy-codegen), which takes your OpenAPI
spec and generates JAX-RS interfaces and data model beans for Quarkus. Drop the Maven plugin into
your build, point it at your spec, and `mvn compile` gives you type-safe interfaces with all the
annotations wired up:

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

Codegen generates **interfaces**, not implementations. You implement the interface with your
business logic; the generated code handles the contract. Change the spec? Re-run the build. The
compiler tells you exactly what broke -- no runtime surprises, no manual sync.

This is where design-first stops being a philosophy and starts being a workflow. The spec is
authoritative. The generated code enforces it. The compiler verifies your implementation matches.
The feedback loop is tight, automated, and hard to get wrong.

## The Full Loop

Put it all together and the design-first workflow looks like this:

1. **Design** your API in the OpenAPI Editor (or via the MCP server from your AI assistant)
2. **Validate** the spec using Data Models' built-in rules
3. **Generate** JAX-RS interfaces and models with Codegen
4. **Implement** your business logic against the generated interfaces
5. **Iterate** -- change the spec, re-generate, let the compiler catch the gaps

No YAML hand-editing. No annotation sprawl. No sync bugs. Just a spec that means what it says and
code that does what the spec says.

## Try It Out

All Apitomy projects are open source under the Apache License 2.0:

- [apitomy-openapi-editor](https://github.com/Apitomy/apitomy-openapi-editor) -- visual API design
- [apitomy-data-models](https://github.com/Apitomy/apitomy-data-models) -- spec parsing and
  validation
- [apitomy-data-models-mcp](https://github.com/Apitomy/apitomy-data-models-mcp) -- AI-assisted
  spec editing
- [apitomy-codegen](https://github.com/Apitomy/apitomy-codegen) -- code generation for
  Quarkus/JAX-RS

If you've been code-first and curious about switching, give the pipeline a spin. We think you'll
find that the design-first tax isn't much of a tax when the tools do the heavy lifting for you.
