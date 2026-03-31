# Toru Architecture Documentation

## Overview

Toru follows Clean Architecture principles with MVVM (Model-View-ViewModel) pattern, ensuring separation of concerns, testability, and maintainability.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│        Presentation Layer               │
│  (Screens, Widgets, ViewModels)         │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Domain Layer                    │
│  (Entities, Use Cases, Repositories)    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Data Layer                     │
│  (Models, Repositories, Data Sources)   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Services Layer                  │
│  (AI, Database, Notifications, Sync)    │
└─────────────────────────────────────────┘
```

## Core Services

### AIService
- Local LLM inference using llama.cpp
- Context management and memory injection
- Semantic search with embeddings

### DatabaseService
- SQLite for offline storage
- Tables: chat_messages, memories, appointments, reminders, saved_routes, sync_queue
- Optimized queries with indexes

### NotificationService
- Local notifications and alarms
- Recurring reminders support
- Platform-specific implementations

### SyncService
- Offline-first synchronization
- Conflict resolution strategies
- Network connectivity monitoring

## Design Patterns

- **MVVM**: Separation of UI and business logic
- **Repository Pattern**: Abstract data sources
- **Dependency Injection**: Provider pattern
- **Observer Pattern**: Reactive updates

## Database Schema

Key tables with relationships and indexes for performance optimization.

See full documentation in the codebase.
