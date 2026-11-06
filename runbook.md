# Runbook — Rollback e Troubleshooting Kubernetes

## 1. Obiettivo

Questo documento descrive come individuare e risolvere un problema durante l'aggiornamento del frontend dell'applicazione Online Boutique, distribuita su Kubernetes.

La simulazione viene eseguita esclusivamente nel namespace `dev`, senza modificare l'ambiente `prod`.

## 2. Scenario di errore

Per simulare un aggiornamento fallito, è stata impostata sul Deployment `frontend` un'immagine Docker inesistente:

```cmd
kubectl set image deploy/frontend server=frontend-challenge:errore -n dev
```

Kubernetes ha tentato di avviare un nuovo Pod utilizzando questa immagine, senza riuscire a scaricarla.

## 3. Diagnosi del problema

Per verificare lo stato dei Pod è stato utilizzato:

```cmd
kubectl get pods -n dev
```

Sono stati osservati due Pod del frontend:

- **Vecchio Pod:** `1/1 Running`, ancora funzionante.
- **Nuovo Pod:** `0/1 ImagePullBackOff`, impossibilitato a scaricare l'immagine.

Lo stato `ImagePullBackOff` indica che Kubernetes non riesce a recuperare l'immagine del container e ritenta l'operazione.

Per approfondire un problema analogo si può utilizzare:

```cmd
kubectl describe pod NOME_POD -n dev
```

Questo comando permette di leggere gli eventi del Pod e individuare eventuali errori relativi all'immagine.

## 4. Verifica della continuità del servizio

Prima del rollback è stata verificata la raggiungibilità del frontend tramite port-forwarding:

```cmd
kubectl port-forward svc/frontend 8083:80 -n dev
```

Aprendo `http://localhost:8083`, il sito risultava accessibile.

È stato inoltre completato un ordine fino alla schermata **Order Complete**, verificando il funzionamento del flusso di acquisto.

Il vecchio Pod è rimasto disponibile durante il tentativo di aggiornamento fallito, grazie alla strategia `RollingUpdate`. Il Service ha continuato a indirizzare il traffico verso il Pod pronto.

## 5. Procedura di rollback

Prima della simulazione era stata salvata una copia della configurazione:

```cmd
kubectl get deploy frontend -n dev -o yaml > backup.yaml
```

Per annullare l'aggiornamento fallito è stato eseguito:

```cmd
kubectl rollout undo deploy/frontend -n dev
```

Kubernetes ha restituito:

```text
deployment.apps/frontend rolled back
```

È comparso anche un avviso relativo all'annotazione `kubectl.kubernetes.io/last-applied-configuration`: il rollback non aggiorna automaticamente questa annotazione, quindi eventuali successivi `kubectl apply` richiedono attenzione.

## 6. Verifica del ripristino

Dopo il rollback è stato controllato lo stato dei Pod:

```cmd
kubectl get pods -n dev
```

Tutti i Pod risultavano `1/1 Running` e il Pod in `ImagePullBackOff` non era più presente.

Infine è stato eseguito:

```cmd
kubectl rollout status deploy/frontend -n dev
```

Risultato:

```text
deployment "frontend" successfully rolled out
```

Il ripristino è stato quindi completato correttamente.

## 7. Considerazioni operative

- Controllare sempre lo stato dei Pod dopo un aggiornamento.
- Utilizzare le readiness probe per evitare di inviare traffico a Pod non pronti.
- In caso di aggiornamento fallito, analizzare gli eventi prima di intervenire.
- Utilizzare `kubectl rollout undo` per ripristinare la configurazione precedente.
- Verificare il risultato con `kubectl rollout status` e con un test funzionale dell'applicazione.
- Preferire tag di immagini Docker univoci e immutabili invece di riutilizzare `latest`, per rendere i rollback più prevedibili.
- Conservare i manifest Kubernetes nel repository come riferimento per la configurazione desiderata.

## 8. Esito della simulazione

**Simulazione riuscita:** l'aggiornamento errato è stato individuato, il frontend è rimasto raggiungibile e il rollback ha ripristinato lo stato corretto del Deployment.

Tutte le operazioni sono state effettuate esclusivamente nell'ambiente DEV.