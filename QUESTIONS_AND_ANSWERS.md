# Questions & Answers

## Q: Is Google Translate API free or paid?
A: The official Google Cloud Translation API is a paid service (new accounts may have trial credits). The unofficial endpoint `translate.googleapis.com/translate_a/single` is not intended for production use.

## Q: What is the cost of the official API?
A:
- NMT (Basic v2 / Advanced v3):
  - first 500,000 characters per month are free
  - then $20 per 1,000,000 characters
- Translation LLM: $10 per 1,000,000 input and $10 per 1,000,000 output characters
- Adaptive Translation: $25 per 1,000,000 input and $25 per 1,000,000 output characters
- Documents (NMT): $0.08 per page

## Q: How do I connect to Google Cloud Translation API?
A:
1. Create a Google Cloud project and enable Billing.
2. Enable `Cloud Translation API`.
3. Create access credentials:
   - for quick testing: API key (v2),
   - for production: Service Account + backend proxy.
4. Send requests to the official Cloud Translation endpoint.

Example (v2):
```bash
curl -s -X POST "https://translation.googleapis.com/language/translate/v2?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "q": "Hello world",
    "source": "en",
    "target": "ru",
    "format": "text"
  }'
```
