# Shwapy Workspace and Engineering Context

## Mission

Shwapy is an AI-powered payment understanding platform that extracts payment intent from unstructured inputs and turns it into safe, structured payment instructions.

## Problem Focus

Users often copy paybill, till, account, and amount details manually between apps, causing delays and errors. Shwapy reduces this friction through OCR and AI-assisted extraction with validation-first workflows.

## Core User Flow

1. User uploads image, PDF, screenshot, or text source.
2. OCR extracts raw text.
3. AI extraction structures payment details.
4. Validation checks correctness and ambiguity.
5. User reviews and confirms details.
6. Payment execution is initiated only after explicit confirmation.

## Architecture Summary

### Backend

- PHP 8+, Laravel
- Service-oriented design using explicit service classes
- DTOs for structured extraction data
- Queue jobs for heavy OCR/AI processing

Key backend service domains:

- OCR service
- AI extraction service
- Validation service
- Payment service (Phase 2)

### Mobile

- Flutter app with Riverpod state management
- Priority on speed, simplicity, and minimal taps
- Primary consumer-facing channel

### Web

- React + Vite for admin, merchant dashboards, and analytics

## Safety Principles

- Never trigger payments without user confirmation.
- Never guess missing critical payment details.
- Never silently modify extracted amounts.
- Always validate OCR and AI output before payment execution.
- Never store M-Pesa PINs or expose secret keys.

## API Response Contract

Success format:

```json
{
  "success": true,
  "data": {}
}
```

Error format:

```json
{
  "success": false,
  "error": {
    "message": "Invalid account number"
  }
}
```

## Delivery Phases

### Phase 1 (Current)

- Image upload API
- OCR extraction
- Payment detail extraction
- Structured JSON output
- No payment integration yet

### Phase 2

- Daraja API integration
- M-Pesa STK Push
- Callback handling
- Payment history and transaction tracking

### Phase 3

- Enhanced AI understanding
- WhatsApp integration
- PDF parsing improvements
- Smart payment suggestions and merchant recognition

## Coding Standards

- Keep controllers thin.
- Keep business logic in service/action classes.
- Prefer dependency injection.
- Use explicit names (for example, PaymentExtractionService, MpesaStkService).
- Avoid generic names such as Helper, Functions, or Utils2.

## Immediate Pipeline Goal

1. Upload image
2. Extract OCR text
3. Parse payment details
4. Return structured JSON

After this becomes reliable, add STK Push, callback handling, and production-grade validation.
