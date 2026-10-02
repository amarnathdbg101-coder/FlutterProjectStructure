# 🏛️ Flutter Architecture Blueprint

This template strictly follows the **Feature-Driven Repository-Controller Pattern**, mirroring Go backend clean architecture:

```
[ UI Screen / Widget ]
         │
         ▼
[ Controller (ChangeNotifier) ] ──▶ Holds State (isLoading, items, error)
         │
         ▼
[ Repository ]                 ──▶ Makes HTTP calls via Dio
         │
         ▼
[ ApiClient + AuthInterceptor ] ──▶ Injects Bearer <token> & headers
         │
         ▼
[ Go Backend API ]             ──▶ https://localhost:8080
```
