# Shwapy Architecture Overview

## Core Flow

1. User uploads image/document/message
2. OCR service extracts text
3. AI service extracts structured payment intent
4. Validation service verifies fields and ambiguity
5. User reviews details
6. Payment execution can be initiated in later phases

## Backend Service Boundaries

- OCR service: extraction and normalization
- AI extraction service: convert noisy text to DTOs
- Validation service: safety and consistency checks
- Payment service: Daraja API interaction (phase 2)

## Safety Rules

- No automatic payment without user confirmation
- No guessed fields for critical values
- No silent amount modification
- Validation-first execution
