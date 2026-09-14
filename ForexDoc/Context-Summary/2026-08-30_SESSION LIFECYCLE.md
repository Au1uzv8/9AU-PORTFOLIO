┌─────────────────────────────────────────────────────────────┐
│                    SESSION LIFECYCLE                        │
└─────────────────────────────────────────────────────────────┘

  🚀 SESSION START
         │
         ▼
  ┌─────────────┐    Load   ┌──────────────┐
  │   Memory    │◄──────────│  Snapshot    │
  │  (Context)  │           │  MEM-{id}    │
  └──────┬──────┘           └──────────────┘
         │                         ▲
         │ confirm context         │ save
         ▼                         │
  ┌─────────────┐         ┌────────┴─────────┐
  │  CHECKPOINT │         │  AUTO-SUMMARY    │
  │  CKP-{id}   │         │  + SYNC ENGINE   │
  │             │         └──────────────────┘
  │  Tasks:     │                  ▲
  │  □ Task 1   │                  │ trigger
  │  □ Task 2   │─────────────────►│ on complete
  │  □ Task 3   │
  └──────┬──────┘
         │ outputs
         ▼
  ┌─────────────┐    link   ┌──────────────┐
  │  KB Entries │◄──────────│   Mission    │
  │  KB-{id}    │           │   MSN-{id}   │
  └─────────────┘           └──────────────┘
         │
         │ update
         ▼
  ┌─────────────┐
  │  KB INDEX   │ ← searchable / filterable
  └─────────────┘