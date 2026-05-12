# Shwapy

Shwapy is an AI-powered payment assistant that extracts payment details from unstructured inputs and returns structured, verifiable payment intent.

## Monorepo Structure

- `backend/`: Laravel-based APIs and payment intelligence services
- `mobile/`: Flutter mobile application
- `web/`: React + Vite web dashboard and admin tools
- `shared/`: Cross-platform shared contracts and assets
- `docs/`: Architecture and engineering documentation

## Immediate Goal (MVP Phase 1)

Build this pipeline:

1. Upload image
2. Extract OCR text
3. Parse payment details
4. Return structured JSON

Payments integration is intentionally deferred until Phase 2.

## Safety Principles

- Never trigger payments without explicit user confirmation.
- Never guess missing payment fields.
- Never silently modify extracted amounts.
- Always validate OCR and AI output before any payment action.

## Getting Started

This repository currently contains architecture-first scaffolding.

Planned project bootstrapping:

- Backend: Laravel app initialization in `backend/`
- Mobile: Flutter app initialization in `mobile/`
- Web: React + Vite initialization in `web/`

## Engineering References

- Architecture overview: `docs/architecture.md`
- MVP plan: `docs/mvp-plan.md`
- Environment variables template: `docs/environment.example.md`
