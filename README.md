# LiveSveltePhoenix

A real-time collaborative document editing platform built with Phoenix LiveView and Svelte, featuring Operational Transformation (OT) for conflict-free multi-user editing.

## Overview

LiveSveltePhoenix is a production-ready collaborative editing system that enables multiple users to edit documents simultaneously with real-time synchronization. The application uses Delta Operational Transformation to ensure consistency and conflict resolution across all connected clients.

### Key Features

- Real-time collaborative editing with operational transformation
- Multi-user cursor tracking and presence awareness
- Automatic conflict resolution using Delta OT
- Asynchronous document snapshots via Oban
- ETS-based caching for performance optimization
- Rich text editing with Tiptap
- User authentication and session management
- Document versioning and history

## Architecture

### Technology Stack

**Backend:**
- Elixir 1.14+ / OTP 25+
- Phoenix Framework 1.7.14
- Phoenix LiveView for real-time updates
- Phoenix Channels for WebSocket communication
- PostgreSQL for data persistence
- Oban for background job processing
- ETS for in-memory caching

**Frontend:**
- Svelte components via LiveSvelte
- Tiptap rich text editor
- Delta.js for operational transformation
- Tailwind CSS for styling

**Core Libraries:**
- Delta (v0.4.1) for OT operations
- Oban (v2.17) for async jobs
- Ecto for database operations

### System Architecture

```mermaid
graph TB
    Browser[Web Browser<br/>Svelte/TipTap]
    Endpoint[Phoenix Endpoint]
    Channel[DocumentChannel<br/>WebSocket Handler]
    Document[CollaborativeDocument<br/>GenServer - OT Engine]
    Supervisor[DocumentSupervisor<br/>Process Management]
    DB[(PostgreSQL Database<br/>Sessions, Users, Oban Jobs)]
    Background[Background Processing<br/>Oban Workers, Snapshots, Cache]
    
    Browser -->|WebSocket| Endpoint
    Endpoint --> Channel
    Channel --> Document
    Document --> Supervisor
    Document --> DB
    Document --> Background
    Background --> DB
```

## Project Structure

```
live_svelte_phoenix/
├── lib/
│   ├── live_svelte_pheonix/
│   │   ├── application.ex              # OTP application supervisor
│   │   ├── collaborative_document.ex  # GenServer for document state & OT
│   │   ├── document_supervisor.ex     # Supervisor for document processes
│   │   ├── session.ex                  # Ecto schema for sessions
│   │   ├── cache.ex                    # ETS-based caching module
│   │   └── workers/
│   │       └── document_snapshot_worker.ex  # Oban worker for snapshots
│   └── live_svelte_pheonix_web/
│       ├── channels/
│       │   └── document_channel.ex     # Phoenix Channel for real-time sync
│       ├── live/
│       │   ├── session_live.ex        # LiveView for document sessions
│       │   └── create_session.ex      # LiveView for session management
│       ├── router.ex                   # Phoenix router
│       └── endpoint.ex                 # Phoenix endpoint configuration
├── assets/
│   ├── js/
│   │   ├── collaborative_client.js     # Phoenix Channel client wrapper
│   │   ├── delta.js                    # Delta OT implementation
│   │   └── collaboration-cursor.js    # Cursor tracking
│   └── svelte/
│       ├── Editor.svelte               # Main editor component
│       ├── status/
│       │   └── Session.svelte          # Session status component
│       └── invite/
│           └── InviteUser.svelte       # User invitation component
├── config/
│   ├── config.exs                     # Application configuration
│   ├── dev.exs                        # Development environment
│   ├── prod.exs                       # Production environment
│   └── runtime.exs                     # Runtime configuration
├── priv/
│   ├── repo/
│   │   └── migrations/                # Database migrations
│   └── static/                        # Static assets
└── test/                              # Test suite
```

## Data Flow

### Document Editing Flow

```mermaid
sequenceDiagram
    participant User
    participant Editor as Tiptap Editor
    participant Client as CollaborativeClient
    participant Channel as DocumentChannel
    participant Doc as CollaborativeDocument
    participant DB as PostgreSQL
    participant OtherClients as Other Clients
    
    User->>Editor: Types text
    Editor->>Editor: Generate Delta via fromTiptapTransaction()
    Editor->>Client: Queue as pendingChanges
    Client->>Channel: sendChange(delta, version, html)
    
    Channel->>Doc: update(delta, version, user_id, html)
    Doc->>Doc: Transform delta against current state
    Doc->>Doc: Compose with document contents
    Doc->>Doc: Increment version
    Doc->>DB: Persist delta and HTML
    Doc->>Channel: Return transformed delta
    
    Channel->>Client: Acknowledge with new version
    Channel->>OtherClients: Broadcast remote_update
    
    OtherClients->>OtherClients: Transform against pending changes
    OtherClients->>Editor: Apply transformed delta
    Editor->>User: Display updated content
```

### Initial Document Load Flow

```mermaid
sequenceDiagram
    participant User
    participant SessionLive
    participant Editor as Editor.svelte
    participant Channel as DocumentChannel
    participant Doc as CollaborativeDocument
    participant DB as PostgreSQL
    
    User->>SessionLive: Navigate to session
    SessionLive->>DB: Load session data
    DB-->>SessionLive: Return session
    SessionLive->>Editor: Mount with session data
    
    Editor->>Channel: Join document channel
    Channel->>Doc: get_state(doc_id)
    Doc->>DB: Load delta and HTML
    DB-->>Doc: Return content
    Doc-->>Channel: Return state (version, contents, html)
    Channel-->>Editor: Return initial state
    
    Editor->>Editor: Set isInitializing = true
    Editor->>Editor: Apply content (HTML > Delta > Fallback)
    Editor->>Editor: Normalize delta (remove leading retains)
    Editor->>Editor: Apply atomically
    Editor->>Editor: Set isInitializing = false
    Editor->>User: Display content
```

### Conflict Resolution

The system uses Operational Transformation (OT) with Delta format:

```mermaid
flowchart TD
    Start[Client sends change<br/>with version N] --> Check{Check version}
    
    Check -->|Client version < Server version| Transform[Transform delta against<br/>missed changes]
    Check -->|Client version = Server version| Direct[Apply directly]
    Check -->|Client version > Server version| Error[Return error<br/>Client out of sync]
    
    Transform --> Compose[Compose with<br/>document state]
    Direct --> Compose
    Compose --> Increment[Increment version]
    Increment --> Broadcast[Broadcast to all clients]
    
    Broadcast --> ClientTransform[Each client transforms<br/>remote delta against<br/>pending local changes]
    ClientTransform --> Converge[All clients converge<br/>to same state]
    
    Error --> End[End]
    Converge --> End
```

## Installation

### Prerequisites

- Elixir 1.14 or later
- Erlang/OTP 25 or later
- PostgreSQL 12 or later
- Node.js 18 or later
- npm or pnpm

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd live_svelte_phoenix
```

2. Install dependencies:
```bash
mix setup
```

This command will:
- Install Elixir dependencies
- Create and migrate the database
- Install Node.js dependencies
- Run database seeds

3. Configure environment variables:
```bash
cp .env.example .env.local
```

Edit `.env.local` with your database credentials:
```
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=your_password
PGDATABASE=live_svelte_phoenix_dev
```

4. Start the Phoenix server:
```bash
mix phx.server
```

Or start with IEx console:
```bash
iex -S mix phx.server
```

5. Visit `http://localhost:4000` in your browser

## Configuration

### Database

The application uses PostgreSQL. Configure connection in `config/dev.exs` or via environment variables:

```elixir
config :live_svelte_pheonix, LiveSveltePheonix.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: System.get_env("PGDATABASE", "live_svelte_phoenix_dev"),
  port: String.to_integer(System.get_env("PGPORT", "5432"))
```

### Oban

Oban is configured for background job processing:

```elixir
config :live_svelte_pheonix, Oban,
  repo: LiveSveltePheonix.Repo,
  queues: [default: 10, document_snapshots: 2],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7, limit: 10_000}
  ]
```

### Cache

ETS cache is used for session metadata and user session lists:

- Session list cache: 1 minute TTL
- Session metadata cache: 5 minutes TTL
- Automatic cleanup every 5 minutes

## Usage

### Creating a Session

1. Navigate to the home page
2. Click "New Session" or use the session creation form
3. Enter a session name
4. The session is created and you're redirected to the editor

### Collaborative Editing

1. Open a session in multiple browser windows/tabs
2. Each window represents a different user
3. Type in any window - changes appear in real-time in all windows
4. Cursor positions are shown for all active collaborators
5. Presence indicators show who is currently editing

### Session Management

- Sessions are persisted in the database
- Each session maintains:
  - Delta content (operational transformation format)
  - HTML snapshot (for fast initial load)
  - Version number (for conflict resolution)
  - Collaborator list
  - Last updated timestamp

### Background Jobs

Document snapshots are generated automatically:
- Triggered every 50 delta changes
- Runs asynchronously via Oban
- Generates full HTML and Delta snapshots
- Persists to database for fast recovery

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

### Database Migrations

Create a new migration:
```bash
mix ecto.gen.migration migration_name
```

Run migrations:
```bash
mix ecto.migrate
```

Rollback:
```bash
mix ecto.rollback
```

### Asset Compilation

Development (watch mode):
```bash
cd assets && npm run dev
```

Production build:
```bash
mix assets.deploy
```

### IEx Console

Start with console:
```bash
iex -S mix phx.server
```

Useful commands:
```elixir
# Get document state
LiveSveltePheonix.CollaborativeDocument.get_state("session-id")

# Get document contents
LiveSveltePheonix.CollaborativeDocument.get_contents("session-id")

# Check Oban jobs
Oban.Job |> LiveSveltePheonix.Repo.all() |> length()

# Check cache
LiveSveltePheonix.Cache.get_session_metadata("session-id")
```

## Deployment

### Production Build

1. Set environment variables:
```bash
export DATABASE_URL="postgresql://user:pass@host/dbname"
export SECRET_KEY_BASE="your-secret-key-base"
export PHX_HOST="your-domain.com"
```

2. Build assets:
```bash
MIX_ENV=prod mix assets.deploy
```

3. Compile:
```bash
MIX_ENV=prod mix compile
```

4. Run migrations:
```bash
MIX_ENV=prod mix ecto.migrate
```

5. Start server:
```bash
MIX_ENV=prod mix phx.server
```

### Docker

A Dockerfile is provided for containerized deployment:

```bash
docker build -t live_svelte_phoenix .
docker run -p 4000:4000 live_svelte_phoenix
```

### Environment Variables

Required for production:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key (generate with `mix phx.gen.secret`)
- `PHX_HOST` - Application hostname
- `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` - Database credentials

## Performance Considerations

### Caching Strategy

- User session lists are cached for 1 minute
- Session metadata is cached for 5 minutes
- Cache invalidation occurs on updates

### Database Optimization

- Delta contents are stored as JSON in `sessions.content`
- HTML snapshots are generated asynchronously
- Indexes should be added for frequently queried fields

### Scalability

- Each document runs in its own GenServer process
- Processes are supervised and can be distributed across nodes
- Phoenix PubSub enables horizontal scaling
- Oban workers can be scaled independently

## Troubleshooting

### Common Issues

**Document not syncing:**
- Check WebSocket connection in browser console
- Verify Phoenix Channel is connected
- Check server logs for errors

**Content duplication:**
- Ensure `isInitializing` flag is properly managed
- Verify version synchronization
- Check for conflicting delta operations

**Performance issues:**
- Monitor Oban queue sizes
- Check database query performance
- Review cache hit rates
- Consider increasing Oban worker concurrency

### Debugging

Enable debug logging:
```elixir
config :logger, level: :debug
```

Check document state:
```elixir
LiveSveltePheonix.CollaborativeDocument.get_state("doc-id")
```

Monitor Oban:
```elixir
Oban.check_queue(:document_snapshots)
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Add tests
4. Ensure code is formatted (`mix format`)
5. Run tests (`mix test`)
6. Submit a pull request

## Support

For issues and questions:
- Open an issue on the repository
- Check existing documentation
- Review code comments for implementation details
