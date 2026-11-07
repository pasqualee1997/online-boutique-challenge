# Architettura — Online Boutique

## Diagramma dei componenti

```mermaid
flowchart TD
    U[Utente] --> F[Frontend]
    F --> P[Catalogo prodotti]
    F --> C[Carrello]
    C --> R[Redis]
    F --> REC[Raccomandazioni]
    F --> A[Pubblicità]
    F --> V[Conversione valute]
    F --> CH[Checkout]
    CH --> PAY[Pagamento simulato]
    CH --> SH[Spedizione]
    CH --> E[Email]
    L[Load Generator] --> F
```

## Come funziona

L'utente accede al negozio tramite il frontend, che comunica con gli altri microservizi.

Il catalogo mostra i prodotti, il carrello utilizza Redis per conservare i dati e il checkout coordina pagamento, spedizione e conferma dell'ordine.

Le comunicazioni interne avvengono principalmente tramite gRPC, mentre il sito web utilizza HTTP.

Il Load Generator simula il traffico degli utenti.

Il progetto verrà eseguito su Kubernetes, con due ambienti logici separati: DEV e PROD.