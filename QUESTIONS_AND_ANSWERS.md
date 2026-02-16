# Questions & Answers

## Q: API Google Translate бесплатное или платное?
A: Официальный Google Cloud Translation API — платный сервис (для новых аккаунтов может быть trial/кредиты). Неофициальный endpoint `translate.googleapis.com/translate_a/single` не предназначен для production.

## Q: Какая стоимость официального API?
A:
- NMT (Basic v2 / Advanced v3):
  - первые 500,000 символов в месяц — бесплатно
  - далее $20 за 1,000,000 символов
- Translation LLM: $10 за 1,000,000 входных и $10 за 1,000,000 выходных символов
- Adaptive Translation: $25 за 1,000,000 входных и $25 за 1,000,000 выходных символов
- Документы (NMT): $0.08 за страницу

## Q: Как подключиться к Google Cloud Translation API?
A:
1. Создать проект в Google Cloud и включить Billing.
2. Включить `Cloud Translation API`.
3. Создать доступ:
   - для быстрого теста: API key (v2),
   - для production: Service Account + backend proxy.
4. Отправлять запросы к официальному endpoint Cloud Translation.

Пример (v2):
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
