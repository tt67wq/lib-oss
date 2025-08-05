# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LibOss is an Elixir SDK for Aliyun OSS (Object Storage Service). It provides a comprehensive interface for interacting with OSS buckets and objects, including basic operations, multipart uploads, ACL management, and more.

## Build System & Common Commands

### Development Environment
```bash
# Initialize development environment
make setup

# Compile project
make build

# Run tests
make test

# Run tests in watch mode
make test.watch

# Start interactive shell
make repl
```

### Code Quality
```bash
# Check code formatting
make lint

# Format code automatically
make fmt
```

### Dependency Management
```bash
# Get all dependencies
make deps.get

# Update all dependencies
make deps.update.all

# Update specific dependency
make deps.update package_name

# Clean unused dependencies
make deps.clean

# Show dependency tree
make deps.tree
```

## Architecture

### Core Components

1. **LibOss** - Main module providing the public API through `use LibOss` macro
2. **LibOss.Core** - Core implementation with Agent for state management
3. **LibOss.Http** - Protocol defining HTTP client behavior
4. **LibOss.Http.Finch** - Finch-based HTTP client implementation
5. **LibOss.Supervisor** - OTP supervisor for managing processes
6. **LibOss.Model.Config** - Configuration validation using NimbleOptions
7. **LibOss.Model.Request** - Request building and OSS authentication
8. **LibOss.Typespecs** - Common type definitions

### Key Design Patterns

- **OTP Supervision**: Uses Supervisor with one-for-one strategy
- **Agent Pattern**: Core module uses Agent for configuration state management
- **Protocol**: Http protocol allows for different HTTP client implementations
- **Modular API Design**: API layer organized by functional domains for better maintainability
- **Delegation Pattern**: Main module delegates operations through API modules to Core module
- **Enhanced Configuration**: Multi-layer validation with runtime checks and environment-specific schemas

### Authentication Flow

The SDK implements OSS authentication through:
1. Request building with proper headers (Host, Content-Type, Content-MD5, Date)
2. String-to-sign construction following OSS specification
3. HMAC-SHA1 signing using access key secret
4. Authorization header generation

### File Structure

```
lib/
├── lib_oss.ex                 # Main public API (refactored)
├── lib_oss/
│   ├── api/                   # API layer (按功能域分离)
│   │   ├── object.ex          # Object operations API
│   │   ├── bucket.ex          # Bucket operations API
│   │   ├── multipart.ex       # Multipart upload API
│   │   ├── acl.ex             # ACL management API
│   │   ├── tagging.ex         # Tagging management API
│   │   ├── symlink.ex         # Symlink operations API
│   │   └── token.ex           # Token generation API
│   ├── core.ex               # Core business logic
│   ├── http.ex               # HTTP protocol definition
│   ├── supervisor.ex         # OTP supervisor
│   ├── typespecs.ex          # Type definitions
│   ├── exception.ex          # Custom exceptions
│   ├── debug.ex              # Debug utilities
│   ├── utils.ex              # Utility functions
│   ├── xml.ex                # XML processing utilities
│   ├── config/               # Configuration management
│   │   ├── validator.ex      # Enhanced configuration validator
│   │   └── manager.ex        # Configuration manager
│   ├── model/
│   │   ├── config.ex         # Configuration model
│   │   ├── http.ex           # HTTP request/response models
│   │   └── request.ex        # OSS request model
│   └── http/
│       └── finch.ex          # Finch HTTP client
```

## Usage Pattern

### Client Setup
```elixir
defmodule MyOss do
  use LibOss, otp_app: :my_app
end

# Configuration
config :my_app, MyOss,
  endpoint: "oss-cn-somewhere.aliyuncs.com",
  access_key_id: "your_access_key_id",
  access_key_secret: "your_access_key_secret"
```

### Supervisor Integration
```elixir
children = [
  MyOss
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Supported Operations

### Object Operations (`LibOss.Api.Object`)
- Basic CRUD: put, get, delete objects
- Copy objects between buckets
- Append write functionality
- Metadata retrieval (head, get_object_meta)

### Access Control Management (`LibOss.Api.Acl`)
- Object ACL management
- Bucket ACL management

### Symlink Operations (`LibOss.Api.Symlink`)
- Create symbolic links
- Retrieve symlink targets

### Tagging Operations (`LibOss.Api.Tagging`)
- Set/update object tags
- Retrieve object tags
- Delete object tags

### Multipart Upload (`LibOss.Api.Multipart`)
- Initiate multipart upload
- Upload individual parts
- Complete multipart upload
- Abort multipart upload
- List multipart uploads
- List uploaded parts

### Bucket Operations (`LibOss.Api.Bucket`)
- Create/delete buckets
- List bucket contents (v1 and v2)
- Bucket information retrieval
- Bucket location and statistics

### Web Upload Token Generation (`LibOss.Api.Token`)
- Generate signed tokens for direct browser uploads
- Support for callback URLs

## Configuration Requirements

The SDK requires three mandatory configuration parameters:
- `endpoint`: OSS endpoint (e.g., "oss-cn-somewhere.aliyuncs.com")
- `access_key_id`: Aliyun access key ID
- `access_key_secret`: Aliyun access key secret

## Dependencies

Key dependencies and their purposes:
- **finch**: HTTP client for making requests
- **nimble_options**: Configuration validation
- **jason**: JSON encoding/decoding
- **sweet_xml**: XML parsing for OSS responses (replaced elixir_xml_to_map for better stability)
- **mime**: Content-Type detection

## Testing

Tests are located in `test/` directory. Use `make test` to run the full test suite or `make test.watch` for development with automatic test execution on file changes.

## Documentation

The project uses ExDoc for documentation generation. The main module documentation is sourced from README.md, and individual functions have comprehensive docstrings with examples and Aliyun OSS documentation links.