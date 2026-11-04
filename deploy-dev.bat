
@echo off
REM ================================================
REM CHALLENGE L2 - DEPLOYMENT FRONTEND IN DEV
REM ================================================

REM Interrompe lo script se un comando restituisce un errore.
REM Usiamo sempre il cluster Kind chiamato "prova".
REM L'ambiente di destinazione e' esclusivamente DEV.


REM Legge il contesto Kubernetes attualmente selezionato.
for /f "delims=" %%A in ('kubectl config current-context') do set "CONTESTO=%%A"

REM Blocca lo script se il contesto non e' kind-prova.
if not "%CONTESTO%"=="kind-prova" (
    echo ERRORE: il contesto Kubernetes non e' kind-prova.
    exit /b 1
)


REM 2. Verifichiamo che esista il namespace DEV.
kubectl get namespace dev >nul 2>&1
if errorlevel 1 (
    echo ERRORE: namespace dev non trovato.
    exit /b 1
)

REM 3. Costruiamo una nuova immagine Docker del frontend.
docker build -t frontend-challenge:latest -f src/frontend/Dockerfile src/frontend
if errorlevel 1 exit /b 1

REM 4. Carichiamo l'immagine Docker dentro il cluster Kind locale.
kind load docker-image frontend-challenge:latest --name prova
if errorlevel 1 exit /b 1

REM 5. Aggiorniamo SOLO il deployment frontend nel namespace DEV.
kubectl set image deployment/frontend server=frontend-challenge:latest -n dev
if errorlevel 1 exit /b 1

REM 6. Forziamo il riavvio per usare l'immagine appena caricata.
kubectl rollout restart deployment/frontend -n dev
if errorlevel 1 exit /b 1

REM 7. Attendiamo che il frontend sia pronto.
kubectl rollout status deployment/frontend -n dev --timeout=180s
if errorlevel 1 exit /b 1

REM 8. Mostriamo lo stato finale del frontend in DEV.
kubectl get deployment frontend -n dev

echo.
echo DEPLOYMENT DEV COMPLETATO CON SUCCESSO!
