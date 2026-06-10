---
layout: post
title: "Programmatically Manipulating OpenAPI Documents in Java and TypeScript"
date: 2026-06-10
author: Eric Wittmann
---

There comes a point in every API team's life where you need to do something *programmatic* with
your OpenAPI specs. Maybe you're building a custom linter. Maybe you need to merge specs from
multiple services. Maybe you want to auto-generate changelog entries from spec diffs, or enforce
naming conventions across dozens of APIs. Whatever the use case, you need a library that can read,
manipulate, and validate OpenAPI documents through code -- not just render them in a UI.

[Apitomy Data Models](https://github.com/Apitomy/apitomy-data-models) is exactly that library. It
provides a rich, typed object model for OpenAPI (2.0 through 3.2) and AsyncAPI (2.0 through 3.1)
documents, available in both Java and TypeScript from a single codebase. Let's walk through the
basics.

## Getting Started

**Java (Maven):**

```xml
<dependency>
    <groupId>io.apitomy</groupId>
    <artifactId>apitomy-data-models</artifactId>
    <version>3.1.0</version>
</dependency>
```

**TypeScript/JavaScript (npm):**

```bash
npm install @apitomy/data-models
```

The npm package has zero runtime dependencies, so it won't bloat your bundle.

## Reading a Document

Everything starts with the `Library` class. Hand it a JSON string and it auto-detects the spec
type and version:

**Java:**

```java
import io.apitomy.datamodels.Library;
import io.apitomy.datamodels.models.openapi.v3x.v30.OpenApi30Document;

String json = Files.readString(Path.of("petstore.json"));
OpenApi30Document doc = (OpenApi30Document) Library.readDocumentFromJSONString(json);

System.out.println(doc.getInfo().getTitle());   // "Swagger Petstore"
System.out.println(doc.getInfo().getVersion());  // "1.0.0"
```

**TypeScript:**

```typescript
import { Library, OpenApi30Document } from "@apitomy/data-models";

const json = fs.readFileSync("petstore.json", "utf-8");
const doc = Library.readDocumentFromJSONString(json) as OpenApi30Document;

console.log(doc.getInfo().getTitle());   // "Swagger Petstore"
console.log(doc.getInfo().getVersion()); // "1.0.0"
```

The API is essentially identical across languages -- same class names, same method names. If you
know one, you know both.

## Creating a Document from Scratch

You can also build a spec programmatically:

```java
import io.apitomy.datamodels.models.ModelType;

OpenApi30Document doc = (OpenApi30Document) Library.createDocument(ModelType.OPENAPI30);
doc.setInfo(doc.createInfo());
doc.getInfo().setTitle("My API");
doc.getInfo().setVersion("1.0");

String output = Library.writeDocumentToJSONString(doc);
```

This produces:

```json
{
    "openapi": "3.0.3",
    "info": {
        "title": "My API",
        "version": "1.0"
    }
}
```

The library handles the boilerplate -- `"openapi": "3.0.3"` is set automatically based on the
model type.

## Traversing with the Visitor Pattern

This is where things get interesting. The visitor pattern lets you walk the entire document tree
and act on specific node types. Need to find every operation across all paths? Count all schemas?
Collect every `$ref`? Visitors make it straightforward.

The key class is `CombinedVisitorAdapter`, which provides no-op implementations for every node
type in the spec. You extend it and override only the visit methods you care about. Want to count
operations? Override `visitOperation()`:

```java
import io.apitomy.datamodels.VisitorUtil;
import io.apitomy.datamodels.TraverserDirection;
import io.apitomy.datamodels.models.Operation;
import io.apitomy.datamodels.models.visitors.CombinedVisitorAdapter;

public class OperationCounter extends CombinedVisitorAdapter {
    public int count = 0;

    @Override
    public void visitOperation(Operation node) {
        count++;
    }
}

// Usage:
OperationCounter counter = new OperationCounter();
VisitorUtil.visitTree(doc, counter, TraverserDirection.down);
System.out.println("Operations: " + counter.count);
```

The adapter has typed visit methods for every node in the spec -- `visitPathItem()`,
`visitSchema()`, `visitResponse()`, `visitInfo()`, and so on. The library handles the traversal;
you just react to the nodes you're interested in. No `instanceof` checks, no manual tree walking.

There's also `AllNodeVisitor` for cases where you don't care about specific types and just want
every node routed to a single `visitNode()` method -- useful for things like node counting or
generic tree analysis.

You can also use `NodePath` to navigate directly to a specific part of the document using an
XPath-like syntax:

```java
import io.apitomy.datamodels.paths.NodePath;

NodePath path = NodePath.parse("/paths[/pets]/get/responses[200]");
VisitorUtil.visitPath(doc, path, myVisitor);
```

This visits only the nodes along that path -- handy when you know exactly where you need to go.

## Validating a Document

Validation is a one-liner that returns a list of problems:

```java
import io.apitomy.datamodels.validation.ValidationProblem;

List<ValidationProblem> problems = Library.validate(doc, null);

for (ValidationProblem problem : problems) {
    System.out.printf("[%s] %s: %s at %s%n",
        problem.severity,
        problem.errorCode,
        problem.message,
        problem.nodePath.toString());
}
```

Each `ValidationProblem` includes a machine-readable error code (like `SCH-001` or `REQ-001`), a
severity level (Error, Warning, Information, Hint), a human-readable message, and the node path
pointing to the exact location in the document. The library ships with 150+ validation rules
covering the full OpenAPI and AsyncAPI specifications.

Pass `null` for the severity registry to use defaults, or implement `IValidationSeverityRegistry`
to customize which rules are errors vs. warnings for your organization.

## Writing It Back Out

After reading and manipulating a document, serialize it back to JSON:

**Java:**

```java
// To a JSON string (formatted)
String json = Library.writeDocumentToJSONString(doc);

// To a Jackson ObjectNode (for further processing)
ObjectNode node = (ObjectNode) Library.writeNode(doc);
```

**TypeScript:**

```typescript
// To a plain JS object
const obj = Library.writeNode(doc);

// Then to a string
const json = JSON.stringify(obj, null, 2);
```

The output is deterministic -- same document always produces the same JSON -- which makes diffs
clean and merge conflicts meaningful.

## Transforming Between Versions

Got a Swagger 2.0 spec that needs to be OpenAPI 3.0? The library handles version conversion (where's your surgeon?):

```java
import io.apitomy.datamodels.models.ModelType;

Document openapi30 = Library.transformDocument(swagger20Doc, ModelType.OPENAPI30);
```

This works across supported version pairs (2.0 to 3.0/3.1/3.2, 3.0 to 3.1/3.2, and AsyncAPI
upgrades). The original document is unchanged -- you get a new document back.

## Putting It All Together

Here's a practical example: a simple tool that reads a spec, validates it, reports any issues, and
writes a cleaned-up version:

```java
// Read the spec
Document doc = Library.readDocumentFromJSONString(
    Files.readString(Path.of("api.json")));

// Validate
List<ValidationProblem> problems = Library.validate(doc, null);
if (!problems.isEmpty()) {
    System.out.println("Found " + problems.size() + " issues:");
    problems.forEach(p ->
        System.out.printf("  [%s] %s: %s%n", p.severity, p.errorCode, p.message));
}

// Clone and transform to latest OpenAPI version
Document upgraded = Library.transformDocument(doc, ModelType.OPENAPI31);

// Write out the upgraded spec
String output = Library.writeDocumentToJSONString(upgraded);
Files.writeString(Path.of("api-upgraded.json"), output);
```

## What Can You Build With This?

The library is intentionally low-level -- it gives you the building blocks, not the finished
product. Some ideas for what you can build on top of it:

- **Custom linters** that enforce your organization's API naming conventions
- **Spec merging tools** that combine microservice APIs into a single gateway spec
- **Changelog generators** that diff two versions of a spec and produce human-readable release notes
- **Migration scripts** that upgrade a fleet of Swagger 2.0 specs to OpenAPI 3.1
- **Documentation extractors** that pull operation metadata into other systems

The same library powers the [Apitomy OpenAPI Editor](https://github.com/Apitomy/apitomy-openapi-editor),
[Codegen](https://github.com/Apitomy/apitomy-codegen), and the
[Data Models MCP Server](https://github.com/Apitomy/apitomy-data-models-mcp) -- so you're
building on the same foundation as the rest of the toolkit.

## Learn More

- [GitHub Repository](https://github.com/Apitomy/apitomy-data-models)
- [npm package: @apitomy/data-models](https://www.npmjs.com/package/@apitomy/data-models)
- [Maven Central: io.apitomy:apitomy-data-models](https://central.sonatype.com/artifact/io.apitomy/apitomy-data-models)
