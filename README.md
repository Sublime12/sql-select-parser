# Building a simple parser for a sql query

A hand-written SQL Lexer and Recursive Descent Parser built from scratch in 
**Zig**. This project demonstrates how to tokenize raw SQL strings and 
assemble them into a structured Abstract Syntax Tree (AST).

---

## 📂 Project Structure

```bash
.
├── build.zig          # Zig build configuration
├── src
│   ├── main.zig       # Demo entry point and tests
│   ├── parser.zig     # Lexer and Parser implementation
│   └── expression.zig # AST node definitions (Select, From, Where)
└── zig-out            # Compiled binary output
