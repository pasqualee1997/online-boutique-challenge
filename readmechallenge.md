# Challenge Tecnica L2 — Online Boutique

## 1. Scelta dell'applicazione

Ho scelto **Online Boutique**, un'applicazione open source di Google che simula un negozio online.

Repository originale: https://github.com/GoogleCloudPlatform/microservices-demo

Ho scelto questa applicazione perché:
- È composta da più microservizi.
- È progettata per funzionare su Kubernetes.
- Permette di simulare acquisti e verificare il funzionamento dell'applicazione.
- È consigliata nella traccia della challenge.

Per la challenge utilizzerò Online Boutique per realizzare due ambienti, DEV e PROD, e dimostrare deploy, configurazione, monitoraggio e gestione degli errori.

## 2. Architettura dell'applicazione

Online Boutique è un negozio online composto da microservizi, ciascuno con una funzione specifica.

- **frontend:** mostra il negozio agli utenti.
- **productcatalogservice:** gestisce il catalogo prodotti.
- **cartservice:** gestisce il carrello.
- **checkoutservice:** coordina gli acquisti.
- **paymentservice:** simula i pagamenti.
- **shippingservice:** gestisce le spedizioni.
- **currencyservice:** converte le valute.
- **recommendationservice:** suggerisce prodotti.
- **adservice:** fornisce annunci pubblicitari.
- **emailservice:** simula l'invio delle email.
- **loadgenerator:** simula utenti che visitano il negozio.
- **shoppingassistantservice:** componente aggiuntivo per l'assistenza agli acquisti.

I microservizi comunicano principalmente tramite gRPC. Il frontend espone l'interfaccia web tramite HTTP.

Il carrello utilizza Redis come archivio temporaneo dei dati.

## 3. Cluster Kubernetes e ambienti

Per eseguire Online Boutique ho creato un cluster Kubernetes locale utilizzando **Kind** e **Docker Desktop**.

Il cluster si chiama `prova` e contiene un nodo chiamato `prova-control-plane`.

Ho creato due namespace:
- `dev`: ambiente dedicato ai test.
- `prod`: ambiente che simula la produzione.

I due ambienti sono separati logicamente, ma condividono lo stesso cluster.

### Comandi utilizzati

```bash
kind create cluster --name prova
kubectl get nodes
kubectl create namespace dev
kubectl create namespace prod
kubectl get namespaces
```

### Label e selector

Per verificare come Kubernetes collega i Service ai Pod, sono stati eseguiti i comandi:

```cmd
kubectl get pods -n dev --show-labels
kubectl describe svc frontend -n dev
```

Il Pod frontend possiede la label `app=frontend` e il Service frontend utilizza il selector `app=frontend`.

Il Service riceve le richieste sulla porta 80 e le inoltra alla porta 8080 del Pod. La presenza dell'endpoint `10.244.0.11:8080` conferma che il Service ha individuato il Pod corretto.

La verifica è stata effettuata senza modificare le risorse del cluster.

### Verifica

Il nodo `prova-control-plane` risulta `Ready`.

I namespace `dev` e `prod` risultano entrambi `Active`.

## 4. Test dell'applicazione in DEV

Ho installato Online Boutique nel namespace `dev`.

kubectl apply -f release/kubernetes-manifests-dev.yaml -n dev
kubectl get pods -n dev
kubectl get svc -n dev

Ho verificato che tutti i 12 Pod risultassero pronti (`READY 1/1`) e che i Service fossero stati creati.

Per accedere all'applicazione dal browser ho utilizzato:

```bash
kubectl port-forward svc/frontend 8080:80 -n dev
```

Il comando collega la porta 8080 del computer alla porta 80 del Service frontend.

Ho aperto `http://localhost:8080` e simulato un ordine, fino alla comparsa del messaggio **"Your order is complete"**.

**Risultato:** test funzionale del percorso di acquisto completato con successo nell'ambiente DEV.

## 5. Installazione e test in PROD

Ho installato Online Boutique anche nel namespace `prod`, utilizzando il file `kubernetes-manifests.yaml`.

Comandi utilizzati:

```bash
kubectl apply -f release/kubernetes-manifests.yaml -n prod
kubectl get pods -n prod
kubectl port-forward svc/frontend 8081:80 -n prod
```

Ho verificato che i Pod fossero pronti e ho aperto l'applicazione all'indirizzo `http://localhost:8081`.

Ho testato il funzionamento dell'applicazione nell'ambiente PROD.

Gli ambienti DEV e PROD sono separati tramite namespace Kubernetes, ma utilizzano lo stesso cluster locale.

## 6. Verifica dei log applicativi

### Requisito
Verificare che l'applicazione produca log utili per il monitoraggio e il troubleshooting.

### Attività svolta
Ho analizzato i log del microservizio `frontend` nell'ambiente DEV utilizzando il comando:

```bash
kubectl logs deployment/frontend -n dev --tail=1
```

Il comando mostra l'ultima riga di log del Deployment frontend.

### Risultato
Ho ottenuto un log strutturato in formato JSON contenente informazioni come:

- `http.req.method`: metodo HTTP utilizzato (`GET`).
- `http.req.path`: percorso richiesto (`/`).
- `http.resp.status`: codice di risposta HTTP (`200`).
- `http.resp.took_ms`: tempo di risposta (`14` millisecondi).
- `severity`: livello del log (`debug`).
- `timestamp`: data e ora dell'evento.

### Verifica
Il frontend ha prodotto un log leggibile e strutturato. La richiesta analizzata è terminata con codice HTTP `200`, quindi con esito positivo.

Ho salvato anche uno screenshot della verifica nel file `log-frontend.png`.

## 7. Verifica delle readiness e liveness probe

### Requisito
Verificare la presenza di controlli per determinare se un container è pronto a ricevere traffico e se è ancora funzionante.

### Attività svolta
Ho esaminato la configurazione del Deployment `frontend` nell'ambiente DEV tramite:

```bash
kubectl describe deployment frontend -n dev
```

### Risultato
Ho verificato che il frontend utilizza entrambe le probe:

- **Readiness probe:** verifica se il container è pronto a ricevere traffico.
- **Liveness probe:** verifica se il container è funzionante e permette a Kubernetes di riavviarlo in caso di fallimenti ripetuti.

Entrambe utilizzano l'endpoint HTTP `/_healthz` sulla porta `8080`.

I parametri osservati sono:

- `delay=10s`: prima verifica dopo 10 secondi.
- `period=10s`: verifica ripetuta ogni 10 secondi.
- `timeout=1s`: tempo massimo di attesa della risposta.
- `success=1`: una verifica riuscita è sufficiente.
- `failure=3`: soglia di tre fallimenti consecutivi.

### Verifica
La configurazione delle readiness e liveness probe è presente nel Deployment frontend.

I Pod dell'applicazione erano stati verificati in stato `READY 1/1`, confermando che risultavano pronti al momento del controllo.

## 8. Metrica applicativa: tempo medio di risposta

Per verificare le prestazioni dell'applicazione ho scelto di misurare il **tempo medio di risposta del frontend** nell'ambiente DEV.

Il frontend registra nei log il tempo impiegato per completare ogni richiesta HTTP, attraverso il campo `http.resp.took_ms`, espresso in millisecondi.

Ho creato il file `metrica.ps1` nella cartella principale del progetto. Lo script esegue quattro operazioni:

1. Recupera gli ultimi 100 messaggi dei log del frontend.
2. Seleziona soltanto le richieste completate, riconoscibili dalla scritta `request complete`.
3. Estrae da ogni richiesta il tempo di risposta in millisecondi.
4. Calcola la media dei tempi ottenuti.

### Comando utilizzato

Dalla cartella principale del progetto, in PowerShell:

```powershell
.\metrica.ps1
```

### Risultato della verifica

```text
Count    : 33
Average  : 22,2424242424242
```

- **Count:** 33 richieste completate analizzate.
- **Average:** tempo medio di risposta di circa **22,24 millisecondi**.

### Verifica

Lo script è stato eseguito correttamente e ha restituito il numero di richieste analizzate e il loro tempo medio di risposta.

Questa misurazione è ottenuta **analizzando i log applicativi**: non si tratta di un sistema di monitoraggio continuo. Il calcolo può essere ripetuto eseguendo nuovamente lo script e i risultati possono cambiare in base alle richieste presenti nei log.s

## 9. Gestione della configurazione: ConfigMap e Secret

### Obiettivo

In Kubernetes, le ConfigMap e i Secret permettono di separare alcune informazioni di configurazione dai Deployment.

In questa challenge abbiamo utilizzato entrambi nel namespace `dev`, senza modificare l'ambiente `prod`.

### 9.1 ConfigMap

Abbiamo creato una ConfigMap chiamata `frontend-config` per conservare l'indirizzo del servizio che gestisce il catalogo dei prodotti.

La ConfigMap contiene:

- **Chiave:** `PRODUCT_CATALOG_SERVICE_ADDR`
- **Valore:** `productcatalogservice:3550`

Comando utilizzato:

```bash
kubectl create configmap frontend-config --from-literal=PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550 -n dev
```

Successivamente abbiamo modificato il Deployment del frontend nel file `release/kubernetes-manifests-dev.yaml`, sostituendo il valore scritto direttamente nel Deployment con un riferimento alla ConfigMap:

```yaml
- name: PRODUCT_CATALOG_SERVICE_ADDR
  valueFrom:
    configMapKeyRef:
      name: frontend-config
      key: PRODUCT_CATALOG_SERVICE_ADDR
```

In questo modo Kubernetes recupera il valore dalla ConfigMap e lo fornisce al container come variabile d'ambiente.

### 9.2 Secret

Abbiamo creato un Secret dimostrativo chiamato `frontend-secret` per mostrare come Kubernetes può fornire un valore riservato a un container.

Il Secret contiene:

- **Chiave:** `DEMO_PASSWORD`
- **Valore:** una password dimostrativa.

Comando utilizzato:

```bash
kubectl create secret generic frontend-secret --from-literal=DEMO_PASSWORD=INSERIRE_PASSWORD_PERSONALE -n dev
```

Nel Deployment del frontend abbiamo aggiunto:

```yaml
- name: DEMO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: frontend-secret
      key: DEMO_PASSWORD
```

Kubernetes legge il valore associato alla chiave `DEMO_PASSWORD` e lo rende disponibile al container attraverso una variabile d'ambiente.

**Limite della dimostrazione:** il frontend riceve questa variabile, ma non utilizza la password per autenticarsi ad altri servizi. Il Secret non introduce quindi, da solo, un controllo di accesso. Non abbiamo attivato l'autenticazione Redis.

Inoltre, i Secret Kubernetes non sono automaticamente cifrati solo perché si chiamano Secret: la codifica Base64 non equivale a cifratura. In un ambiente reale occorre gestire anche i permessi di accesso, la protezione dei dati e le modalità di distribuzione delle credenziali.

### 9.3 Verifica

Abbiamo controllato la presenza delle risorse nel namespace DEV:

```bash
kubectl get configmap -n dev
kubectl get secrets -n dev
```

Abbiamo poi verificato la configurazione del frontend:

```bash
kubectl describe deployment frontend -n dev
```

Nella sezione `Environment` abbiamo confermato che:

- `PRODUCT_CATALOG_SERVICE_ADDR` viene letto dalla ConfigMap `frontend-config`.
- `DEMO_PASSWORD` viene letto dal Secret `frontend-secret`.

Prima dell'applicazione definitiva abbiamo corretto un errore di indentazione YAML e utilizzato il controllo:

```bash
kubectl apply --dry-run=server -f kubernetes-manifests-dev.yaml -n dev
```

Dopo la validazione abbiamo applicato la configurazione:

```bash
kubectl apply -f kubernetes-manifests-dev.yaml -n dev
```

Infine, abbiamo verificato che i Pod fossero funzionanti.

### 9.4 Considerazioni

La ConfigMap è adatta a informazioni non riservate, come gli indirizzi dei servizi.

Il Secret è pensato per informazioni sensibili, come password e credenziali.

In entrambi i casi, il Deployment può leggere i valori attraverso `valueFrom`, utilizzando rispettivamente `configMapKeyRef` e `secretKeyRef`.

Per questa dimostrazione abbiamo creato le risorse direttamente nel cluster DEV. Per rendere il progetto completamente riproducibile, in una fase successiva sarà opportuno definire anche la ConfigMap e il Secret dimostrativo tramite manifest dedicati, evitando di inserire credenziali reali nel repository.

## 10. Analisi del codice applicativo — Requisito 4.1

Per la challenge è stata scelta l'applicazione open source **Google Cloud Online Boutique**, composta da più microservizi.

Il codice sorgente dei servizi si trova nella cartella `src` del repository.

### Analisi del frontend

Il servizio `frontend` gestisce l'interfaccia web del negozio ed è sviluppato nel linguaggio **Go**.

Nel file `src/frontend/Dockerfile` abbiamo individuato:

- L'utilizzo di Go per compilare il programma.
- Il comando `go mod download` per scaricare le dipendenze.
- Il comando `go build` per costruire l'eseguibile.
- Una seconda fase con immagine `distroless`, per eseguire il programma.
- La porta `8080`, dichiarata tramite `EXPOSE`.

### Analisi del cartservice

Il servizio `cartservice` gestisce il carrello degli acquisti ed è sviluppato in **C# con .NET**.

Il servizio comunica con Redis per la gestione dei dati del carrello.

Nel file `src/cartservice/Dockerfile` abbiamo individuato:

- Il comando `dotnet restore` per recuperare le dipendenze.
- Il comando `dotnet publish` per preparare l'applicazione.
- Una seconda fase con l'ambiente necessario all'esecuzione.
- La porta `7070`, dichiarata tramite `EXPOSE`.
- L'istruzione `USER 1000`, che permette di eseguire il programma senza utilizzare l'utente root.

### Considerazioni

L'analisi ha mostrato che Online Boutique utilizza microservizi sviluppati con linguaggi differenti, ma distribuiti attraverso container.

I Dockerfile esaminati utilizzano una costruzione in più fasi (*multi-stage build*), separando la compilazione dall'esecuzione dell'applicazione.

Questa organizzazione permette di preparare immagini dedicate ai singoli servizi e di distribuirle su Kubernetes.

## 11. Containerizzazione — Requisito 4.2

Per verificare la containerizzazione dell'applicazione Online Boutique, è stato utilizzato il Dockerfile originale del servizio `frontend`, scritto in Go.

### Build dell'immagine Docker

Dalla cartella principale del progetto è stato eseguito il comando:

```cmd
docker build -t fasullo-immagine -f src/frontend/Dockerfile src/frontend
```

Il comando costruisce l'immagine Docker del frontend e le assegna il nome `fasullo-immagine`.

La build è stata completata correttamente.

### Verifica dell'immagine

È stato eseguito:

```cmd
docker images fasullo-immagine
```

Docker ha confermato la presenza dell'immagine `fasullo-immagine:latest`.

### Prova di avvio del container

Per verificare l'avvio locale è stato utilizzato:

```cmd
docker run -d --name prova-frontend -p 9090:8080 fasullo-immagine
```

Il container è stato creato, ma si è arrestato con stato `Exited (2)`.

### Analisi dell'errore

Per individuare la causa sono stati eseguiti:

```cmd
docker ps -a --filter name=prova-frontend
docker logs prova-frontend
```

Nei log è stato individuato il seguente errore:

```text
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set
```

Il frontend richiede una variabile d'ambiente che indichi dove trovare il servizio del catalogo prodotti.

La build dell'immagine è quindi riuscita, mentre l'avvio locale non è stato completato perché mancava una configurazione necessaria.

Su Kubernetes gli indirizzi dei microservizi vengono forniti attraverso le variabili d'ambiente definite nei Deployment.

### Risultato

È stata dimostrata la costruzione riproducibile dell'immagine Docker del frontend e l'analisi di un errore di configurazione durante l'avvio.

Rimane da completare la verifica dell'esecuzione locale del container con le configurazioni necessarie.

### 11.1 Soluzione: utilizzo dell'immagine Docker nel cluster Kind

Dopo aver costruito l'immagine Docker personalizzata `fasullo-immagine:latest`, è stato effettuato un test di avvio locale.

Il frontend si avviava correttamente dopo aver configurato le variabili d'ambiente, ma il browser restituiva un errore HTTP 500 perché gli altri microservizi non erano raggiungibili dal container Docker isolato.

Per risolvere il problema, è stata utilizzata l'immagine personalizzata nel cluster Kubernetes Kind già configurato, dove tutti i microservizi di Online Boutique erano disponibili.

**1. Caricamento dell'immagine nel cluster Kind**

```cmd
kind load docker-image fasullo-immagine:latest --name prova
```

Il comando ha caricato l'immagine Docker nel cluster locale `prova`.

La presenza dell'immagine è stata verificata con:

```cmd
docker exec prova-control-plane crictl images
```

Nell'elenco è stata individuata l'immagine `docker.io/library/fasullo-immagine` con tag `latest`.

**2. Aggiornamento del frontend DEV**

```cmd
kubectl set image deployment/frontend server=fasullo-immagine:latest -n dev
```

Il comando ha aggiornato il Deployment `frontend` nell'ambiente DEV, sostituendo l'immagine precedente con quella personalizzata.

L'ambiente PROD non è stato modificato.

**3. Verifica dell'aggiornamento**

```cmd
kubectl rollout status deployment/frontend -n dev --timeout=120s
```

Risultato:

```text
deployment "frontend" successfully rolled out
```

Questo risultato conferma che Kubernetes ha completato correttamente l'aggiornamento del frontend.

**4. Test funzionale dell'applicazione**

Per accedere al negozio dal browser è stato eseguito:

```cmd
kubectl port-forward -n dev service/frontend 8082:80
```

Successivamente è stato aperto l'indirizzo:

http://localhost:8082

Il negozio è risultato funzionante. È stato possibile visualizzare i prodotti, procedere con un acquisto simulato e raggiungere la schermata finale:

```text
Your order is complete!
```

**5. Conclusioni**

La prova ha dimostrato che:

- Il Dockerfile del frontend permette di costruire un'immagine applicativa personalizzata.
- L'immagine `fasullo-immagine:latest` è stata caricata correttamente nel cluster Kind.
- Il Deployment frontend DEV è stato aggiornato con successo.
- Il frontend ha comunicato correttamente con gli altri microservizi.
- Il test di acquisto simulato è stato completato.
- L'ambiente PROD non è stato modificato.

Il test con Docker standalone ha evidenziato la necessità di configurare le dipendenze del frontend. Il funzionamento completo dell'applicazione è stato invece verificato nel cluster Kubernetes locale, utilizzando l'immagine personalizzata.

## 11.2 — Kubernetes: RBAC e Ingress (ambiente DEV)

### Gestione dei permessi con RBAC

È stato creato il file `rbac-dev.yaml` per configurare il controllo degli accessi nel namespace `dev`.

Il file definisce tre risorse Kubernetes:

- **ServiceAccount `lettore-pod`**: identità Kubernetes utilizzata per dimostrare la gestione dei permessi.
- **Role `lettura-pod`**: autorizza esclusivamente le operazioni `get` e `list` sui Pod.
- **RoleBinding `assegna-lettura-pod`**: associa il Role alla ServiceAccount.

La configurazione è stata verificata tramite `kubectl apply --dry-run=server` e successivamente applicata al cluster.

Sono stati eseguiti due test:

```cmd
kubectl auth can-i list pods --as=system:serviceaccount:dev:lettore-pod -n dev
```

**Risultato:** `yes`

```cmd
kubectl auth can-i delete pods --as=system:serviceaccount:dev:lettore-pod -n dev
```

**Risultato:** `no`

Questi test dimostrano l'applicazione del principio del **minimo privilegio (least privilege)**: l'identità può consultare i Pod, ma non eliminarli.

La ServiceAccount è dimostrativa e non è stata assegnata ai microservizi applicativi.

### Configurazione Ingress

È stato creato il file `ingress-dev.yaml` per definire una regola di instradamento HTTP verso il frontend di Online Boutique.

La configurazione prevede:

- Namespace: `dev`
- Nome della risorsa: `frontend-ingress`
- Percorso HTTP: `/`
- Tipo di corrispondenza: `Prefix`
- Service di destinazione: `frontend`
- Porta del Service: `80`

Il file è stato verificato con:

```cmd
kubectl apply --dry-run=server -f ingress-dev.yaml
```

Successivamente è stato applicato:

```cmd
kubectl apply -f ingress-dev.yaml
```

La presenza della risorsa è stata confermata con:

```cmd
kubectl get ingress -n dev
```

**Risultato:** `frontend-ingress` presente nel namespace `dev`.

**Limitazione:** nel cluster Kind non è stata rilevata alcuna IngressClass e non è stato configurato un Ingress Controller. Pertanto la risorsa Ingress è stata creata e validata, ma non è stato dimostrato l'instradamento HTTP attraverso un controller.

Il frontend è stato invece verificato tramite `kubectl port-forward`, con navigazione del negozio e completamento di un ordine simulato.

### Separazione degli ambienti

Le risorse RBAC e Ingress sono state configurate esclusivamente nel namespace `dev`. Il namespace `prod` non è stato modificato durante queste attività.

## 4.4 — CI/CD con GitHub Actions e deployment DEV

### Obiettivo

L'obiettivo di questa fase è automatizzare i controlli sul codice del frontend di Online Boutique e predisporre una procedura ripetibile per distribuire l'applicazione nell'ambiente DEV.

Sono stati utilizzati Git, GitHub, GitHub Actions, Docker, Kind e Kubernetes.

### 1. Versionamento del progetto con Git

È stato inizializzato un repository Git locale per tenere traccia delle modifiche al progetto.

**Comandi utilizzati:**

```cmd
git init
git status
git add .github/workflows/challenge-ci.yaml
git add src/frontend
git commit -m "Aggiunta configurazioni e pipeline CI"
git commit -m "Aggiunto codice frontend"
git branch -M main
```

**Spiegazione:**

- `git init`: inizializza il repository Git locale.
- `git status`: visualizza lo stato dei file.
- `git add`: prepara i file per il commit.
- `git commit -m`: registra le modifiche nella cronologia Git con un messaggio descrittivo.
- `git branch -M main`: rinomina il ramo principale in `main`.

Sono stati creati commit per registrare le configurazioni Kubernetes, la pipeline CI e il codice sorgente del frontend.

### 2. Collegamento del progetto a GitHub

È stato creato un repository GitHub privato denominato `online-boutique-challenge`.

**Comandi utilizzati:**

```cmd
git remote -v
git remote add origin https://github.com/pasqualee1997/online-boutique-challenge.git
git push -u origin main
```

**Spiegazione:**

- `git remote -v`: verifica i repository remoti configurati.
- `git remote add origin`: collega il repository locale a GitHub.
- `git push -u origin main`: pubblica i commit sul ramo `main` e configura il collegamento con il ramo remoto.

**Risultato:** codice e configurazioni pubblicati correttamente nel repository GitHub privato.

### 3. Configurazione della pipeline CI

È stato creato il file:

`.github/workflows/challenge-ci.yaml`

La pipeline viene avviata automaticamente a ogni `push` su GitHub.

**Operazioni eseguite dalla pipeline:**

1. Recupero del codice tramite `actions/checkout@v4`.
2. Configurazione dell'ambiente Go tramite `actions/setup-go@v5`.
3. Esecuzione dei test del frontend con `go test ./...`.
4. Costruzione dell'immagine Docker del frontend.

**Comando di build utilizzato:**

```cmd
docker build -t frontend-challenge:latest -f src/frontend/Dockerfile src/frontend
```

La pipeline viene eseguita su un runner GitHub con sistema operativo Ubuntu.

**Risultato:** la pipeline `Challenge CI` è stata eseguita con successo, completando i test Go e la build Docker.

### 4. Preparazione del deployment in DEV

È stato creato lo script Windows:

`deploy-dev.bat`

Lo script permette di eseguire manualmente una procedura di deployment del frontend nel cluster Kind locale.

**Operazioni previste dallo script:**

1. Verifica del contesto Kubernetes `kind-prova`.
2. Verifica dell'esistenza del namespace `dev`.
3. Costruzione dell'immagine Docker del frontend.
4. Caricamento dell'immagine nel cluster Kind.
5. Aggiornamento dell'immagine del Deployment `frontend` nel namespace DEV.
6. Riavvio controllato del Deployment.
7. Verifica del completamento del rollout.

**Comandi principali utilizzati:**

```cmd
kubectl config current-context
kubectl get namespace dev

docker build -t frontend-challenge:latest -f src/frontend/Dockerfile src/frontend

kind load docker-image frontend-challenge:latest --name prova

kubectl set image deployment/frontend server=frontend-challenge:latest -n dev

kubectl rollout restart deployment/frontend -n dev

kubectl rollout status deployment/frontend -n dev --timeout=180s

kubectl get deployment frontend -n dev
```

Lo script contiene controlli per interrompere la procedura in caso di errore e limita il deployment al namespace `dev`.

**Risultato:** dopo la correzione del controllo sul contesto Kubernetes, lo script è stato eseguito con successo.

### 5. Pubblicazione dello script di deployment

Dopo aver verificato il funzionamento dello script, è stato registrato e pubblicato su GitHub.

**Comandi utilizzati:**

```cmd
git add deploy-dev.bat
git commit -m "Aggiunto deployment DEV funzionante"
git push
```

Il nuovo `push` ha avviato nuovamente la pipeline GitHub Actions.

**Risultato:** l'ultima esecuzione di `Challenge CI` è terminata con stato `Success`.

### 6. Differenza tra CI e CD nella soluzione realizzata

**Continuous Integration (CI):** automatizzata tramite GitHub Actions. A ogni push vengono eseguiti i test del frontend e la build Docker.

**Continuous Delivery (CD):** è stata predisposta una procedura manuale e ripetibile tramite lo script `deploy-dev.bat`, eseguito sul computer locale.

La pipeline GitHub Actions non distribuisce automaticamente l'applicazione nel cluster Kind e non pubblica l'immagine Docker in un registry remoto.

Lo script di deployment costruisce localmente l'immagine e la carica nel cluster Kind.

### 7. Sicurezza degli ambienti

Le operazioni di deployment sono state limitate al namespace `dev`.

Non sono state eseguite operazioni di aggiornamento sull'ambiente PROD durante questa fase.

### 8. Risultato finale

La fase ha permesso di ottenere:

- Repository GitHub privato con codice e configurazioni versionati.
- Pipeline CI automatica con GitHub Actions.
- Test automatici del frontend Go.
- Build automatica dell'immagine Docker.
- Script locale per il deployment ripetibile in DEV.
- Verifica positiva dell'ultima esecuzione della pipeline.

**Conclusione:** è stata realizzata una soluzione CI automatizzata, accompagnata da una procedura di deployment manuale per l'ambiente DEV.

## 4.7 — Rollback e troubleshooting

Per verificare la capacità di diagnosticare e risolvere problemi su Kubernetes, è stata eseguita una simulazione controllata di aggiornamento fallito del frontend nel namespace `dev`.

### Simulazione del problema

È stata impostata un'immagine Docker inesistente:

```bash
kubectl set image deploy/frontend server=frontend-challenge:errore -n dev
```

Il nuovo Pod non è riuscito a scaricare l'immagine ed è entrato nello stato `ImagePullBackOff`, mentre il Pod precedente è rimasto funzionante.

### Diagnosi e continuità del servizio

Lo stato dei Pod è stato verificato con:

```bash
kubectl get pods -n dev
```

Per controllare la disponibilità dell'applicazione durante l'aggiornamento fallito è stato utilizzato:

```bash
kubectl port-forward svc/frontend 8083:80 -n dev
```

Il frontend è risultato raggiungibile all'indirizzo `http://localhost:8083`. È stato inoltre completato un ordine fino alla schermata **Order Complete**.

Questo test ha dimostrato che la strategia `RollingUpdate` ha mantenuto disponibile il Pod precedente e che il Service ha continuato a indirizzare il traffico verso il Pod pronto.

### Rollback e verifica

Per annullare l'aggiornamento errato è stato eseguito:

```bash
kubectl rollout undo deploy/frontend -n dev
```

Il rollback è stato confermato dal messaggio `deployment.apps/frontend rolled back`.

Successivamente sono stati verificati lo stato dei Pod e il completamento del rollout:

```bash
kubectl get pods -n dev
kubectl rollout status deploy/frontend -n dev
```

**Risultato:** tutti i Pod erano `1/1 Running` e Kubernetes ha confermato `deployment "frontend" successfully rolled out`.

### Documentazione

La procedura completa di diagnosi, verifica della continuità del servizio e ripristino è disponibile nel file [runbook.md](runbook.md).

Tutte le operazioni sono state eseguite esclusivamente nel namespace `dev`, senza modificare `prod`.

## 4.3 – Packaging Kubernetes con Helm

Per il packaging Kubernetes è stato utilizzato l'Helm Chart già presente nel progetto Online Boutique, nella directory `helm-chart/`.

Il Chart contiene:
- `Chart.yaml`: metadati del Chart.
- `values.yaml`: parametri di configurazione.
- `templates/`: template Kubernetes dei microservizi.
- `README.md`: documentazione del Chart.

### Validazione del Chart

È stata verificata la correttezza del Chart mediante:

```bash
helm lint ./helm-chart
```

Risultato: `1 chart(s) linted, 0 chart(s) failed`.

Successivamente sono stati generati i manifest Kubernetes:

```bash
helm template boutique ./helm-chart --namespace dev > helm-rendered.yaml
```

Infine è stata eseguita una simulazione dell'applicazione dei manifest:

```bash
kubectl apply --dry-run=client --validate=false -f helm-rendered.yaml -n dev
```

Il comando è terminato senza errori.

### Risultato

Il Chart Helm è stato validato e i manifest sono stati generati correttamente. La verifica tramite `dry-run` non ha modificato le risorse Kubernetes esistenti.

Non è stata effettuata una nuova installazione del Chart tramite Helm durante questa verifica.

## 4.4 – Valutazione tecnica di Krateo

### Obiettivo

Krateo è una piattaforma open source orientata al Platform Engineering, che permette di proporre servizi e risorse infrastrutturali attraverso un modello self-service e dichiarativo.

L'obiettivo della valutazione è comprendere come Krateo potrebbe migliorare la gestione dell'applicazione Online Boutique distribuita su Kubernetes.

### Possibile integrazione con Online Boutique

Attualmente l'applicazione viene gestita tramite manifest Kubernetes, Helm e script di deployment.

Una possibile evoluzione prevede l'utilizzo di Krateo come livello di Platform Engineering per:

- Esporre Online Boutique attraverso un catalogo self-service.
- Standardizzare la creazione degli ambienti DEV e PROD.
- Consentire ai team di richiedere un'istanza applicativa tramite parametri predefiniti.
- Integrare procedure di deployment e governance.
- Definire un percorso standardizzato, o *golden path*, per il rilascio dell'applicazione.

### Disegno logico dell'integrazione proposta

```text
Team di sviluppo
       |
       v
Catalogo self-service Krateo
       |
       v
Richiesta applicativa
(ambiente, versione, configurazione)
       |
       v
Automazione e governance
       |
       v
Helm Chart / Manifest Kubernetes
       |
       v
Cluster Kubernetes
       |
       +---- Namespace DEV
       |
       +---- Namespace PROD
       |
       v
Online Boutique
```

Questo schema rappresenta un'architettura proposta, non un'integrazione già implementata.

### Vantaggi

- Maggiore standardizzazione dei deployment.
- Riduzione delle operazioni manuali ripetitive.
- Possibilità di offrire funzionalità self-service ai team.
- Gestione più uniforme degli ambienti.
- Migliore governance in scenari con numerosi team e applicazioni.

### Svantaggi e complessità

- Introduzione di ulteriori componenti infrastrutturali.
- Maggiore complessità operativa e di manutenzione.
- Necessità di configurare e testare le integrazioni.
- Costi di apprendimento e gestione.
- Benefici limitati in un ambiente dimostrativo con una sola applicazione.

### Decisione architetturale

Per questa Challenge si è deciso di non installare Krateo nel cluster Kubernetes locale.

La scelta è motivata dalla dimensione dell'ambiente, composto da un'applicazione dimostrativa e due namespace logici, DEV e PROD.

L'utilizzo diretto di Kubernetes, Helm e degli script di deployment è sufficiente per gli obiettivi attuali.

Krateo viene quindi proposto come possibile evoluzione futura, soprattutto in presenza di più applicazioni, più team e necessità di standardizzare il provisioning self-service.

### Conclusione

La valutazione individua Krateo come possibile livello di Platform Engineering da introdurre in una fase successiva.

Non è stata realizzata un'integrazione operativa o una PoC Krateo. È stato invece definito un disegno logico di integrazione e motivata la non adozione immediata.

## 4.8 – Utilizzo dell'intelligenza artificiale nella Challenge

### Strumento utilizzato

Durante lo svolgimento della Challenge ho utilizzato ChatGPT come strumento di supporto per comprendere tecnologie e configurazioni, analizzare errori e preparare la documentazione.

### Ambiti di utilizzo

**Analisi del codice:** ho utilizzato l'AI per comprendere la struttura dei microservizi Online Boutique, i Dockerfile e le dipendenze applicative.

**Kubernetes:** ho richiesto spiegazioni sui Deployment, Service, namespace, ConfigMap, Secret, ServiceAccount e RBAC.

**CI/CD:** ho utilizzato l'AI come supporto per preparare e correggere la pipeline GitHub Actions e lo script di deployment DEV.

**Troubleshooting:** ho condiviso messaggi di errore e risultati dei comandi per individuare problemi di configurazione, immagini Docker, accesso al cluster e aggiornamenti Kubernetes.

**Documentazione:** ho utilizzato l'AI per organizzare le attività svolte e descrivere i risultati delle verifiche.

### Approccio adottato

Le richieste all'AI sono state formulate partendo da problemi concreti, ad esempio:

- Come verificare lo stato dei Pod Kubernetes?
- Come interpretare un errore ImagePullBackOff?
- Come configurare una ConfigMap e un Secret?
- Come verificare una pipeline GitHub Actions?
- Come effettuare il rollback di un Deployment?

### Verifica degli output

Le indicazioni ricevute non sono state considerate automaticamente corrette.

I comandi e le configurazioni sono stati verificati tramite strumenti come Docker, kubectl, Helm, Git e GitHub Actions.

Sono stati accettati gli output che hanno superato le verifiche; gli errori individuati sono stati corretti e le soluzioni non necessarie sono state scartate.

Un esempio è il problema di connettività tra Windows e il cluster Kind: è stato utilizzato temporaneamente un container ponte per ripristinare l'accesso, senza considerarlo una soluzione architetturale definitiva.

### Limiti

L'AI è stata utilizzata come supporto all'implementazione e al troubleshooting, non come sostituto dei test tecnici.

La responsabilità della verifica delle configurazioni e della valutazione dei risultati rimane del candidato.

